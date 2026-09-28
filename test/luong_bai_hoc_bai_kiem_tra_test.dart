import 'package:cloud_functions/cloud_functions.dart';
import 'package:e09_elearning/screens/user/doc_bai_hoc.dart';
import 'package:e09_elearning/screens/user/lam_bai_kiem_tra_bao_mat.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:e09_elearning/services/ket_noi_api/dich_vu_bai_kiem_tra_bao_mat.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mode in ['study_only', 'study_exam']) {
    testWidgets('$mode starts exam only after progress is saved, once', (
      tester,
    ) async {
      final db = FakeFirebaseFirestore();
      await db.doc('courses/c').set({'published': true});
      await db.doc('courses/c/lessons/l').set({
        'learningMode': mode,
        'examId': 'e',
      });
      var calls = 0;
      final service = SecureExamService(
        transport: (name, data) async {
          calls++;
          expect(name, 'examStart');
          expect(data['examId'], 'e');
          expect(
            (await db.doc('users/u/learning/c_l').get())
                .data()?['studyCompleted'],
            true,
          );
          return {
            'status': 'completed',
            'title': 'Kết quả kiểm tra',
            'score': 8,
            'correctAnswers': 4,
            'totalQuestions': 5,
            'passed': true,
          };
        },
      );
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: LessonReaderScreen(
            uid: 'u',
            courseId: 'c',
            lessonId: 'l',
            service: LearningService(db: db),
            examService: service,
            lesson: {
              'title': 'Bài học',
              'content': 'Nội dung',
              'minimumStudySeconds': 2,
              'learningMode': mode,
              'examId': 'e',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.pump(const Duration(seconds: 2));
      if (mode == 'study_exam') {
        await tester.drag(find.byType(ListView), const Offset(0, -1000));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Học xong và làm bài kiểm tra'));
      }
      await tester.pumpAndSettle();
      expect(calls, mode == 'study_exam' ? 1 : 0);
      if (mode == 'study_exam') {
        expect(find.byType(SecureExamResultScreen), findsOneWidget);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 5));
        expect(calls, 1);
        expect(find.text('Làm bài kiểm tra'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('closed exam retains progress and offers manual retry', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.doc('courses/c').set({'published': true});
    await db.doc('courses/c/lessons/l').set({
      'learningMode': 'study_exam',
      'examId': 'e',
    });
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LessonReaderScreen(
          uid: 'u',
          courseId: 'c',
          lessonId: 'l',
          service: LearningService(db: db),
          examService: SecureExamService(
            transport: (_, _) async {
              calls++;
              throw FirebaseFunctionsException(
                code: 'failed-precondition',
                message: 'Bài kiểm tra chưa mở.',
              );
            },
          ),
          lesson: const {
            'title': 'Bài học',
            'content': 'Nội dung',
            'minimumStudySeconds': 1,
            'learningMode': 'study_exam',
            'examId': 'e',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Học xong và làm bài kiểm tra'));
    await tester.pumpAndSettle();
    expect(find.text('Bài kiểm tra chưa mở.'), findsOneWidget);
    expect(
      (await db.doc('users/u/learning/c_l').get()).data()?['studyCompleted'],
      true,
    );
    expect(calls, 1);
    await tester.tap(find.text('Làm bài kiểm tra'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });
}
