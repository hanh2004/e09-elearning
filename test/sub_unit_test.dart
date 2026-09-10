import 'package:e09_elearning/screens/user/profile_edit_screen.dart';
import 'package:e09_elearning/models/admin_report.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('learner updates subordinate unit without changing admin unit', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/u').set({
      'name': 'An',
      'unit': 'Đơn vị A',
      'classId': '1',
      'role': 'user',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileEditScreen(uid: 'u', firestore: db),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cập nhật hồ sơ'));
    await tester.pumpAndSettle();
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
