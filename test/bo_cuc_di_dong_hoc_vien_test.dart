import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/app/chu_de_hoc_vien.dart';
import 'package:e09_elearning/models/tham_so_nguoi_dung.dart';
import 'package:e09_elearning/screens/user/bo_cuc_chinh_hoc_vien.dart';
import 'package:e09_elearning/screens/user/tien_ich_hoc_vien.dart';
import 'package:e09_elearning/screens/user/lam_bai_kiem_tra_bao_mat.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:e09_elearning/services/ket_noi_api/dich_vu_bai_kiem_tra_bao_mat.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_LEARNER_PREVIEW')) {
      for (final entry in {
        'Arial': const String.fromEnvironment('PREVIEW_TEXT_FONT'),
        'MaterialIcons': const String.fromEnvironment('PREVIEW_ICON_FONT'),
      }.entries) {
        if (entry.value.isEmpty) continue;
        final loader = FontLoader(entry.key);
        loader.addFont(
          File(entry.value).readAsBytes().then(ByteData.sublistView),
        );
        await loader.load();
      }
    }
  });
  for (final width in [320.0, 375.0, 430.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('learner tabs fit phone $width at text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = FakeFirebaseFirestore();
        final previewKey = GlobalKey();
        await db.collection('users').doc('u').set({
          'name': 'Học viên có họ tên dài để kiểm tra giao diện',
          'unit': 'D1',
        });
        await db.collection('courses').doc('c').set({
          'title': 'Bồi dưỡng kiến thức và kỹ năng nghiệp vụ dành cho học viên',
          'subject': 'Nghiệp vụ',
          'published': true,
          'description': 'Nội dung khóa học',
        });
        await db.collection('learning_notifications').doc('n').set({
          'title': 'Thông báo bài học mới',
          'body': 'Học viên vui lòng xem nội dung bài học.',
          'audience': 'all',
          'sendAt': Timestamp.now(),
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: LearnerTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(
                key: previewKey,
                child: LearnerViewport(child: child!),
              ),
            ),
            home: UserMainLayout(
              args: UserArguments(userId: 'u', userName: 'Học viên', email: ''),
              learningService: LearningService(db: db),
              examService: SecureExamService(
                transport: (_, _) async => {'exams': <dynamic>[]},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(NavigationRail), findsNothing);
        for (final label in [
          'Học tập',
          'Kiểm tra',
          'Tin tức',
          'Tiện ích',
          'Thông báo',
          'Cá nhân',
          'Trang chủ',
        ]) {
          if (label == 'Thông báo' || label == 'Cá nhân') {
            await tester.tap(find.text('Tiện ích').last);
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.text(label),
              150,
              scrollable: find
                  .descendant(
                    of: find.byType(UserUtilitiesScreen),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await tester.pumpAndSettle();
          }
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: label);
          if (label == 'Thông báo' || label == 'Cá nhân') {
            expect(find.byTooltip('Back'), findsOneWidget, reason: label);
            await tester.pageBack();
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$label back');
          }
          if (const bool.fromEnvironment('CAPTURE_LEARNER_PREVIEW') &&
              width == 375 &&
              scale == 1) {
            await tester.runAsync(() async {
              final boundary =
                  previewKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File('.tmp/learner-preview-$label.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
        await tester.pumpWidget(
          MaterialApp(
            theme: LearnerTheme.light,
            home: const SecureExamResultScreen(
              result: {
                'title': 'Kết quả bài kiểm tra',
                'score': 8.0,
                'passed': true,
                'correctAnswers': 8,
                'totalQuestions': 10,
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
