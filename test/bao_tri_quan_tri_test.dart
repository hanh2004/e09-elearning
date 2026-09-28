import 'package:e09_elearning/models/dinh_danh_tai_khoan.dart';
import 'package:e09_elearning/screens/admin/cai_dat_quan_tri.dart';
import 'package:e09_elearning/services/du_lieu/dich_vu_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AccountSession.current = null);

  testWidgets('admin update switch only changes the maintenance status', (
    tester,
  ) async {
    AccountSession.current = const AccountIdentity(
      id: 'root',
      role: 'super_admin',
    );
    final db = FakeFirebaseFirestore();
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AdminSettingsScreen(
          service: FirestoreService(firestore: db),
          maintenanceModeUpdater: (enabled) async {
            calls++;
            await db.doc('system/app_status').set({'maintenance': enabled});
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tạm dừng ứng dụng học viên (bảo trì)'), findsOneWidget);
    expect(find.text('Thử dọn lượt đang làm lại'), findsNothing);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(
      (await db.doc('system/app_status').get()).data()?['maintenance'],
      true,
    );
    expect(find.textContaining('lượt thi chưa được hủy'), findsNothing);
  });

  testWidgets('failed update only displays a simple error', (tester) async {
    AccountSession.current = const AccountIdentity(
      id: 'root',
      role: 'super_admin',
    );
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AdminSettingsScreen(
          service: FirestoreService(firestore: FakeFirebaseFirestore()),
          maintenanceModeUpdater: (_) async {
            calls++;
            throw StateError('temporary failure');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(
      find.text('Không thể cập nhật trạng thái ứng dụng.'),
      findsOneWidget,
    );
    expect(find.text('Thử dọn lượt đang làm lại'), findsNothing);
  });
}
