import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/app/app_theme.dart';
import 'package:e09_elearning/app/app_portal.dart';
import 'package:e09_elearning/app/elearning_app.dart';
import 'package:e09_elearning/models/exam_outcome.dart';
import 'package:e09_elearning/models/user_arguments.dart';
import 'package:e09_elearning/models/account_identity.dart';
import 'package:e09_elearning/models/question_bank_arguments.dart';
import 'package:e09_elearning/screens/admin/admin_question_bank_screen.dart';
import 'package:e09_elearning/screens/admin/admin_home_screen.dart';
import 'package:e09_elearning/services/firestore_service.dart';
import 'package:e09_elearning/screens/user/user_dashboard_screen.dart';
import 'package:e09_elearning/screens/user/user_notifications_screen.dart';
import 'package:e09_elearning/screens/user/user_main_layout.dart';
import 'package:e09_elearning/services/secure_exam_service.dart';
import 'package:e09_elearning/services/learning_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_UI')) return;
  await tester.runAsync(
    () => precacheImage(const AssetImage(AppTheme.logo), key.currentContext!),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/review/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets('editing an existing question preserves its ID and other data', (
    tester,
  ) async {
    AccountSession.current = const AccountIdentity(
      id: 'root1',
      role: 'super_admin',
    );
    addTearDown(() => AccountSession.current = null);
    final db = FakeFirebaseFirestore();
    await db.doc('exams/e/questions/q').set({
      'questionText': 'Nội dung cũ',
      'options': ['A', 'B', 'C', 'D'],
      'correctAnswerIndex': 1,
      'explanation': 'Giải thích cũ',
      'customTag': 'giữ nguyên',
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminQuestionBankScreen(
          args: const QuestionBankArguments(examId: 'e', examTitle: 'Đề'),
          service: FirestoreService(firestore: db),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sửa câu hỏi'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Nội dung đã cập nhật',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    final doc = (await db.doc('exams/e/questions/q').get()).data()!;
    expect(doc['questionText'], 'Nội dung đã cập nhật');
    expect(doc['customTag'], 'giữ nguyên');
    expect(doc['correctAnswerIndex'], 1);
    expect((await db.collection('exams/e/questions').get()).docs.length, 1);
    expect(tester.takeException(), isNull);
  });
  test('reports preserve server pass decision and old record fallback', () {
    expect(ExamOutcome.passed({'bestScore': 6, 'passScore': 8}), false);
    expect(ExamOutcome.passed({'bestScore': 8, 'passScore': 8}), true);
    expect(ExamOutcome.passed({'bestScore': 6, 'passed': false}), false);
    expect(ExamOutcome.passed({'diemSo': 5}), true);
  });
  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'dashboard, course reader and notification receipts at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        if (const bool.fromEnvironment('CAPTURE_UI')) {
          await tester.runAsync(() async {
            final bytes = await File('C:/Windows/Fonts/arial.ttf')
                .readAsBytes();
            for (final family in ['Arial', 'Roboto']) {
              await (FontLoader(
                family,
              )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
            }
            final icons = await File(
              'D:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes();
            await (FontLoader(
              'MaterialIcons',
            )..addFont(Future.value(ByteData.sublistView(icons)))).load();
          });
        }
        final db = FakeFirebaseFirestore();
        final service = LearningService(db: db);
        await db.doc('users/u').set({'name': 'Học viên E09', 'classId': 'A'});
        await db.doc('courses/c').set({
          'title': 'Kiến thức nghiệp vụ',
          'subject': 'Nghiệp vụ',
          'description': 'Tài liệu bồi dưỡng kiến thức',
          'published': true,
          'audience': 'class:A',
        });
        await db.doc('courses/c/lessons/l').set({
          'title': 'Bài học đầu tiên',
          'content': 'Nội dung học tập.',
          'chapter': 'Chương 1',
          'order': 1,
          'type': 'text',
        });
        final boundaryKey = GlobalKey();
        int selected = -1;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              home: UserDashboardScreen(
                args: UserArguments(
                  userId: 'u',
                  userName: 'Học viên',
                  email: '',
                ),
                service: service,
                onSelect: (index) => selected = index,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Học viên E09'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_UI')) {
          await tester.runAsync(
            () => precacheImage(
              const AssetImage(AppTheme.logo),
              boundaryKey.currentContext!,
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('build/review/dashboard-${width.toInt()}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.text('KHÁM PHÁ KHÓA HỌC'));
        expect(selected, 1);
        await tester.scrollUntilVisible(find.text('Kiến thức nghiệp vụ'), 250);
        await tester.tap(find.text('Kiến thức nghiệp vụ'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tiếp tục học'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hoàn thành bài học'));
        await tester.pumpAndSettle();
        expect(
          (await db.doc('users/u/learning/c_l').get()).data()?['completed'],
          true,
        );
        expect(find.text('Đã học • Đánh dấu chưa học'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await db.doc('learning_notifications/n').set({
          'title': 'Lịch học mới',
          'body': 'Kiểm tra lịch học của bạn.',
          'audience': 'class:A',
          'sendAt': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 5)),
          ),
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: UserNotificationsScreen(uid: 'u', service: service),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Chưa đọc (1)'), findsOneWidget);
        await tester.tap(find.text('Đánh dấu đã đọc'));
        await tester.pumpAndSettle();
        expect(
          (await db.doc('users/u/notification_reads/n').get()).exists,
          true,
        );
        await tester.tap(find.text('Chưa đọc (0)'));
        await tester.pumpAndSettle();
        expect(find.text('Bạn đã đọc tất cả thông báo.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final shellKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: shellKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              home: UserMainLayout(
                args: UserArguments(
                  userId: 'u',
                  userName: 'Học viên',
                  email: '',
                ),
                learningService: service,
                examService: SecureExamService(
                  transport: (_, _) async => {
                    'exams': <Map<String, dynamic>>[],
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await capture(tester, shellKey, 'app-${width.toInt()}');
        if (width < 900) {
          expect(
            tester
                .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
                .items
                .length,
            5,
          );
          await tester.tap(find.text('Kiểm tra'));
        } else {
          expect(
            tester
                .widget<NavigationRail>(find.byType(NavigationRail))
                .destinations
                .length,
            5,
          );
          await tester.tap(find.text('Kiểm tra'));
        }
        await tester.pumpAndSettle();
        expect(find.text('Bài kiểm tra'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_UI')) {
          final loginKey = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: loginKey,
              child: ElearningApp(
                portal: AppPortal.user,
                homeBuilder: (_) => const SizedBox(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await capture(tester, loginKey, 'login-${width.toInt()}');
          expect(tester.takeException(), isNull);
          AccountSession.current = const AccountIdentity(
            id: 'root1',
            role: 'super_admin',
          );
          final adminKey = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: adminKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                home: const AdminHomeScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await capture(tester, adminKey, 'admin-${width.toInt()}');
          expect(tester.takeException(), isNull);
          AccountSession.current = null;
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
