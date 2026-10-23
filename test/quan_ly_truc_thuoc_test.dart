import 'dart:async';

import 'package:e09_elearning/models/dinh_danh_tai_khoan.dart';
import 'package:e09_elearning/screens/admin/quan_ly_tai_khoan.dart';
import 'package:e09_elearning/services/du_lieu/dich_vu_firestore.dart';
import 'package:e09_elearning/services/ket_noi_api/api_tai_khoan.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openSubUnits(
  WidgetTester tester, {
  List<String> subUnits = const [],
  Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
  transport,
}) async {
  final db = FakeFirebaseFirestore();
  await db.doc('users/m').set({
    'name': 'Quản lý',
    'username': 'manager',
    'role': 'admin',
    'status': 'active',
    'unit': 'D1',
    'subUnits': subUnits,
  });
  await tester.pumpWidget(
    MaterialApp(
      home: AdminAccountScreen(
        service: FirestoreService(
          firestore: db,
          accounts: AccountApi(transport: transport),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tạo trực thuộc'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(
    () =>
        AccountSession.current = const AccountIdentity(id: 'm', role: 'admin'),
  );
  tearDown(() => AccountSession.current = null);

  testWidgets('repeated save taps send only one subordinate-unit update', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    var calls = 0;
    await openSubUnits(
      tester,
      transport: (_, _) {
        calls++;
        return pending.future;
      },
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Tên trực thuộc'),
      'Đội 1',
    );
    await tester.tap(find.text('Lưu'));
    await tester.tap(find.text('Lưu'));
    await tester.pump();
    final observedCalls = calls;
    pending.complete({});
    await tester.pumpAndSettle();

    expect(observedCalls, 1);
    expect(find.text('Tạo trực thuộc'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('200 subordinate units fit a phone and scroll to the last chip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openSubUnits(
      tester,
      subUnits: List.generate(
        200,
        (i) => 'Đội ${i.toString().padLeft(3, '0')}',
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Đội 199'));
    await tester.pumpAndSettle();
    expect(find.text('Đội 199').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'saving cannot be dismissed and a failed save remains retryable',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      await openSubUnits(
        tester,
        transport: (method, input) {
          expect(method, 'accountSetSubUnits');
          expect(input, {
            'subUnits': ['Đội 1'],
          });
          return pending.future;
        },
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Tên trực thuộc'),
        'Đội 1',
      );
      await tester.tap(find.text('Lưu'));
      await tester.pump();
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      final dialogContext = tester.element(find.byType(AlertDialog));
      final didPop = await Navigator.of(dialogContext).maybePop();
      expect(didPop, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Đang lưu…'), findsOneWidget);
      pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.textContaining('offline'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lưu'))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('save failure after navigation is disposed has no state update', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    await openSubUnits(tester, transport: (_, _) => pending.future);
    await tester.tap(find.text('Lưu'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
