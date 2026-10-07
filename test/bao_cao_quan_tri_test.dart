import 'package:e09_elearning/models/bao_cao_quan_tri.dart';
import 'package:e09_elearning/services/lay_du_lieu_bao_cao_quan_tri.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/models/dinh_danh_tai_khoan.dart';
import 'package:e09_elearning/screens/admin/bao_cao_thong_ke.dart';
import 'package:e09_elearning/services/du_lieu/dich_vu_firestore.dart';
import 'package:e09_elearning/app/chu_de_ung_dung.dart';
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
  test(
    'Excel date range counts only runs submitted inside that range',
    () async {
      final db = FakeFirebaseFirestore();
      await db.doc('exam_attempts/legacy').set({
        'userId': 'u',
        'examId': 'e',
        'attemptCount': 2,
        'bestScore': 9,
        'lastAttemptAt': Timestamp.fromDate(DateTime(2026, 9, 20)),
      });
      await db.doc('exam_attempts/legacy/runs/1').set({
        'score': 9,
        'completedAt': Timestamp.fromDate(DateTime(2026, 8, 20)),
      });
      await db.doc('exam_attempts/legacy/runs/2').set({
        'score': 5,
        'completedAt': Timestamp.fromDate(DateTime(2026, 9, 20)),
      });
      await db.doc('exam_attempts/secure_session').set({
        'userId': 'v',
        'examId': 'e',
        'attemptCount': 2,
        'bestScore': 10,
      });
      await db.doc('exam_sessions/session/runs/a').set({
        'score': 10,
        'status': 'completed',
        'completedAt': Timestamp.fromDate(DateTime(2026, 8, 21)),
      });
      await db.doc('exam_sessions/session/runs/b').set({
        'score': 6,
        'status': 'completed',
        'completedAt': Timestamp.fromDate(DateTime(2026, 9, 21)),
      });
      final summaries = (await db.collection('exam_attempts').get()).docs;
      final selected = await AdminReportAttempts.trongKhoang(
        db: db,
        summaries: summaries,
        userIds: {'u', 'v'},
        from: DateTime(2026, 9),
        until: DateTime(2026, 10),
      );
      final report = AdminReport.build(
        users: users,
        exams: exams,
        attempts: selected,
      );
      expect(report.attempts, 2);
      expect(report.rows.singleWhere((row) => row.userId == 'u').score, 5);
      expect(report.rows.singleWhere((row) => row.userId == 'v').score, 6);
      final onlyUnit = await AdminReportAttempts.trongKhoang(
        db: db,
        summaries: summaries,
        userIds: {'u'},
        from: DateTime(2026, 9),
        until: DateTime(2026, 10),
      );
      expect(onlyUnit.length, 1);
    },
  );
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
        find.text('0 quản lý • 2 học viên'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('0 quản lý • 2 học viên'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
