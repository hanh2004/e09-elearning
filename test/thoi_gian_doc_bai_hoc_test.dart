import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/screens/user/doc_bai_hoc.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:e09_elearning/widgets/thong_bao_loi.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecoveringProgressFirestore extends FakeFirebaseFirestore {
  var subscriptions = 0;

  @override
  DocumentReference<Map<String, dynamic>> doc(String path) {
    final reference = super.doc(path);
    return path == 'users/u/learning/c_l'
        ? _RecoveringProgressReference(reference, this)
        : reference;
  }
}

// ignore: subtype_of_sealed_class
class _RecoveringProgressReference
    implements DocumentReference<Map<String, dynamic>> {
  _RecoveringProgressReference(this.reference, this.owner);

  final DocumentReference<Map<String, dynamic>> reference;
  final _RecoveringProgressFirestore owner;

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource? source,
  }) => ++owner.subscriptions == 1
      ? Stream.error(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        )
      : reference.snapshots(includeMetadataChanges: includeMetadataChanges);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) =>
      reference.get(options);

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) =>
      reference.set(data, options);

  @override
  Future<void> update(Map<Object, Object?> data) => reference.update(data);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RetryCourseProgressService extends LearningService {
  _RetryCourseProgressService({required super.db});

  int progressChecks = 0;
  int starts = 0;
  Future<void>? pendingStart;

  @override
  Future<bool> startLesson(
    String userId,
    String courseId,
    String lessonId,
  ) async {
    starts++;
    await pendingStart;
    return super.startLesson(userId, courseId, lessonId);
  }

  @override
  Future<bool> isCourseComplete(
    String userId,
    String courseId, {
    bool studyOnly = false,
  }) async {
    if (++progressChecks == 1) throw StateError('Chưa tải được tiến độ khóa.');
    return super.isCourseComplete(userId, courseId, studyOnly: studyOnly);
  }
}

class _SlowCourseProgressService extends LearningService {
  _SlowCourseProgressService({required super.db});
  final pending = Completer<bool>();
  var progressChecks = 0;

  @override
  Future<bool> isCourseComplete(
    String userId,
    String courseId, {
    bool studyOnly = false,
  }) => ++progressChecks == 1
      ? pending.future
      : super.isCourseComplete(userId, courseId, studyOnly: studyOnly);
}

