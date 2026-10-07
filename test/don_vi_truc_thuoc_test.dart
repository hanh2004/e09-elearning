import 'package:e09_elearning/models/bao_cao_quan_tri.dart';
import 'package:e09_elearning/services/ket_noi_api/api_tai_khoan.dart';
import 'package:e09_elearning/services/tai_khoan/thao_tac_tai_khoan_hoc_vien.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
      await _moCapNhatDonVi(tester, db, accounts: api);
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
    await _moCapNhatDonVi(
      tester,
      db,
      accounts: AccountApi(
        transport: (_, _) async => throw StateError('offline'),
      ),
    );
    expect(
      find.textContaining('Cập nhật đơn vị trực thuộc đang bị lỗi: offline'),
      findsOneWidget,
    );
    expect(find.text('Lưu'), findsNothing);
    expect((await db.doc('users/u').get()).data()!['subUnit'], 'Đội cũ');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'falls back to the manager profile when the function is unavailable',
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
      await _moCapNhatDonVi(
        tester,
        db,
        accounts: AccountApi(
          transport: (_, _) async => throw FirebaseFunctionsException(
            code: 'unavailable',
            message: 'function is not deployed',
          ),
        ),
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('C1'), findsWidgets);
      expect(find.text('C2'), findsWidgets);
      expect(
        find.textContaining('Không thể tải thông tin đơn vị'),
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
    await _moCapNhatDonVi(tester, db);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is NetworkImage,
      ),
      findsNothing,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Đơn vị trực thuộc (tổ/đội/bộ phận)'),
      'Đội 1',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    final user = (await db.doc('users/u').get()).data()!;
    expect(user['unit'], 'Đơn vị A');
    expect(user['subUnit'], 'Đội 1');
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
