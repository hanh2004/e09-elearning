import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/models/account_identity.dart';
import 'package:e09_elearning/screens/admin/admin_account_screen.dart';
import 'package:e09_elearning/screens/admin/admin_notifications_screen.dart';
import 'package:e09_elearning/services/ket_noi_api/account_api.dart';
import 'package:e09_elearning/services/du_lieu/firestore_service.dart';
import 'package:e09_elearning/services/nghiep_vu/learning_service.dart';
import 'package:e09_elearning/widgets/profile_card.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(
    () => AccountSession.current = const AccountIdentity(
      id: 'root',
      role: 'super_admin',
    ),
  );
  tearDown(() => AccountSession.current = null);
  for (final audience in ['all', 'managers', 'user:u']) {
    testWidgets(
      'notification edit preserves $audience until explicit recipient choice',
      (tester) async {
        final db = FakeFirebaseFirestore();
        await db.doc('learning_notifications/n').set({
          'title': 'Tin riêng',
          'body': 'Nội dung',
          'audience': audience,
          'sendAt': Timestamp.fromDate(DateTime(2026, 9, 1, 8)),
        });
        await tester.pumpWidget(
          MaterialApp(
            home: AdminNotificationsScreen(service: LearningService(db: db)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Sửa thông báo'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lưu'));
        await tester.pumpAndSettle();
        expect(
          (await db.doc('learning_notifications/n').get()).data()!['audience'],
          audience,
        );
        await tester.tap(find.byTooltip('Sửa thông báo'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Quản lý').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lưu'));
        await tester.pumpAndSettle();
        expect(
          (await db.doc('learning_notifications/n').get()).data()!['audience'],
          'managers',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'root hidden, code searchable and transfer uses selected manager at phone width',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FakeFirebaseFirestore();
      for (final id in ['root', 'm1', 'm2', 'u']) {
        await db.doc('users/$id').set({
          'name': id == 'root' ? 'Hidden Root' : id,
          'username': id,
          'role': id == 'root'
              ? 'super_admin'
              : id == 'u'
              ? 'user'
              : 'admin',
          'status': 'active',
          'unit': id == 'm2' ? 'D2' : 'D1',
          'createdBy': id == 'u' ? 'm1' : 'root',
          if (id == 'u') 'userCode': 'D1-001',
        });
      }
      Map<String, dynamic>? payload;
      final service = FirestoreService(
        firestore: db,
        accounts: AccountApi(
          transport: (method, data) async {
            expect(method, 'accountReassignUser');
            payload = data;
            return {'updated': true};
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: AdminAccountScreen(service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hidden Root'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'D1-001');
      await tester.pumpAndSettle();
      expect(find.text('u'), findsOneWidget);
      expect(find.text('m2'), findsNothing);
      await tester.tap(find.byTooltip('Chuyển cho quản lý khác'));
      await tester.pumpAndSettle();
      final dropdown = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('m2 • D2').last);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        findsNothing,
      );
      await tester.tap(find.text('Chuyển'));
      await tester.pumpAndSettle();
      expect(payload, {'userId': 'u', 'managerId': 'm2'});
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('unit change includes learners hidden by account search', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/m1').set({
      'name': 'Manager One',
      'username': 'manager1',
      'role': 'admin',
      'status': 'active',
      'unit': 'D1',
      'createdBy': 'root',
    });
    for (final id in ['u1', 'u2']) {
      await db.doc('users/$id').set({
        'name': id,
        'username': id,
        'role': 'user',
        'status': 'active',
        'unit': 'D1',
        'createdBy': 'm1',
      });
    }
    Map<String, dynamic>? payload;
    final service = FirestoreService(
      firestore: db,
      accounts: AccountApi(
        transport: (method, data) async {
          expect(method, 'accountSetUnit');
          payload = data;
          return {'updated': true};
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: AdminAccountScreen(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Manager One');
    await tester.pumpAndSettle();
    expect(find.text('u1'), findsNothing);
    await tester.tap(find.byTooltip('Phân đơn vị'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    expect(fields, findsOneWidget);
    await tester.enterText(fields.at(0), 'D3');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(payload, {'userId': 'm1', 'unit': 'D3'});
    expect(tester.takeException(), isNull);
  });
  testWidgets('profile shows assigned code and never invents a legacy code', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/u').set({'unit': 'D1', 'username': 'legacy'});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileCard(
            uid: 'u',
            fallbackName: 'An',
            service: LearningService(db: db),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mã người dùng: Chưa được cấp'), findsOneWidget);
    expect(find.textContaining('D1-legacy'), findsNothing);
    await db.doc('users/u').update({'userCode': 'D1-001'});
    await tester.pumpAndSettle();
    expect(find.text('Mã người dùng: D1-001'), findsOneWidget);
  });
}
