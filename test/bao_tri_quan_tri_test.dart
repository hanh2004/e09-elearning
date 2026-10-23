import 'dart:async';

import 'package:e09_elearning/models/dinh_danh_tai_khoan.dart';
import 'package:e09_elearning/screens/admin/cai_dat_quan_tri.dart';
import 'package:e09_elearning/services/du_lieu/dich_vu_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AccountSession.current = null);

  testWidgets('failed maintenance status must be retried before toggling', (
    tester,
  ) async {
    AccountSession.current = const AccountIdentity(
      id: 'root',
      role: 'super_admin',
    );
    var reads = 0;
    final service = _MaintenanceStatusService(
      () => ++reads == 1
          ? Stream.error(StateError('offline'))
          : Stream.value(true),
    );
    await tester.pumpWidget(
      MaterialApp(home: AdminSettingsScreen(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text('Không tải được dữ liệu'), findsOneWidget);
    await tester.tap(find.text('Tải lại'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      true,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('maintenance update ignores repeated calls before rebuilding', (
    tester,
  ) async {
    AccountSession.current = const AccountIdentity(
      id: 'root',
      role: 'super_admin',
    );
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AdminSettingsScreen(
          service: _MaintenanceStatusService(() => Stream.value(false)),
          maintenanceModeUpdater: (_) {
            calls++;
            return pending.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final toggle = tester
        .widget<SwitchListTile>(find.byType(SwitchListTile))
        .onChanged!;
    toggle(true);
    toggle(true);
    expect(calls, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

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

class _MaintenanceStatusService extends FirestoreService {
  _MaintenanceStatusService(this.status)
    : super(firestore: FakeFirebaseFirestore());

  final Stream<bool> Function() status;

  @override
  Stream<bool> getMaintenanceModeStream() => status();
}
