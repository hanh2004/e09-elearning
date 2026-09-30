import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/models/tham_so_nguoi_dung.dart';
import 'package:e09_elearning/screens/user/ho_so_hoc_vien.dart';
import 'package:e09_elearning/services/ket_noi_api/api_tai_khoan.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:e09_elearning/services/tai_khoan/thao_tac_tai_khoan_hoc_vien.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _moCapNhatDonVi(
  WidgetTester tester,
  FakeFirebaseFirestore db, {
  AccountApi? accounts,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => updateLearnerUnit(
              context,
              uid: 'u',
              firestore: db,
              accounts: accounts,
            ),
            child: const Text('Cập nhật đơn vị'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Cập nhật đơn vị'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('account entry warns only when the learner has no unit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final noUnitDb = FakeFirebaseFirestore();
    await noUnitDb.doc('users/u').set({'name': 'An', 'unit': ''});
    await tester.pumpWidget(
      MaterialApp(
        home: UserProfileScreen(
          args: const UserArguments(userId: 'u', userName: 'An'),
          service: LearningService(db: noUnitDb),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa có đơn vị'), findsOneWidget);
    expect(find.textContaining('liên hệ quản lý'), findsOneWidget);
    await tester.tap(find.text('Đã hiểu'));
    await tester.pumpAndSettle();

    final assignedDb = FakeFirebaseFirestore();
    await assignedDb.doc('users/u').set({
      'name': 'An',
      'unit': 'D2',
      'subUnit': '',
      'unitNeedsConfirmation': true,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: UserProfileScreen(
          args: const UserArguments(userId: 'u', userName: 'An'),
          service: LearningService(db: assignedDb),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa có đơn vị'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty subordinate unit cannot confirm a unit transfer', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/u').set({
      'name': 'An',
      'unit': 'D1',
      'subUnit': '',
      'unitNeedsConfirmation': true,
      'unitAssignmentVersion': 3,
    });
    await _moCapNhatDonVi(tester, db);
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(
      (await db.doc('users/u').get()).data()!['unitNeedsConfirmation'],
      true,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Đơn vị trực thuộc (tổ/đội/bộ phận)'),
      'Đội 1',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    final data = (await db.doc('users/u').get()).data()!;
    expect(data['unitNeedsConfirmation'], false);
    expect(data['unitConfirmedVersion'], 3);
    expect(data['unitConfirmedAt'], isA<Timestamp>());
  });

  testWidgets('open form cannot acknowledge a later unit transfer', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/u').set({
      'name': 'An',
      'unit': 'D1',
      'subUnit': '',
      'createdBy': 'm1',
      'unitNeedsConfirmation': true,
      'unitAssignmentVersion': 1,
    });
    await _moCapNhatDonVi(
      tester,
      db,
      accounts: AccountApi(
        transport: (_, _) async => {'managerId': 'm1', 'subUnits': <String>[]},
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Đơn vị trực thuộc (tổ/đội/bộ phận)'),
      'Đội cũ',
    );
    await db.doc('users/u').update({
      'unit': 'D2',
      'createdBy': 'm2',
      'unitAssignmentVersion': 2,
      'unitNeedsConfirmation': true,
      'subUnit': '',
    });
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    final data = (await db.doc('users/u').get()).data()!;
    expect(data['unitNeedsConfirmation'], true);
    expect(data['subUnit'], '');
    expect(find.textContaining('Đơn vị vừa thay đổi'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
