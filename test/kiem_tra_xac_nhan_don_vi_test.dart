import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/screens/user/chinh_sua_ho_so.dart';
import 'package:e09_elearning/services/ket_noi_api/api_tai_khoan.dart';
import 'package:e09_elearning/widgets/thong_bao_cap_nhat_don_vi.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('missing unit, transfer, confirmation and mobile large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    Future<void> show(Map<String, dynamic> data) => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: Column(
              children: [
                UnitUpdateNotice(profile: data, onUpdate: () => taps++),
              ],
            ),
          ),
        ),
      ),
    );
    await show({'unit': 'D1'});
    expect(find.textContaining('Bạn chưa nhập đơn vị'), findsOneWidget);
    await tester.tap(find.byTooltip('Cập nhật đơn vị'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
    await show({
      'unit': 'D2',
      'subUnit': 'Đội cũ',
      'unitNeedsConfirmation': true,
    });
    expect(find.textContaining('xác nhận đơn vị'), findsOneWidget);
    await show({
      'unit': 'D2',
      'subUnit': 'Đội mới',
      'unitNeedsConfirmation': false,
    });
    expect(find.byIcon(Icons.info_outline), findsNothing);
    await show({'unit': ''});
    expect(find.textContaining('liên hệ quản lý'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blank personal unit cannot dismiss transfer requirement', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/u').set({
      'name': 'An',
      'unit': 'D1',
      'unitNeedsConfirmation': true,
      'unitAssignmentVersion': 3,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileEditScreen(uid: 'u', firestore: db, openEditor: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lưu'), findsOneWidget);
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
      'createdBy': 'm1',
      'unitNeedsConfirmation': true,
      'unitAssignmentVersion': 1,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileEditScreen(
          uid: 'u',
          firestore: db,
          openEditor: true,
          accounts: AccountApi(
            transport: (_, _) async => {
              'managerId': 'm1',
              'subUnits': <String>[],
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
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
