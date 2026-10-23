import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/models/dinh_danh_tai_khoan.dart';
import 'package:e09_elearning/models/yeu_cau_cap_lai_mat_khau.dart';
import 'package:e09_elearning/screens/admin/quan_ly_tai_khoan.dart';
import 'package:e09_elearning/screens/admin/yeu_cau_dat_lai_mat_khau.dart';
import 'package:e09_elearning/services/du_lieu/dich_vu_firestore.dart';
import 'package:e09_elearning/services/ket_noi_api/api_tai_khoan.dart';
import 'package:e09_elearning/widgets/giao_dien_quan_tri.dart';
import 'package:e09_elearning/widgets/thong_bao_loi.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AccountSession.current = null);

  for (final actorId in ['root1', 'root2']) {
    testWidgets('both roots can reset an approved admin account: $actorId', (
      tester,
    ) async {
      AccountSession.current = AccountIdentity(
        id: actorId,
        role: 'super_admin',
      );
      final db = FakeFirebaseFirestore();
      await db.doc('password_reset_requests/u').set({
        'userId': 'u',
        'managerId': 'm1',
        'userRole': 'admin',
        'name': 'Học viên',
        'username': 'learner',
        'status': 'approved',
        'firstApprovedBy': 'root1',
        'secondApprovedBy': 'root2',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPasswordResetScreen(
              service: FirestoreService(firestore: db),
              embedded: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nhập mật khẩu mới'), findsOneWidget);
      expect(find.text('Đồng ý cấp lại'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('legacy admin reset is visible to either root: $actorId', (
      tester,
    ) async {
      AccountSession.current = AccountIdentity(
        id: actorId,
        role: 'super_admin',
      );
      final db = FakeFirebaseFirestore();
      await db.doc('users/helper').set({'role': 'admin', 'status': 'active'});
      await db.doc('password_reset_requests/helper').set({
        'userId': 'helper',
        'managerId': 'root1',
        'name': 'Admin phụ',
        'username': 'helper',
        'status': 'approved_once',
        'firstApprovedBy': 'root1',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPasswordResetScreen(
              service: FirestoreService(firestore: db),
              embedded: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Admin phụ (helper)'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Nhập mật khẩu mới'),
        findsNothing,
      );
      expect(
        find.widgetWithText(FilledButton, 'Đồng ý cấp lại'),
        actorId == 'root2' ? findsOneWidget : findsNothing,
      );
      // Đọc vai trò để hiển thị, không cần sửa dữ liệu yêu cầu cũ.
      expect(
        (await db.doc('password_reset_requests/helper').get()).data(),
        isNot(contains('userRole')),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'root2 badge and list include legacy and approved admin requests',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AccountSession.current = const AccountIdentity(
        id: 'root2',
        role: 'super_admin',
      );
      final db = FakeFirebaseFirestore();
      for (final id in ['legacy', 'approved', 'learner']) {
        await db.doc('users/$id').set({
          'name': id,
          'username': id,
          'status': 'active',
          'unit': 'D1',
          'role': id == 'learner' ? 'user' : 'admin',
          'createdBy': 'root1',
          'approvedBy': 'root2',
        });
        await db.doc('password_reset_requests/$id').set({
          'userId': id,
          'managerId': 'root1',
          'name': id,
          'username': id,
          'status': id == 'approved' ? 'approved' : 'pending',
          if (id == 'approved') 'userRole': 'admin',
          if (id == 'approved') 'firstApprovedBy': 'root1',
          if (id == 'approved') 'secondApprovedBy': 'root2',
        });
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: AdminUi.theme,
          home: AdminAccountScreen(service: FirestoreService(firestore: db)),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.widgetWithText(OutlinedButton, 'Cấp lại mật khẩu');
      final badge = tester.widget<Badge>(
        find.ancestor(of: button, matching: find.byType(Badge)).first,
      );
      expect((badge.label as Text).data, '2');
      expect(badge.isLabelVisible, isTrue);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('legacy (legacy)'), findsOneWidget);
      expect(find.text('approved (approved)'), findsOneWidget);
      expect(find.text('learner (learner)'), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Đồng ý cấp lại'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Nhập mật khẩu mới'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('root account recovery keeps its separate approval action', (
    tester,
  ) async {
    AccountSession.current = const AccountIdentity(
      id: 'root2',
      role: 'super_admin',
    );
    final db = FakeFirebaseFirestore();
    await db.doc('password_reset_requests/root1').set({
      'type': 'root_recovery',
      'userId': 'root1',
      'managerId': 'root1',
      'name': 'Admin tổng 1',
      'username': 'admintong1',
      'status': 'pending',
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(minutes: 30)),
      ),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminPasswordResetScreen(
            service: FirestoreService(firestore: db),
            embedded: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Duyệt yêu cầu'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Cấp lại mật khẩu'), findsNothing);
    await db.doc('password_reset_requests/root1').update({
      'status': 'approved',
    });
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Duyệt yêu cầu'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Cấp lại mật khẩu'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('request read error shows a warning badge and a visible error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AccountSession.current = const AccountIdentity(
      id: 'root2',
      role: 'super_admin',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AdminUi.theme,
        home: AdminAccountScreen(service: _FailedRequestService()),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.widgetWithText(OutlinedButton, 'Cấp lại mật khẩu');
    final badge = tester.widget<Badge>(
      find.ancestor(of: button, matching: find.byType(Badge)).first,
    );
    expect((badge.label as Text).data, '!');
    expect(badge.isLabelVisible, isTrue);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(AppErrorNotice), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'owning root submits a matching new password and closes the dialog safely',
    (tester) async {
      AccountSession.current = const AccountIdentity(
        id: 'root1',
        role: 'super_admin',
      );
      final db = FakeFirebaseFirestore();
      await db.doc('password_reset_requests/u').set({
        'userId': 'u',
        'managerId': 'root1',
        'userRole': 'user',
        'name': 'Học viên',
        'username': 'learner',
        'status': 'pending',
      });
      Map<String, dynamic>? submitted;
      final service = FirestoreService(
        firestore: db,
        accounts: AccountApi(
          transport: (method, data) async {
            expect(method, 'accountResolvePasswordReset');
            submitted = data;
            await db.doc('password_reset_requests/u').update({
              'status': 'completed',
            });
            return {'updated': true};
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPasswordResetScreen(service: service, embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cấp lại mật khẩu'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'new-password');
      await tester.enterText(
        find.byType(TextFormField).last,
        'different-password',
      );
      await tester.tap(find.text('Cấp lại'));
      await tester.pumpAndSettle();
      expect(submitted, isNull);
      expect(find.text('Mật khẩu nhập lại không khớp.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).last, 'new-password');
      await tester.tap(find.text('Cấp lại'));
      await tester.pumpAndSettle();
      expect(submitted, {
        'requestId': 'u',
        'userId': 'u',
        'password': 'new-password',
      });
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _FailedRequestService extends FirestoreService {
  _FailedRequestService() : super(firestore: FakeFirebaseFirestore());

  @override
  Stream<List<PasswordResetRequest>> getPasswordResetRequestsStream() =>
      Stream.error(StateError('Request lookup unavailable'));
}
