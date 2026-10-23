import 'dart:async';

import 'package:e09_elearning/widgets/tien_ich_giao_dien_hoc_tap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _openEditor(
  WidgetTester tester, {
  required Future<void> Function(Map<String, String>) save,
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => editLearningRecord(
              context,
              title: 'Cập nhật đơn vị',
              fields: {'Đơn vị trực thuộc': 'Đội 1'},
              save: save,
            ),
            child: const Text('Mở'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('repeated save taps send only one update', (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    await _openEditor(
      tester,
      save: (_) {
        calls++;
        return pending.future;
      },
    );
    await tester.tap(find.text('Lưu'));
    await tester.tap(find.text('Lưu'));
    await tester.pump();
    final observedCalls = calls;
    pending.complete();
    await tester.pumpAndSettle();
    expect(observedCalls, 1);
    expect(find.text('Mở'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back during save keeps the editor and errors remain retryable', (
    tester,
  ) async {
    final pending = Completer<void>();
    await _openEditor(tester, save: (_) => pending.future);
    await tester.tap(find.text('Lưu'));
    await tester.pump();
    await Navigator.of(tester.element(find.byType(AlertDialog))).maybePop();
    await tester.pumpAndSettle();
    final wasOpen = find.text('Đang lưu…').evaluate().length;
    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();

    expect(wasOpen, 1);
    expect(find.textContaining('offline'), findsWidgets);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lưu'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('save completion closes only its own editor under a new dialog', (
    tester,
  ) async {
    final pending = Completer<void>();
    final navigator = GlobalKey<NavigatorState>();
    await _openEditor(
      tester,
      save: (_) => pending.future,
      navigatorKey: navigator,
    );
    await tester.tap(find.text('Lưu'));
    await tester.pump();
    unawaited(
      showDialog<void>(
        context: navigator.currentContext!,
        builder: (_) => const AlertDialog(title: Text('Thông tin mới')),
      ),
    );
    await tester.pumpAndSettle();
    pending.complete();
    await tester.pumpAndSettle();

    expect(find.text('Thông tin mới'), findsOneWidget);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Cập nhật đơn vị'), findsNothing);
    expect(find.text('Mở'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
