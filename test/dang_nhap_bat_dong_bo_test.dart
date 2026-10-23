import 'dart:async';

import 'package:e09_elearning/app/cong_ung_dung.dart';
import 'package:e09_elearning/screens/hop_thoai_dat_lai_mat_khau.dart';
import 'package:e09_elearning/screens/man_hinh_dang_nhap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('does not authenticate after leaving during maintenance check', (
    tester,
  ) async {
    final maintenance = Completer<bool>();
    var authenticationCalls = 0;
    await tester.pumpWidget(
      PortalScope(
        portal: AppPortal.user,
        homeBuilder: (_) => const SizedBox(),
        child: MaterialApp(
          home: LoginScreen(
            maintenanceChecker: () => maintenance.future,
            authenticate: (_, _) async {
              authenticationCalls++;
              return null;
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'learner');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.text('ĐĂNG NHẬP'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    maintenance.complete(false);
    await tester.pumpAndSettle();

    expect(authenticationCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'password request can finish after its original page is removed',
    (tester) async {
      final response = Completer<bool>();
      final showPage = ValueNotifier(true);
      addTearDown(showPage.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: showPage,
              builder: (_, visible, _) => visible
                  ? Builder(
                      builder: (context) => TextButton(
                        onPressed: () => showPasswordResetDialog(
                          context: context,
                          initialUsername: 'learner',
                          canRecoverRootAccount: false,
                          submitRequest: ({required username}) =>
                              response.future,
                          recoverRootAccount: (_) async {},
                        ),
                        child: const Text('Mở'),
                      ),
                    )
                  : const SizedBox(),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gửi yêu cầu'));
      await tester.pump();
      showPage.value = false;
      await tester.pump();
      response.complete(true);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
