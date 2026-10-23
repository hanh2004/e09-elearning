import 'package:e09_elearning/screens/user/lam_bai_kiem_tra_bao_mat.dart';
import 'package:e09_elearning/screens/user/bai_kiem_tra_hoc_vien.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:e09_elearning/services/ket_noi_api/dich_vu_bai_kiem_tra_bao_mat.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final learningMode in ['study_exam', null]) {
    testWidgets(
      'course exam ($learningMode) opens only after every lesson is complete',
      (tester) async {
        final db = FakeFirebaseFirestore();
        await db.doc('courses/c').set({
          'title': 'Khóa có kiểm tra',
          'published': true,
          'learningMode': ?learningMode,
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
                  if (name == 'examList') {
                    return {
                      'exams': [
                        {'id': 'e', 'title': 'Bài thi cuối khóa'},
                      ],
                    };
                  }
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
        await tester.tap(find.text('BẮT ĐẦU HỌC NGAY'));
        await tester.pumpAndSettle();
        expect(find.text('Bài l1'), findsOneWidget);
        expect(find.text('Bài l2'), findsOneWidget);
        expect(
          tester
              .widget<ListTile>(
                find.ancestor(
                  of: find.text('Bài l2'),
                  matching: find.byType(ListTile),
                ),
              )
              .onTap,
          isNull,
        );
        expect(find.text('0% Hoàn thành'), findsOneWidget);
        await tester.drag(find.byType(ListView).last, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(find.text('Bài thi cuối khóa'), findsOneWidget);
        await tester.ensureVisible(find.text('Bài l1'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Bài l1'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Bài tiếp theo'),
              )
              .onPressed,
          isNull,
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -1000));
        await tester.pumpAndSettle();
        expect(find.text('Xác nhận đã học xong'), findsNothing);
        expect(find.textContaining('Bạn đã học xong bài này.'), findsOneWidget);
        expect(find.text('Làm bài kiểm tra'), findsNothing);
        await tester.tap(find.text('Bài tiếp theo'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -1000));
        await tester.pumpAndSettle();
        expect(find.text('Xác nhận đã học xong'), findsNothing);
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
        expect(find.text('HOÀN THÀNH BÀI HỌC'), findsNothing);
        expect(await service.isCourseComplete('u', 'c'), true);
        Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
        await tester.pumpAndSettle();
        expect(find.text('100% Hoàn thành'), findsOneWidget);
        expect(find.text('Đã hoàn thành'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
