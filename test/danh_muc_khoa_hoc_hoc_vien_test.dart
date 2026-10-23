import 'package:e09_elearning/screens/user/bai_kiem_tra_hoc_vien.dart';
import 'package:e09_elearning/screens/user/cac_khoa_hoc.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:e09_elearning/widgets/danh_muc_khoa_hoc_hoc_vien.dart';
import 'package:e09_elearning/widgets/tien_ich_giao_dien_hoc_tap.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('course classification respects explicit modes and legacy lessons', () {
    const examLesson = {'learningMode': 'study_exam', 'examId': 'exam'};
    expect(
      LearningPolicy.isExamCourse(
        {'learningMode': 'study_only', 'examId': 'old-exam'},
        [examLesson],
      ),
      false,
    );
    expect(
      LearningPolicy.isExamCourse({'learningMode': 'study_exam'}, const []),
      true,
    );
    expect(LearningPolicy.isExamCourse({'examId': 'exam'}, const []), true);
    expect(
      LearningPolicy.isExamCourse(const {}, [
        {'examId': 'legacy-exam'},
      ]),
      true,
    );
    expect(LearningPolicy.isExamCourse(const {}, [examLesson, const {}]), true);
    expect(LearningPolicy.isExamCourse(const {}, [const {}]), false);
    expect(LearningPolicy.isExamCourse(const {}, const []), false);
  });

  testWidgets('legacy study courses do not create invisible test results', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final service = LearningService(db: db);
    await db.doc('courses/legacy').set({
      'title': 'Khóa cũ chỉ học',
      'subject': 'Môn chỉ học',
      'published': true,
    });
    await db.doc('courses/legacy/lessons/first').set({
      'title': 'Bài học thường',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: UserLearningTestsScreen(uid: 'u', service: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy khóa học phù hợp.'), findsOneWidget);
    expect(find.text('Khóa cũ chỉ học'), findsNothing);
    expect(find.text('Môn chỉ học'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final exams in [false, true]) {
    testWidgets(
      'libraries classify legacy and explicit courses (exam=$exams)',
      (tester) async {
        final db = FakeFirebaseFirestore();
        final service = LearningService(db: db);
        for (final (id, title, mode) in [
          ('study', 'Khóa cũ chỉ học', null),
          ('mixed', 'Khóa cũ có kiểm tra', null),
          ('explicit-study', 'Khóa học tập', 'study_only'),
          ('explicit-exam', 'Khóa kiểm tra', 'study_exam'),
        ]) {
          await db.doc('courses/$id').set({
            'title': title,
            'subject': 'Môn $id',
            'published': true,
            'learningMode': ?mode,
          });
          await db.doc('courses/$id/lessons/first').set({
            'title': 'Bài đầu $id',
            'order': 1,
          });
        }
        for (final id in ['mixed', 'explicit-study']) {
          await db.doc('courses/$id/lessons/second').set({
            'title': 'Bài cuối $id',
            'order': 2,
            'learningMode': 'study_exam',
            'examId': 'exam',
          });
        }
        await tester.pumpWidget(
          MaterialApp(
            home: exams
                ? UserLearningTestsScreen(uid: 'u', service: service)
                : UserCoursesScreen(uid: 'u', service: service),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Khóa cũ chỉ học'),
          exams ? findsNothing : findsOneWidget,
        );
        expect(
          find.text('Khóa học tập'),
          exams ? findsNothing : findsOneWidget,
        );
        expect(
          find.text('Khóa cũ có kiểm tra'),
          exams ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Khóa kiểm tra'),
          exams ? findsOneWidget : findsNothing,
        );
        expect(find.text('Môn study'), exams ? findsNothing : findsOneWidget);
        expect(find.text('Môn mixed'), exams ? findsOneWidget : findsNothing);
        if (exams) {
          await tester.tap(find.text('Khóa cũ có kiểm tra'));
          await tester.pumpAndSettle();
          expect(find.byType(TestCourseDetailsScreen), findsOneWidget);
          await tester.tap(find.text('Bài học'));
          await tester.pumpAndSettle();
          expect(find.text('Bài đầu mixed'), findsOneWidget);
          expect(find.text('Bài cuối mixed'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('catalog follows lesson additions, changes and removals', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final service = LearningService(db: db);
    await db.doc('courses/legacy').set({'published': true});
    await db.doc('courses/legacy/lessons/first').set({'title': 'Bài đầu'});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningList(
            stream: service.courses(publishedOnly: true),
            builder: (courses) => LearnerCourseCatalog(
              courses: courses,
              service: service,
              builder: (entries) => Text(
                entries
                    .map(
                      (entry) =>
                          '${entry.hasExam ? 'Kiểm tra' : 'Học tập'}:${entry.lessons.length}',
                    )
                    .join(','),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Học tập:1'), findsOneWidget);
    await db.doc('courses/legacy/lessons/second').set({
      'learningMode': 'study_exam',
      'examId': 'exam',
    });
    await tester.pumpAndSettle();
    expect(find.text('Kiểm tra:2'), findsOneWidget);
    await db.doc('courses/legacy/lessons/second').update({
      'learningMode': 'study_only',
    });
    await tester.pumpAndSettle();
    expect(find.text('Học tập:2'), findsOneWidget);
    await db.doc('courses/legacy/lessons/first').delete();
    await tester.pumpAndSettle();
    expect(find.text('Học tập:1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
