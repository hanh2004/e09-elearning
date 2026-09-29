import 'package:e09_elearning/models/dinh_danh_tai_khoan.dart';
import 'package:e09_elearning/screens/admin/yeu_cau_dat_lai_mat_khau.dart';
import 'package:e09_elearning/services/du_lieu/dich_vu_firestore.dart';
import 'package:e09_elearning/services/ket_noi_api/api_tai_khoan.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AccountSession.current = null);

  for (final actorId in ['root1', 'root2']) {
    testWidgets('second approval is offered only to the other root: $actorId', (
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
        'name': 'Học viên',
        'username': 'learner',
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
      expect(
        find.text('Duyệt lần 2'),
        actorId == 'root2' ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

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
        'name': 'Học viên',
        'username': 'learner',
        'status': 'approved',
        'firstApprovedBy': 'root1',
        'secondApprovedBy': 'root2',
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
