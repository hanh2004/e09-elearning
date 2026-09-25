import 'package:e09_elearning/screens/user/secure_exam_screen.dart';
import 'package:e09_elearning/screens/user/user_learning_tests_screen.dart';
import 'package:e09_elearning/services/nghiep_vu/learning_service.dart';
import 'package:e09_elearning/services/ket_noi_api/secure_exam_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('course exam opens only after every lesson is complete', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.doc('courses/c').set({
      'title': 'Khóa có kiểm tra',
      'published': true,
      'learningMode': 'study_exam',
      'examId': 'e',
    });
    for (final id in ['l1', 'l2']) {
      await db.doc('courses/c/lessons/$id').set({
        'title': 'Bài $id',
        'order': id == 'l1' ? 1 : 2,
        'content': 'Nội dung $id',
        'minimumStudySeconds': 1,
      });
    }
    var starts = 0;
    final service = LearningService(db: db);
    await tester.pumpWidget(
      MaterialApp(
        home: UserLearningTestsScreen(
          uid: 'u',
          service: service,
          examService: SecureExamService(
            transport: (name, input) async {
              starts++;
              expect(name, 'examStart');
              expect(input['examId'], 'e');
              for (final id in ['l1', 'l2']) {
                final ref = db.doc('users/u/learning/c_$id');
                expect((await ref.get()).data()?['completed'], false);
                await ref.update({
                  'completed': true,
                  'examCompleted': true,
                  'completedExamId': 'e',
                });
              }
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
    expect(find.text('Khóa có kiểm tra'), findsOneWidget);
    await tester.tap(find.text('Khóa có kiểm tra'));
    await tester.pumpAndSettle();
    expect(find.text('Bài l1'), findsOneWidget);
    expect(find.text('Bài l2'), findsOneWidget);

    await tester.tap(find.text('Bài l1'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiểm tra và hoàn thành'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bạn đã học xong bài này.'), findsOneWidget);
    expect(find.text('Làm bài kiểm tra'), findsNothing);
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bài l2'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiểm tra và hoàn thành'));
    await tester.pumpAndSettle();
    expect(find.text('Kiểm tra và hoàn thành'), findsOneWidget);
    expect(find.text('HOÀN THÀNH BÀI HỌC'), findsNothing);
    expect(await service.isCourseComplete('u', 'c'), false);
    expect(starts, 0);
    await tester.tap(find.text('Kiểm tra và hoàn thành'));
    await tester.pumpAndSettle();
    expect(starts, 1);
    expect(find.byType(SecureExamResultScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pumpAndSettle();
    expect(find.text('HOÀN THÀNH BÀI HỌC'), findsOneWidget);
    expect(await service.isCourseComplete('u', 'c'), true);
    expect(tester.takeException(), isNull);
  });
}
