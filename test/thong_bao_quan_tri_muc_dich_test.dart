import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/models/dinh_danh_tai_khoan.dart';
import 'package:e09_elearning/screens/admin/quan_ly_thong_bao.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AccountSession.current = const AccountIdentity(
      id: 'root',
      role: 'super_admin',
    );
  });
  tearDown(() => AccountSession.current = null);

  for (final entry in const {
    'Khóa học về thiết bị': 'Học tập',
    'Nhắc lịch thi: cuối khóa': 'Làm bài kiểm tra',
  }.entries) {
    testWidgets('legacy purpose correctly classifies ${entry.key}', (
      tester,
    ) async {
      final db = FakeFirebaseFirestore();
      await db.doc('learning_notifications/n').set({
        'title': entry.key,
        'body': 'Nội dung thông báo',
        'audience': 'all',
        'sendAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
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
        (await db.doc('learning_notifications/n').get()).data()!['purpose'],
        entry.value,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('notification content is hidden until its row is opened', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.doc('learning_notifications/notice').set({
      'title': 'Thông báo thử',
      'body': 'Nội dung cần được mở',
      'audience': 'all',
      'sendAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: AdminNotificationsScreen(service: LearningService(db: db)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nội dung cần được mở'), findsNothing);
    await tester.tap(find.text('Thông báo thử'));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung cần được mở'), findsOneWidget);

    await tester.tap(find.text('Thông báo thử'));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung cần được mở'), findsNothing);
  });

  testWidgets('manager filter shows only notifications sent to managers', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final sentAt = Timestamp.fromDate(DateTime(2026, 9, 1));
    await db.doc('learning_notifications/all').set({
      'title': 'Gửi tất cả',
      'body': 'Nội dung chung',
      'audience': 'all',
      'sendAt': sentAt,
    });
    await db.doc('learning_notifications/managers').set({
      'title': 'Gửi quản lý',
      'body': 'Nội dung quản lý',
      'audience': 'managers',
      'sendAt': sentAt,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: AdminNotificationsScreen(service: LearningService(db: db)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lọc: Tất cả'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi cho quản lý'));
    await tester.pumpAndSettle();

    expect(find.text('Gửi quản lý'), findsOneWidget);
    expect(find.text('Gửi tất cả'), findsNothing);
  });

  testWidgets('filtering does not open a different notification body', (
    tester,
  ) async {
    final db = await _notificationFixtures();
    await _showNotifications(tester, db);

    await tester.tap(find.text('Gửi tất cả'));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung chung'), findsOneWidget);

    await tester.tap(find.text('Lọc: Tất cả'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi cho quản lý'));
    await tester.pumpAndSettle();

    expect(find.text('Nội dung quản lý'), findsNothing);
  });

  testWidgets('live reordering keeps the opened body with its notification', (
    tester,
  ) async {
    final db = await _notificationFixtures();
    await _showNotifications(tester, db);

    await tester.tap(find.text('Gửi quản lý'));
    await tester.pumpAndSettle();
    await db.doc('learning_notifications/managers').update({
      'sendAt': Timestamp.fromDate(DateTime(2026, 9, 3)),
    });
    await tester.pumpAndSettle();

    expect(find.text('Nội dung quản lý'), findsOneWidget);
    expect(find.text('Nội dung chung'), findsNothing);
  });

  testWidgets('repeated edit clicks open one notification editor', (
    tester,
  ) async {
    final db = await _notificationFixtures();
    await _showNotifications(tester, db);
    final edit = tester
        .widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.edit_outlined).first,
        )
        .onPressed!;
    edit();
    edit();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog, skipOffstage: false), findsOneWidget);
  });

  for (final width in [390.0, 760.0, 1200.0]) {
    testWidgets('notifications remain usable at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = await _notificationFixtures();
      await _showNotifications(tester, db);

      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Gửi tất cả'));
      await tester.pumpAndSettle();
      expect(find.text('Nội dung chung'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<FakeFirebaseFirestore> _notificationFixtures() async {
  final db = FakeFirebaseFirestore();
  for (final audience in ['all', 'managers']) {
    await db.doc('learning_notifications/$audience').set({
      'title': audience == 'all' ? 'Gửi tất cả' : 'Gửi quản lý',
      'body': audience == 'all' ? 'Nội dung chung' : 'Nội dung quản lý',
      'audience': audience,
      'sendAt': Timestamp.fromDate(
        DateTime(2026, 9, audience == 'all' ? 2 : 1),
      ),
    });
  }
  return db;
}

Future<void> _showNotifications(
  WidgetTester tester,
  FakeFirebaseFirestore db,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AdminNotificationsScreen(service: LearningService(db: db)),
    ),
  );
  await tester.pumpAndSettle();
}
