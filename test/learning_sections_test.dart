import 'package:e09_elearning/screens/user/user_courses_screen.dart';
import 'package:e09_elearning/screens/user/user_learning_tests_screen.dart';
import 'package:e09_elearning/screens/user/secure_exam_screen.dart';
import 'package:e09_elearning/services/nghiep_vu/learning_service.dart';
import 'package:e09_elearning/services/ket_noi_api/secure_exam_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(find.text('HOÀN THÀNH BÀI HỌC'), findsOneWidget);
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
      expect(find.text('HOÀN THÀNH BÀI HỌC'), findsOneWidget);
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
      await tester.tap(find.text('Xác nhận đã học xong'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Làm bài kiểm tra'));
      await tester.pumpAndSettle();
      expect(started, 1);
      expect(find.byType(SecureExamResultScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
