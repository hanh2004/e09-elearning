import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/models/dinh_danh_tai_khoan.dart';
import 'package:e09_elearning/models/bieu_mau_khoa_hoc.dart';
import 'package:e09_elearning/models/bieu_mau_bai_hoc.dart';
import 'package:e09_elearning/screens/admin/forms/bieu_mau_khoa_hoc.dart';
import 'package:e09_elearning/screens/admin/forms/bieu_mau_bai_hoc.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:e09_elearning/widgets/tien_ich_giao_dien_hoc_tap.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final editLesson in [false, true]) {
    testWidgets('editor saves to the existing record (lesson: $editLesson)', (
      tester,
    ) async {
      AccountSession.current = const AccountIdentity(
        id: 'root',
        role: 'super_admin',
      );
      addTearDown(() => AccountSession.current = null);
      final db = FakeFirebaseFirestore();
      final service = LearningService(db: db);
      await db.doc('courses/c').set({
        'title': 'Khóa học cũ',
        'subject': 'Nghiệp vụ',
        'published': false,
        'coverUrl': 'https://example.org/course.png',
      });
      await db.doc('courses/c/lessons/l').set({
        'title': 'Bài học cũ',
        'chapter': 'Chương 1',
        'order': 1,
        'content': 'Nội dung bài học cũ',
        'type': 'video',
        'url': 'https://example.org/video.mp4',
        'coverUrl': 'https://example.org/lesson.png',
      });
      final course = (await db.collection('courses').get()).docs.single;
      final lesson =
          (await course.reference.collection('lessons').get()).docs.single;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => editLesson
                    ? showLessonEditor(
                        context,
                        service: service,
                        course: course,
                        lesson: lesson,
                      )
                    : showCourseEditor(
                        context,
                        service: service,
                        course: course,
                      ),
                child: const Text('Mở'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();
      if (!editLesson) {
        expect(find.text('Loại khóa học'), findsNothing);
      }
      final titleField = editLesson
          ? find.widgetWithText(TextFormField, 'Tên bài học')
          : find.byType(TextFormField).first;
      await tester.enterText(titleField, 'Tên đã sửa');
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      final saved =
          (await (editLesson ? lesson.reference : course.reference).get())
              .data()!;
      expect(saved['title'], 'Tên đã sửa');
      expect(
        saved['coverUrl'],
        editLesson
            ? 'https://example.org/lesson.png'
            : 'https://example.org/course.png',
      );
      if (editLesson) {
        expect(saved['type'], 'video');
        expect(saved['url'], 'https://example.org/video.mp4');
        expect(
          (await course.reference.collection('lessons').get()).docs,
          hasLength(1),
        );
      } else {
        expect(saved['published'], false);
        expect((await db.collection('courses').get()).docs, hasLength(1));
      }
      expect((await db.collection('learning_audit').get()).docs, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  test('editing a scheduled course retains dates and publication state', () {
    final start = DateTime(2026, 10, 1, 8, 30);
    final end = DateTime(2026, 10, 2, 17);
    final fields = CourseForm.initialValues({
      'title': 'Khóa học',
      'subject': 'Nghiệp vụ',
      'startsAt': Timestamp.fromDate(start),
      'endsAt': Timestamp.fromDate(end),
      // Bản ghi cũ chưa có deploymentMode vẫn phải mở đúng form.
    });
    final saved = CourseForm.toFirestore(fields, published: true);
    expect(saved['deploymentMode'], 'scheduled');
    expect((saved['startsAt'] as Timestamp).toDate(), start);
    expect((saved['endsAt'] as Timestamp).toDate(), end);
    expect(saved['published'], true);
    expect(saved['audience'], 'all');
  });

  test('exam course can be saved before its exam is created', () {
    final saved = CourseForm.toFirestore(
      {
        ...CourseForm.initialValues({}),
        'learningMode': CourseForm.studyExamLabel,
        'examId': '',
      },
      published: false,
      allowPendingExam: true,
    );
    expect(saved['learningMode'], 'study_exam');
    expect(saved['examId'], '');
  });

  test('switching to manual clears the old schedule without publishing', () {
    final fields = CourseForm.initialValues({
      'startsAt': '2026-10-01 08:00',
      'endsAt': '2026-10-02 17:00',
    });
    fields['deploymentMode'] = CourseForm.manualLabel;
    final saved = CourseForm.toFirestore(fields, published: false);
    expect(saved.containsKey('startsAt'), true);
    expect(saved.containsKey('endsAt'), true);
    expect(saved['startsAt'], isNull);
    expect(saved['endsAt'], isNull);
    expect(saved['deploymentMode'], 'manual');
    expect(saved['published'], false);
  });

  test('scheduled courses reject missing, invalid or reversed dates', () {
    for (final (start, end) in [
      ('', '2026-10-02 08:00'),
      ('2026-10-01 08:00', ''),
      ('không phải ngày', '2026-10-02 08:00'),
      ('2026-10-01 08:00', '2026-10-01 08:00'),
      ('2026-10-02 08:00', '2026-10-01 08:00'),
    ]) {
      expect(
        () => CourseForm.toFirestore({
          'deploymentMode': CourseForm.scheduledLabel,
          'startsAt': start,
          'endsAt': end,
        }, published: false),
        throwsArgumentError,
      );
    }
  });

  test('explicit manual mode stays manual after ending a course', () {
    final course = {
      'deploymentMode': 'manual',
      'published': true,
      'endsAt': DateTime(2020),
    };
    expect(LearningPolicy.isManual(course), true);
    expect(LearningPolicy.isScheduled(course), false);
    expect(LearningPolicy.hasEnded(course), true);
    expect(LearningPolicy.isManual({}), true);
    expect(LearningPolicy.isScheduled({'startsAt': DateTime(2026)}), true);
  });

  test('editing a legacy media lesson preserves its type and URL', () {
    final previous = {
      'title': 'Video cũ',
      'type': 'video',
      'url': 'https://example.org/video.mp4',
      'minimumStudySeconds': 450,
    };
    final fields = LessonForm.initialValues(previous);
    fields['title'] = 'Video đã đổi tên';
    final saved = LessonForm.toFirestore(fields, previous: previous);
    expect(saved['title'], 'Video đã đổi tên');
    expect(saved['type'], 'video');
    expect(saved['url'], previous['url']);
    expect(saved['minimumStudySeconds'], 450);
  });

  test('study duration and lesson order validate at their boundaries', () {
    final fields = {
      ...LessonForm.initialValues({}),
      'content': 'Nội dung bài học',
    };
    for (final seconds in ['0', '-1', '86401', '1.5', 'abc', '']) {
      expect(
        () => LessonForm.toFirestore({
          ...fields,
          'minimumStudySeconds': seconds,
        }, previous: {}),
        throwsArgumentError,
      );
    }
    for (final seconds in ['1', '86400']) {
      final saved = LessonForm.toFirestore({
        ...fields,
        'minimumStudySeconds': seconds,
        'order': '0',
      }, previous: {});
      expect(saved['minimumStudySeconds'], int.parse(seconds));
      expect(saved['order'], 0);
    }
    for (final order in ['-1', 'abc']) {
      expect(
        () => LessonForm.toFirestore({...fields, 'order': order}, previous: {}),
        throwsArgumentError,
      );
    }
  });

  test('text lessons need content or a cover image', () {
    final fields = LessonForm.initialValues({});
    expect(
      () => LessonForm.toFirestore(fields, previous: {}),
      throwsArgumentError,
    );
    final saved = LessonForm.toFirestore({
      ...fields,
      'imageUrl': 'https://example.org/cover.png',
    }, previous: {});
    expect(saved['minimumStudySeconds'], 300);
    expect(saved['type'], 'text');
  });

  for (final useLabels in [false, true]) {
    testWidgets('form labels retain stable save keys (labels: $useLabels)', (
      tester,
    ) async {
      Map<String, String>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => editLearningRecord(
                  context,
                  title: 'Sửa nội dung',
                  fields: {'title': 'Tên cũ'},
                  labels: useLabels ? {'title': 'Tên hiển thị mới'} : {},
                  save: (values) async {
                    saved = values;
                  },
                ),
                child: const Text('Mở'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();
      expect(
        find.text(useLabels ? 'Tên hiển thị mới' : 'title'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField), '  Tên mới  ');
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(saved, {'title': 'Tên mới'});
      expect(tester.takeException(), isNull);
    });
  }
}
