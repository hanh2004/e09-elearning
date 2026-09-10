import 'package:e09_elearning/models/admin_report.dart';
import 'package:e09_elearning/models/account_identity.dart';
import 'package:e09_elearning/screens/admin/admin_report_screen.dart';
import 'package:e09_elearning/services/firestore_service.dart';
import 'package:e09_elearning/app/app_theme.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final users = <String, Map<String, dynamic>>{
    'u': {'name': 'An', 'role': 'user', 'unit': 'A', 'classId': '1'},
    'v': {'name': 'Bình', 'role': 'user', 'unit': 'B', 'classId': '2'},
    'w': {'name': 'Châu', 'role': 'user', 'unit': 'A', 'classId': '1'},
  };
  final exams = <String, Map<String, dynamic>>{
    'e': {'title': 'Nghiệp vụ'},
  };
  final attempts = <Map<String, dynamic>>[
    {
      'userId': 'u',
      'examId': 'e',
      'attemptCount': 2,
      'bestScore': 6,
      'passed': false,
    },
    {
      'userId': 'u',
      'examId': 'e',
      'attemptCount': 1,
      'bestScore': 8,
      'passed': true,
    },
    {
      'userId': 'v',
      'examId': 'e',
      'attemptCount': 1,
      'bestScore': 4,
      'passed': false,
    },
  ];
  test(
    'reports merge learner/exam scores without discarding submitted counts',
    () {
      final report = AdminReport.build(
        users: users,
        exams: exams,
        attempts: attempts,
      );
      expect(report.attempts, 4);
      expect(report.rows.length, 2);
      expect(report.participants, 2);
      expect(report.passRate, 50);
      expect(report.average, 6);
      final unit = AdminReport.build(
        users: users,
        exams: exams,
        attempts: attempts,
        unit: 'A',
      );
      expect(unit.studentCount, 2);
      expect(unit.participants, 1);
      expect(unit.attempts, 3);
      expect(unit.average, 8);
      expect(unit.passRate, 100);
    },
  );
  test('missing points are unknown, never silently graded zero', () {
    final report = AdminReport.build(
      users: users,
      exams: exams,
      attempts: [
        {'userId': 'u', 'examId': 'e', 'status': 'completed'},
      ],
    );
    expect(report.ungraded, 1);
    expect(report.average, isNull);
    expect(report.passRate, isNull);
  });
  for (final width in [390.0, 1440.0]) {
    testWidgets('unit report filters and fits $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AccountSession.current = const AccountIdentity(
        id: 'root',
        role: 'super_admin',
      );
      addTearDown(() => AccountSession.current = null);
      final db = FakeFirebaseFirestore();
      for (final user in users.entries) {
        await db.doc('users/${user.key}').set(user.value);
      }
      await db.doc('users/root').set({
        'name': 'Root',
        'role': 'super_admin',
        'unit': 'E09',
      });
      await db.doc('exams/e').set(exams['e']!);
      for (var i = 0; i < attempts.length; i++) {
        await db.doc('exam_attempts/$i').set(attempts[i]);
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminReportScreen(service: FirestoreService(firestore: db)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tổng quan kết quả học tập'), findsOneWidget);
      await tester.tap(find.text('Tất cả đơn vị'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Tiến độ theo đơn vị'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.text('0 quản trị viên • 2 học viên\nĐã làm: 1 • Chưa làm: 1'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('0 quản trị viên • 2 học viên\nĐã làm: 1 • Chưa làm: 1'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
