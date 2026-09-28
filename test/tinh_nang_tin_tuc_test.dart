import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/app/chu_de_hoc_vien.dart';
import 'package:e09_elearning/models/bai_viet_tin_tuc.dart';
import 'package:e09_elearning/models/bieu_mau_tin_tuc.dart';
import 'package:e09_elearning/models/anh_bia_trang_chu.dart';
import 'package:e09_elearning/models/tham_so_nguoi_dung.dart';
import 'package:e09_elearning/screens/user/danh_sach_tin_tuc.dart';
import 'package:e09_elearning/screens/user/bo_cuc_chinh_hoc_vien.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_tin_tuc.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_anh_bia_trang_chu.dart';
import 'package:e09_elearning/services/ket_noi_api/dich_vu_bai_kiem_tra_bao_mat.dart';
import 'package:e09_elearning/widgets/tien_ich_tin_tuc.dart';
import 'package:e09_elearning/widgets/khung_tin_tuc_trang_chu.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> seedNews(FakeFirebaseFirestore db) async {
  await db.doc('users/u').set({'name': 'Nguyễn Văn An', 'unit': 'E09'});
  for (final (id, title, category, days) in [
    ('one', 'Nâng cao kiến thức nghiệp vụ', 'Điểm tin', 0),
    ('two', 'Chủ trương học tập mới', 'Chủ trương chính sách', 2),
    ('three', 'Lịch học chuyên đề tháng 9', 'Thông tin học tập', 40),
  ]) {
    await db.doc('news/$id').set({
      'title': title,
      'summary': 'Cập nhật thông tin và kiến thức dành cho học viên E09.',
      'content': 'Nội dung chi tiết $id',
      'category': category,
      'published': true,
      'featured': id == 'one',
      'publishedAt': Timestamp.fromDate(
        DateTime.now().subtract(Duration(days: days, minutes: 15)),
      ),
    });
  }
  await db.doc('news/draft').set({'title': 'Nháp bí mật', 'published': false});
}

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_NEWS_PREVIEW')) {
      for (final entry in {
        'Arial': const String.fromEnvironment('PREVIEW_TEXT_FONT'),
        'MaterialIcons': const String.fromEnvironment('PREVIEW_ICON_FONT'),
      }.entries) {
        if (entry.value.isEmpty) continue;
        final loader = FontLoader(entry.key)
          ..addFont(File(entry.value).readAsBytes().then(ByteData.sublistView));
        await loader.load();
      }
    }
  });

  test('news metadata validates category and banner image', () {
    expect(
      () => NewsForm.toFirestore({
        'title': 'Tin',
        'content': 'Nội dung',
        'homeBanner': 'Có',
      }),
      throwsArgumentError,
    );
    expect(
      () => NewsForm.toFirestore({
        'title': 'Tin',
        'content': 'Nội dung',
        'category': 'Sai',
      }),
      throwsArgumentError,
    );
    expect(NewsArticle.normalize('Chủ trương ĐẢNG'), 'chu truong dang');
    final article = NewsArticle('n', {
      'title': 'Nghiệp vụ',
      'publishedAt': Timestamp.fromDate(DateTime(2026, 9, 16, 10)),
    });
    expect(article.matches('nghiep vu'), true);
    expect(
      article.timeLabel(now: DateTime(2026, 9, 16, 10, 20)),
      '20 phút trước',
    );
  });

  test(
    'home banners sort by position and expose at most five active images',
    () async {
      final db = FakeFirebaseFirestore();
      for (var index = 1; index <= 6; index++) {
        await db.doc('home_banners/$index').set({
          'imageUrl': 'https://example.org/$index.png',
          'title': 'Banner $index',
          'order': index,
          'active': true,
        });
      }
      await db.doc('home_banners/hidden').set({
        'imageUrl': 'https://example.org/hidden.png',
        'order': 0,
        'active': false,
      });
      final banners = await HomeBannerService(db).active().first;
      expect(banners, hasLength(5));
      expect(banners.map((banner) => banner.order), [1, 2, 3, 4, 5]);
      expect(
        HomeBanner.toFirestore({
          'imageUrl': 'https://example.org/banner.png',
          'order': '5',
          'active': 'Có',
        })['active'],
        true,
      );
    },
  );

  testWidgets('home banner advances automatically every five seconds', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.doc('home_banners/one').set({
      'imageUrl': 'icon:book',
      'title': 'Ảnh thứ nhất',
      'order': 1,
      'active': true,
    });
    await db.doc('home_banners/two').set({
      'imageUrl': 'icon:science',
      'title': 'Ảnh thứ hai',
      'order': 2,
      'active': true,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeNewsBanner(service: NewsService(db), uid: 'u', onStudy: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ảnh thứ nhất'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ảnh thứ hai'), findsOneWidget);
  });

  test('editing published news keeps its original publication date', () async {
    final db = FakeFirebaseFirestore();
    final date = Timestamp.fromDate(DateTime(2026, 1, 1));
    await db.doc('news/n').set({
      'title': 'Cũ',
      'published': true,
      'publishedAt': date,
    });
    await LearningService(db: db).saveContent('root', db.doc('news/n'), {
      'title': 'Mới',
      'published': true,
    });
    expect((await db.doc('news/n').get()).data()?['publishedAt'], date);
    await LearningService(db: db).saveContent('root', db.doc('news/new'), {
      'title': 'Mới',
      'published': true,
    });
    expect(
      (await db.doc('news/new').get()).data()?['publishedAt'],
      isA<Timestamp>(),
    );
  });

  testWidgets('search, categories and time filters select the right articles', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await seedNews(db);
    await tester.pumpWidget(
      MaterialApp(
        home: NewsScreen(service: LearningService(db: db)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nháp bí mật'), findsNothing);
    await tester.enterText(find.byType(TextField), 'chu truong');
    await tester.pumpAndSettle();
    expect(find.text('Chủ trương học tập mới'), findsOneWidget);
    expect(find.text('Nâng cao kiến thức nghiệp vụ'), findsNothing);
    await tester.tap(find.byTooltip('Xóa tìm kiếm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chủ trương chính sách'));
    await tester.pumpAndSettle();
    expect(find.byType(NewsTile), findsOneWidget);
    await tester.tap(find.text('Tất cả'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Lọc tin tức'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mọi thời gian'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('24 giờ qua').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(find.byType(NewsTile), findsOneWidget);
    expect(find.text('Nâng cao kiến thức nghiệp vụ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('news cannot be saved and unpublished articles disappear', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await seedNews(db);
    await tester.pumpWidget(
      MaterialApp(
        home: NewsScreen(service: LearningService(db: db)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Bài viết đã lưu'), findsNothing);
    await tester.tap(find.byType(NewsTile).first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Lưu bài viết'), findsNothing);
    expect(find.text('Nội dung chi tiết one'), findsOneWidget);
    await db.doc('news/one').update({'published': false});
    await tester.pumpAndSettle();
    expect(find.textContaining('Bài viết không còn được đăng'), findsOneWidget);
    expect(find.text('Nội dung chi tiết one'), findsNothing);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('home news and utilities work at $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FakeFirebaseFirestore();
      await seedNews(db);
      final preview = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: LearnerTheme.light,
          builder: (context, child) =>
              RepaintBoundary(key: preview, child: child!),
          home: UserMainLayout(
            args: const UserArguments(userId: 'u', userName: 'An'),
            learningService: LearningService(db: db),
            examService: SecureExamService(
              transport: (_, _) async => {'runs': []},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final tab in ['Trang chủ', 'Tin tức', 'Tiện ích']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
        if (const bool.fromEnvironment('CAPTURE_NEWS_PREVIEW') &&
            width == 390) {
          await tester.runAsync(() async {
            final boundary =
                preview.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('.tmp/news-preview-$tab.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
      await tester.tap(find.text('Lịch sử kiểm tra'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Lịch sử hiển thị khóa học đã kết thúc và đã làm xong bài kiểm tra.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
