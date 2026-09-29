import 'dart:async';

import 'package:e09_elearning/screens/hop_thoai_dat_lai_mat_khau.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final fails in [false, true]) {
    testWidgets('closing password request before server reply does not update disposed state: $fails', (tester) async {
      final response = Completer<bool>();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey: navigator, home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () => showPasswordResetDialog(
            context: context, initialUsername: 'learner', canRecoverRootAccount: false,
            submitRequest: ({required username, required codeSuffix}) => response.future,
            recoverRootAccount: (_) async {},
          ),
          child: const Text('Mở'),
        )),
      )));
      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '001');
      await tester.tap(find.text('Gửi yêu cầu'));
      await tester.pump();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (fails) {
        response.completeError(StateError('Network unavailable'));
      } else {
        response.complete(false);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('root recovery closes safely with a focused username field', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showRootPasswordRecoveryDialog(screenContext: context, initialUsername: ''),
        child: const Text('Mở'),
      ),
    ))));
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'admintong1');
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
