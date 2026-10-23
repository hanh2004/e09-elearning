import 'dart:async';

import 'package:e09_elearning/screens/user/lam_bai_kiem_tra_bao_mat.dart';
import 'package:e09_elearning/services/ket_noi_api/dich_vu_bai_kiem_tra_bao_mat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> run({bool expired = false}) => {
    'runId': 'r',
    'examId': 'e',
    'title': 'Đề',
    'revision': 0,
    'endsAt': DateTime.now()
        .add(expired ? const Duration(seconds: -1) : const Duration(minutes: 5))
        .millisecondsSinceEpoch,
    'selectedAnswers': <String, dynamic>{},
    'questions': [
      {
        'id': 'q',
        'title': 'Câu hỏi',
        'options': ['A', 'B'],
      },
    ],
  };

  testWidgets('a second choice during saving cannot replace the saved answer', (
    tester,
  ) async {
    final saved = Completer<Map<String, dynamic>>();
    final requests = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SecureExamScreen(
          run: run(),
          service: SecureExamService(
            transport: (name, data) {
              requests.add(data);
              return saved.future;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('B'));
    await tester.tap(find.text('A'));
    saved.complete({'status': 'in_progress', 'revision': 1});
    await tester.pumpAndSettle();
    expect(requests.single['selectedAnswers'], {'q': 1});
    expect(
      tester
          .widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'B'))
          .value,
      true,
    );
    expect(
      tester
          .widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'A'))
          .value,
      false,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('rapid question navigation stays within the question list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SecureExamScreen(
          run: {
            ...run(),
            'questions': [
              {
                'id': 'first',
                'title': 'Câu đầu',
                'options': ['A', 'B'],
              },
              {
                'id': 'last',
                'title': 'Câu cuối',
                'options': ['C', 'D'],
              },
            ],
          },
          service: SecureExamService(transport: (_, _) async => {}),
        ),
      ),
    );
    await tester.tap(find.text('Câu tiếp'));
    await tester.tap(find.text('Câu tiếp'));
    await tester.pump();
    expect(find.text('2. Câu cuối'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    await tester.tap(find.text('Câu trước'));
    await tester.tap(find.text('Câu trước'));
    await tester.pump();
    expect(find.text('1. Câu đầu'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'timeout replaces the exam even while its submit dialog is open',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final service = SecureExamService(
        transport: (_, _) async => {
          'status': 'completed',
          'title': 'Đề',
          'score': 8,
          'correctAnswers': 1,
          'totalQuestions': 1,
          'passed': true,
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: SecureExamScreen(service: service, run: run(expired: true)),
        ),
      );
      await tester.tap(find.text('Nộp bài và xem kết quả'));
      await tester.pumpAndSettle();
      expect(find.text('Nộp bài?'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(SecureExamResultScreen), findsOneWidget);
      expect(find.byType(SecureExamScreen), findsNothing);
      expect(navigator.currentState!.canPop(), false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'repeated reload taps send only one request while it is pending',
    (tester) async {
      final restored = Completer<Map<String, dynamic>>();
      var reloads = 0;
      final service = SecureExamService(
        transport: (name, _) async {
          if (name == 'examStart') {
            reloads++;
            return restored.future;
          }
          throw StateError('Mất kết nối');
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SecureExamScreen(service: service, run: run()),
        ),
      );
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      final reload = find.text('Tải bài đã lưu');
      await tester.tap(reload);
      await tester.tap(reload);
      expect(reloads, 1);
      restored.complete({
        ...run(),
        'revision': 1,
        'serverNow': DateTime.now().millisecondsSinceEpoch,
      });
      await tester.pumpAndSettle();
      expect(find.byType(MaterialBanner), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

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
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(seconds: 40));
    expect(activeStates, [true, false]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
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
