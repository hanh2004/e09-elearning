import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:e09_elearning/screens/hop_thoai_dat_lai_mat_khau.dart';
import 'package:e09_elearning/services/du_lieu/dich_vu_firestore.dart';
import 'package:e09_elearning/services/ket_noi_api/api_tai_khoan.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final fails in [false, true]) {
    testWidgets(
      'closing password request before server reply does not update disposed state: $fails',
      (tester) async {
        final response = Completer<bool>();
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showPasswordResetDialog(
                    context: context,
                    initialUsername: 'learner',
                    canRecoverRootAccount: false,
                    submitRequest: ({required username}) => response.future,
                    recoverRootAccount: (_) async {},
                  ),
                  child: const Text('Mở'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Mở'));
        await tester.pumpAndSettle();
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
      },
    );
  }

  testWidgets('root recovery closes safely with a focused username field', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showRootPasswordRecoveryDialog(
                screenContext: context,
                initialUsername: '',
              ),
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'admintong1');
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'root recovery keeps its proof while processing and offers login after completion',
    (tester) async {
      var requests = 0;
      var checks = 0;
      String? proof;
      final service = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        accounts: AccountApi(
          transport: (method, input) async {
            if (method == 'rootPasswordResetRequest') {
              requests++;
              proof = input['proof'] as String;
              return {};
            }
            expect(method, 'rootPasswordResetStatus');
            expect(input['proof'], proof);
            checks++;
            return {'status': checks == 1 ? 'processing' : 'completed'};
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showRootPasswordRecoveryDialog(
                  screenContext: context,
                  initialUsername: 'admintong1',
                  service: service,
                ),
                child: const Text('Mở'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gửi yêu cầu duyệt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kiểm tra duyệt'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Yêu cầu đang được xử lý.'), findsOneWidget);
      expect(find.textContaining('liên hệ người phụ trách'), findsOneWidget);
      expect(find.text('Gửi yêu cầu duyệt'), findsNothing);
      await tester.tap(find.text('Kiểm tra duyệt'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Đã hoàn tất khôi phục mật khẩu.'),
        findsOneWidget,
      );
      expect(find.text('Kiểm tra duyệt'), findsNothing);
      expect(requests, 1);
      await tester.tap(find.text('Đăng nhập lại'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'interrupted root recovery checks status before submitting again',
    (tester) async {
      var finishes = 0;
      var checks = 0;
      final service = FirestoreService(
        firestore: FakeFirebaseFirestore(),
        accounts: AccountApi(
          transport: (method, input) async {
            if (method == 'rootPasswordResetRequest') return {};
            if (method == 'rootPasswordResetStatus') {
              checks++;
              return {'status': checks == 1 ? 'approved' : 'processing'};
            }
            expect(method, 'rootPasswordResetFinish');
            finishes++;
            throw FirebaseFunctionsException(
              code: 'unavailable',
              message: 'offline',
            );
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showRootPasswordRecoveryDialog(
                  screenContext: context,
                  initialUsername: 'admintong1',
                  service: service,
                ),
                child: const Text('Mở'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gửi yêu cầu duyệt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kiểm tra duyệt'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'NewPassword01!');
      await tester.enterText(find.byType(TextField).at(1), 'NewPassword01!');
      await tester.tap(find.text('Đặt mật khẩu mới'));
      await tester.pumpAndSettle();
      expect(finishes, 1);
      expect(find.text('Đặt mật khẩu mới'), findsNothing);
      expect(find.text('Kiểm tra duyệt'), findsOneWidget);
      await tester.tap(find.text('Kiểm tra duyệt'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Yêu cầu đang được xử lý.'), findsOneWidget);
      expect(finishes, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
