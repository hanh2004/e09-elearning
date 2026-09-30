import 'package:e09_elearning/screens/user/lam_bai_kiem_tra_bao_mat.dart';
import 'package:e09_elearning/services/ket_noi_api/dich_vu_bai_kiem_tra_bao_mat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('leaving the exam marks it inactive and stops heartbeat', (
    tester,
  ) async {
    final activeStates = <bool>[];
    final service = SecureExamService(
      transport: (name, data) async {
        if (name == 'examHeartbeat') activeStates.add(data['active'] as bool);
        return {'status': 'in_progress'};
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
    await tester.pump(const Duration(seconds: 20));
    expect(activeStates, [true]);
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 40));
    expect(activeStates, [true, false]);
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await tester.pump();
    expect(activeStates, [true, false, true]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(seconds: 40));
    expect(activeStates, [true, false, true, false]);
    expect(tester.takeException(), isNull);
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