void main() {
  testWidgets('a stalled course progress read can time out and be retried', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final service = _SlowCourseProgressService(db: db);
    const lesson = {
      'title': 'Bài học',
      'content': 'Nội dung',
      'minimumStudySeconds': 2,
    };
    await db.doc('courses/c').set({'learningMode': 'study_only'});
    await db.doc('courses/c/lessons/l').set(lesson);
    await tester.pumpWidget(
      MaterialApp(
        home: LessonReaderScreen(
          uid: 'u',
          courseId: 'c',
          lessonId: 'l',
          lesson: lesson,
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(service.progressChecks, 2);
    expect(find.text('Thử lại'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -10000));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(
      (await db.doc('users/u/learning/c_l').get()).data()?['completed'],
      true,
    );
    service.pending.complete(false);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('retrying progress reading keeps the current study timer', (
    tester,
  ) async {
    final db = _RecoveringProgressFirestore();
    const lesson = {
      'title': 'Bài học',
      'content': 'Nội dung',
      'minimumStudySeconds': 3,
    };
    await db.doc('courses/c').set({'learningMode': 'study_only'});
    await db.doc('courses/c/lessons/l').set(lesson);
    await tester.pumpWidget(
      MaterialApp(
        home: LessonReaderScreen(
          uid: 'u',
          courseId: 'c',
          lessonId: 'l',
          lesson: lesson,
          service: LearningService(db: db),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppErrorNotice), findsOneWidget);
    expect(db.subscriptions, 1);
    final ref = db.doc('users/u/learning/c_l');
    final startedAt = (await ref.get()).data()?['startedAt'];

    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Tải lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tải lại'));
    await tester.pumpAndSettle();
    expect(db.subscriptions, 2);
    expect(find.byType(AppErrorNotice), findsNothing);
    expect((await ref.get()).data()?['startedAt'], startedAt);
    expect(find.text('Thời gian còn lại: 0:02'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -10000));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect((await ref.get()).data()?['completed'], true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'retry restarts the reader after its first progress check fails',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final service = _RetryCourseProgressService(db: db);
      const lesson = {
        'title': 'Bài học',
        'content': 'Nội dung',
        'minimumStudySeconds': 2,
      };
      await db.doc('courses/c').set({'learningMode': 'study_only'});
      await db.doc('courses/c/lessons/l').set(lesson);
      await tester.pumpWidget(
        MaterialApp(
          home: LessonReaderScreen(
            uid: 'u',
            courseId: 'c',
            lessonId: 'l',
            lesson: lesson,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chưa tải được tiến độ khóa.'), findsOneWidget);
      expect(service.progressChecks, 1);

      final retry = Completer<void>();
      service.pendingStart = retry.future;
      await tester.tap(find.textContaining('Thử'));
      await tester.tap(find.textContaining('Thử'));
      expect(service.starts, 2);
      retry.complete();
      await tester.pumpAndSettle();
      expect(service.progressChecks, 2);
      expect(find.text('Chưa tải được tiến độ khóa.'), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, -10000));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(
        (await db.doc('users/u/learning/c_l').get()).data()?['completed'],
        true,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'leaving app resets study time and completion also waits for the end',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final service = LearningService(db: db);
      Widget reader() => MaterialApp(
        home: LessonReaderScreen(
          uid: 'u',
          courseId: 'c',
          lessonId: 'l',
          lesson: {
            'title': 'Bài học',
            'content': List.filled(80, 'Nội dung cần đọc.').join('\n'),
            'minimumStudySeconds': 3,
          },
          service: service,
        ),
      );
      await tester.pumpWidget(reader());
      await tester.pumpAndSettle();
      final ref = db.doc('users/u/learning/c_l');
      expect((await ref.get()).data()?['completed'], false);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.textContaining('Yêu thích'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 10));
      expect((await ref.get()).data()?['completed'], false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect((await ref.get()).data()?['completed'], false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect((await ref.get()).data()?['completed'], false);
      await tester.drag(find.byType(ListView), const Offset(0, -10000));
      await tester.pumpAndSettle();
      expect((await ref.get()).data()?['completed'], true);
      await tester.drag(find.byType(ListView), const Offset(0, 10000));
      await tester.pumpAndSettle();
      expect(find.text('Đã học'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(reader());
      await tester.pumpAndSettle();
      expect(find.text('Đã học'), findsOneWidget);
      expect((await ref.get()).data()?['completed'], true);
    },
  );

  for (final mode in ['study_only', 'study_exam']) {
    testWidgets(
      '$mode requires time and the end before opening the next lesson',
      (tester) async {
        final db = FakeFirebaseFirestore();
        final courseData = {
          'published': true,
          'learningMode': mode,
          if (mode == 'study_exam') 'examId': 'e',
        };
        await db.doc('courses/c').set(courseData);
        await db.doc('courses/c/lessons/first').set({
          'title': 'Bài đầu tiên',
          'order': 1,
          'content': List.filled(80, 'Nội dung cần đọc.').join('\n'),
          'minimumStudySeconds': 3,
        });
        await db.doc('courses/c/lessons/last').set({
          'title': 'Bài cuối',
          'order': 2,
          'content': 'Nội dung cuối.',
          'minimumStudySeconds': 3,
        });
        final lessons = LearningPolicy.sortLessons(
          (await db.collection('courses/c/lessons').get()).docs,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: LessonReaderScreen(
              uid: 'u',
              courseId: 'c',
              lessonId: lessons.first.id,
              lesson: lessons.first.data(),
              courseData: courseData,
              siblings: lessons,
              service: LearningService(db: db),
            ),
          ),
        );
        await tester.pumpAndSettle();

        OutlinedButton nextButton() => tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Bài tiếp theo'),
        );
        final progress = db.doc('users/u/learning/c_first');
        await tester.drag(find.byType(ListView), const Offset(0, -10000));
        await tester.pumpAndSettle();
        expect((await progress.get()).data()?['studyCompleted'], isNot(true));
        expect(nextButton().onPressed, isNull);

        await tester.drag(find.byType(ListView), const Offset(0, 10000));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect((await progress.get()).data()?['studyCompleted'], isNot(true));
        expect(nextButton().onPressed, isNull);

        await tester.drag(find.byType(ListView), const Offset(0, -10000));
        await tester.pumpAndSettle();
        expect((await progress.get()).data()?['studyCompleted'], true);
        expect(nextButton().onPressed, isNotNull);
        await tester.tap(find.text('Bài tiếp theo'));
        await tester.pumpAndSettle();
        expect(find.text('Nội dung cuối.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
