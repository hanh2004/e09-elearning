import 'package:e09_elearning/screens/user/profile_edit_screen.dart';
import 'package:e09_elearning/models/admin_report.dart';
import 'package:e09_elearning/services/ket_noi_api/account_api.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'learner selects manager options and cannot select removed unit',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.doc('users/u').set({
        'name': 'An',
        'unit': 'D1',
        'createdBy': 'm1',
        'subUnit': 'Đội cũ',
      });
      final api = AccountApi(
        transport: (method, input) async {
          expect(method, 'accountGetSubUnits');
          expect(input, isEmpty);
          return {
            'managerId': 'm1',
            'subUnits': ['Đội 1', 'Đội 2'],
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileEditScreen(
            uid: 'u',
            firestore: db,
            accounts: api,
            openEditor: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Đội cũ'), findsNothing);
      await tester.tap(find.text('Đội 2').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect((await db.doc('users/u').get()).data()!['subUnit'], 'Đội 2');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed options load leaves profile unchanged', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/u').set({
      'name': 'An',
      'unit': 'D1',
      'createdBy': 'm1',
      'subUnit': 'Đội cũ',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileEditScreen(
          uid: 'u',
          firestore: db,
          openEditor: true,
          accounts: AccountApi(
            transport: (_, _) async => throw StateError('offline'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Không tải được danh sách trực thuộc'),
      findsOneWidget,
    );
    expect(find.text('Lưu'), findsNothing);
    expect((await db.doc('users/u').get()).data()!['subUnit'], 'Đội cũ');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'falls back to the direct manager profile when function is unavailable',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.doc('users/u').set({
        'name': 'An',
        'unit': 'D',
        'createdBy': 'm1',
        'subUnit': '',
      });
      await db.doc('users/m1').set({
        'role': 'admin',
        'status': 'active',
        'unit': 'D',
        'subUnits': ['C1', 'C2'],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileEditScreen(
            uid: 'u',
            firestore: db,
            openEditor: true,
            accounts: AccountApi(
              transport: (_, _) async => throw FirebaseFunctionsException(
                code: 'unavailable',
                message: 'function is not deployed',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
    expect(find.text('C1'), findsWidgets);
    expect(find.text('C2'), findsWidgets);
      expect(
        find.textContaining('Không tải được danh sách trực thuộc'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('learner updates subordinate unit without changing admin unit', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/u').set({
      'name': 'An',
      'unit': 'Đơn vị A',
      'classId': '1',
      'role': 'user',
      'avatarUrl': 'https://example.org/old-avatar.png',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileEditScreen(uid: 'u', firestore: db),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is NetworkImage,
      ),
      findsNothing,
    );
    await tester.tap(find.text('Cập nhật hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Đơn vị trực thuộc (tổ/đội/bộ phận)'),
      'Đội 1',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    final user = (await db.doc('users/u').get()).data()!;
    expect(user['unit'], 'Đơn vị A');
    expect(user['subUnit'], 'Đội 1');
    expect(find.textContaining('Đơn vị: Đội 1-Đơn vị A'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final report = AdminReport.build(
      users: {'u': user},
      exams: {
        'e': {'title': 'Đề'},
      },
      attempts: [
        {'userId': 'u', 'examId': 'e', 'status': 'completed', 'bestScore': 8},
      ],
      search: 'Đội 1',
    );
    expect(report.studentCount, 1);
    expect(report.rows.single.subUnit, 'Đội 1');
    expect(report.rows.single.unit, 'Đơn vị A');
  });
}
