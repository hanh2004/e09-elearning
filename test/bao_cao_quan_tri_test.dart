import 'package:e09_elearning/models/bao_cao_quan_tri.dart';
import 'package:e09_elearning/services/lay_du_lieu_bao_cao_quan_tri.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/models/dinh_danh_tai_khoan.dart';
import 'package:e09_elearning/screens/admin/bao_cao_thong_ke.dart';
import 'package:e09_elearning/screens/admin/bao_cao_khoa_hoc.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:e09_elearning/screens/admin/theo_doi_tien_do_hoc_tap.dart';
import 'package:e09_elearning/screens/admin/tong_quan_hoc_tap.dart';
import 'package:e09_elearning/services/du_lieu/dich_vu_firestore.dart';
import 'package:e09_elearning/services/nguon_du_lieu_bao_cao_quan_tri.dart';
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
  test('report reads submission dates directly from summary fields', () {
    final best = DateTime(2026, 9, 1);
    final latest = DateTime(2026, 9, 3);
    final report = AdminReport.build(
      users: users,
      exams: exams,
      attempts: [
        {
          'userId': 'u',
          'examId': 'e',
          'attemptCount': 2,
          'bestScore': 8,
          'bestCompletedAt': Timestamp.fromDate(best),
          'lastAttemptAt': latest,
        },
      ],
    );
    expect(report.rows.single.bestAt, best);
    expect(report.rows.single.submittedAt, latest);
  });

  testWidgets('course exam statistics merge summaries and retain earlier submissions', (
    tester,
  ) async {
    AccountSession.current = const AccountIdentity(id: 'root', role: 'super_admin');
    addTearDown(() => AccountSession.current = null);
    final db = FakeFirebaseFirestore();
    await db.doc('courses/c').set({
      'title': 'Khóa đã kết thúc',
      'endsAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
      'examId': 'e',
    });
    for (final (id, userId, status, count, score) in [
      ('best', 'u', 'in_progress', 2, 8),
      ('older', 'u', 'completed', 1, 6),
      ('pending', 'v', 'in_progress', 0, null),
      ('ungraded', 'w', 'completed', 1, null),
    ]) {
      await db.doc('exam_attempts/$id').set({
        'userId': userId,
        'courseId': 'c',
        'examId': 'e',
        'status': status,
        'attemptCount': count,
        'score': score,
      });
    }
    await tester.pumpWidget(
      MaterialApp(
        home: AdminCourseReportScreen(
          course: (await db.collection('courses').get()).docs.single,
          service: LearningService(db: db),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Đã nộp: 2/3 • Điểm trung bình: 8.0'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Đã nộp: 2/3 • Điểm trung bình: 8.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final dashboard in [false, true]) {
    testWidgets('report tabs agree on score fields and missing grades ($dashboard)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FakeFirebaseFirestore();
      for (final id in ['u', 'v']) {
        await db.doc('users/$id').set(users[id]!);
      }
      await db.doc('courses/c').set({
        'title': 'Khóa có kiểm tra',
        'published': true,
        'learningMode': 'study_exam',
        'examId': 'e',
      });
      await db.doc('courses/c/lessons/l').set({'title': 'Bài học'});
      await db.doc('exams/e').set({...exams['e']!, 'courseId': 'c'});
      for (final id in ['u', 'v']) {
        await db.doc('exam_attempts/$id').set({
          'userId': id,
          'examId': 'e',
          'courseId': 'c',
          'status': 'completed',
          if (id == 'u') dashboard ? 'bestScore' : 'score': 8,
          'completedAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
        });
      }
      final data = AdminReportData.fromSnapshots(
        users: await db.collection('users').get(),
        courses: await db.collection('courses').get(),
        exams: await db.collection('exams').get(),
        attempts: await db.collection('exam_attempts').get(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: dashboard
                ? AdminLearningDashboard(reportData: data)
                : AdminProgressScreen(reportData: data),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (dashboard) {
        expect(find.text('Đã thi • 8.0'), findsOneWidget);
        expect(find.text('Chưa thi'), findsOneWidget);
      } else {
        expect(find.text('8.0'), findsOneWidget);
        await tester.tap(find.text('Nghiệp vụ'));
        await tester.pumpAndSettle();
        expect(find.text('Thiếu điểm'), findsOneWidget);
        expect(find.text('0.0'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
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
