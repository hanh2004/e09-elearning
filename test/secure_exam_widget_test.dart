import 'package:e09_elearning/screens/user/secure_exam_screen.dart';
import 'package:e09_elearning/services/secure_exam_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('secure catalog renders without fetching answer keys', (
    tester,
  ) async {
    final calls = <String>[];
    final service = SecureExamService(
      transport: (name, data) async {
        calls.add(name);
        return {
          'exams': [
            {
              'id': 'e',
              'title': 'Đề thi máy chủ',
              'durationMinutes': 15,
              'usedAttempts': 0,
              'maxAttempts': 2,
              'active': false,
            },
          ],
        };
      },
    );
    await tester.pumpWidget(
      MaterialApp(home: SecureExamHomeScreen(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Đề thi máy chủ'), findsOneWidget);
    expect(calls, ['examList']);
  });
  for (final width in [390.0, 1440.0]) {
    testWidgets('secure exam fits $width and displays server result', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <Map<String, dynamic>>[];
      final service = SecureExamService(
        transport: (name, data) async {
          requests.add(data);
          return name == 'examSave'
              ? {'status': 'in_progress', 'revision': 1}
              : {
                  'status': 'completed',
                  'title': 'Đề',
                  'score': 7.5,
                  'correctAnswers': 3,
                  'totalQuestions': 4,
                  'passed': true,
                };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SecureExamScreen(
            service: service,
            run: {
              'runId': 'r',
              'examId': 'e',
              'title': 'Đề',
              'revision': 0,
              'endsAt': DateTime.now()
                  .add(const Duration(minutes: 5))
                  .millisecondsSinceEpoch,
              'selectedAnswers': <String, dynamic>{},
              'questions': [
                {
                  'id': 'q',
                  'title': 'Câu hỏi',
                  'options': ['A', 'B'],
                },
              ],
            },
          ),
        ),
      );
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      expect(requests.single['selectedAnswers'], {'q': 1});
      expect(requests.single.containsKey('score'), false);
      await tester.tap(find.text('Nộp bài và xem kết quả'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nộp bài'));
      await tester.pumpAndSettle();
      expect(find.text('7.5/10'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
