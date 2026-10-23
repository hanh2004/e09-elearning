import 'package:e09_elearning/screens/user/cac_khoa_hoc.dart';
import 'package:e09_elearning/screens/user/doc_bai_hoc.dart';
import 'package:e09_elearning/screens/user/bai_kiem_tra_hoc_vien.dart';
import 'package:e09_elearning/screens/user/lam_bai_kiem_tra_bao_mat.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:e09_elearning/services/ket_noi_api/dich_vu_bai_kiem_tra_bao_mat.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final learningMode in ['study_only', null]) {
    testWidgets('last study lesson ($learningMode) completes after scrolling', (
      tester,
    ) async {
      final db = FakeFirebaseFirestore();
      final service = LearningService(db: db);
      await db.doc('courses/c').set({
        'title': 'Khóa học để biết',
        'published': true,
        'learningMode': ?learningMode,
      });
      await db.doc('courses/c/lessons/l').set({
        'title': 'Bài học cuối',
        'content': List.filled(80, 'Nội dung cần đọc.').join('\n'),
        'minimumStudySeconds': 1,
      });
      final course = (await db.collection('courses').get()).docs.single;
      await tester.pumpWidget(
        MaterialApp(
          home: UserLessonsScreen(uid: 'u', course: course, service: service),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bài học'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bài học cuối'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Hoàn thành khóa học'), findsNothing);
      expect(
        (await db.doc('users/u/learning/c_l').get()).data()?['completed'],
        false,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -10000));
      await tester.pumpAndSettle();
      expect(find.text('Hoàn thành khóa học'), findsOneWidget);
      expect(
        (await db.doc('users/u/learning/c_l').get()).data()?['completed'],
        true,
      );
      await tester.tap(find.text('Hoàn thành khóa học'));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết khóa học'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'legacy mixed course waits for its exam before final completion',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final service = LearningService(db: db);
      await db.doc('courses/c').set({
        'title': 'Khóa học cũ',
        'published': true,
      });
      await db.doc('courses/c/lessons/first').set({
        'title': 'Bài có kiểm tra',
        'order': 1,
        'learningMode': 'study_exam',
        'examId': 'e',
      });
      await db.doc('users/u/learning/c_first').set({
        'courseId': 'c',
        'lessonId': 'first',
        'studyCompleted': true,
        'completed': false,
      });
      await db.doc('courses/c/lessons/last').set({
        'title': 'Bài cuối',
        'order': 2,
        'content': 'Nội dung cuối khóa.',
        'minimumStudySeconds': 1,
      });
      final course = (await db.collection('courses').get()).docs.single;
      await tester.pumpWidget(
        MaterialApp(
          home: TestCourseDetailsScreen(
            uid: 'u',
            course: course,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bài học'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bài cuối'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bài cuối'));
      await tester.pumpAndSettle();
      expect(find.byType(LessonReaderScreen), findsOneWidget);
      expect(find.text('Nội dung cuối khóa.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(find.text('Hoàn thành khóa học'), findsNothing);
      expect(await service.isCourseComplete('u', 'c'), false);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('study-only course overrides old exam lessons in both sections', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final service = LearningService(db: db);
    await db.doc('courses/c').set({
      'title': 'Khóa chỉ học',
      'published': true,
      'learningMode': 'study_only',
      'examId': '',
    });
    await db.doc('courses/c/lessons/old').set({
      'title': 'Bài học cũ',
      'order': 1,
      'content': 'Nội dung',
      'minimumStudySeconds': 1,
      'learningMode': 'study_exam',
      'examId': 'old-exam',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: UserLearningTestsScreen(uid: 'u', service: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bài học cũ'), findsNothing);
    final course = (await db.collection('courses').get()).docs.single;
    await tester.pumpWidget(
      MaterialApp(
        home: CourseChaptersScreen(uid: 'u', course: course, service: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bài học cũ'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('HOÀN THÀNH BÀI HỌC'), findsNothing);
    expect(find.text('Làm bài kiểm tra'), findsNothing);
    expect(
      (await db.doc('users/u/learning/c_old').get()).data()?['studyCompleted'],
      true,
    );
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 1200.0]) {
    testWidgets('study and test sections have separate content at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FakeFirebaseFirestore();
      final service = LearningService(db: db);
      await db.doc('courses/c').set({
        'title': 'Chuyên đề',
        'published': true,
        'learningMode': 'study_only',
        'examId': '',
      });
      await db.doc('courses/c/lessons/only').set({
        'title': 'Bài chỉ học',
        'order': 1,
        'content': 'Nội dung chỉ học',
        'minimumStudySeconds': 2,
      });
      await db.doc('courses/c/lessons/test').set({
        'title': 'Nội dung trước kiểm tra',
        'order': 2,
        'content': 'Đọc trước khi kiểm tra',
        'minimumStudySeconds': 2,
        'learningMode': 'study_exam',
        'examId': 'e',
      });
      final course = (await db.collection('courses').get()).docs.single;
      await tester.pumpWidget(
        MaterialApp(
          home: CourseChaptersScreen(
            uid: 'u',
            course: course,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bài chỉ học'), findsOneWidget);
      expect(find.text('Nội dung trước kiểm tra'), findsOneWidget);
      await tester.tap(find.text('Bài chỉ học'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('HOÀN THÀNH BÀI HỌC'), findsNothing);
      expect(find.text('Làm bài kiểm tra'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await db.doc('courses/c').update({
        'learningMode': 'study_exam',
        'examId': 'e',
      });
      var started = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: UserLearningTestsScreen(
            uid: 'u',
            service: service,
            examService: SecureExamService(
              transport: (name, input) async {
                if (name == 'examList') return {'exams': []};
                started++;
                expect(name, 'examStart');
                expect(input, {
                  'examId': 'e',
                  'courseId': 'c',
                  'lessonId': 'test',
                });
                expect(
                  (await db.doc('users/u/learning/c_test').get())
                      .data()?['studyCompleted'],
                  true,
                );
                return {
                  'status': 'completed',
                  'title': 'Kết quả',
                  'score': 10,
                  'correctAnswers': 1,
                  'totalQuestions': 1,
                  'passed': true,
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chuyên đề'), findsOneWidget);
      expect(started, 0);
      await tester.tap(find.text('Chuyên đề'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bài học'));
      await tester.pumpAndSettle();
      expect(find.text('Bài chỉ học'), findsOneWidget);
      expect(find.text('Nội dung trước kiểm tra'), findsOneWidget);
      await tester.tap(find.text('Nội dung trước kiểm tra'));
      await tester.pumpAndSettle();
      expect(find.text('Đọc trước khi kiểm tra'), findsOneWidget);
      expect(find.text('Làm bài kiểm tra'), findsNothing);
      expect(started, 0);
      await tester.pump(const Duration(seconds: 2));
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận đã học xong'), findsNothing);
      expect(find.text('Kiểm tra và hoàn thành'), findsOneWidget);
      await tester.tap(find.text('Kiểm tra và hoàn thành'));
      await tester.pumpAndSettle();
      expect(started, 1);
      expect(find.byType(SecureExamResultScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
