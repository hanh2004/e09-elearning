import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:e09_elearning/app/chu_de_hoc_vien.dart';
import 'package:e09_elearning/screens/user/cac_khoa_hoc.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:e09_elearning/widgets/anh_bia_khoa_hoc.dart';
import 'package:e09_elearning/widgets/tien_ich_giao_dien_hoc_tap.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets('library details, chapters and reader fit $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FakeFirebaseFirestore();
      await db.doc('courses/c').set({
        'title': 'Luật hình sự',
        'published': true,
        'subject': 'Pháp luật',
        'instructor': 'Giảng viên E09',
        'objectives': 'Nắm kiến thức cơ bản\nVận dụng trong công tác',
        'description': 'Nội dung chuyên đề',
      });
      for (var i = 1; i <= 2; i++) {
        await db.doc('courses/c/lessons/l$i').set({
          'title': 'Bài $i',
          'chapter': 'Chương 1',
          'order': i,
          'content': 'Nội dung học tập',
          'minimumStudySeconds': 2,
        });
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: LearnerTheme.light,
          home: UserCoursesScreen(
            uid: 'u',
            service: LearningService(db: db),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CourseCover), findsOneWidget);
      expect(find.text('2 bài học'), findsOneWidget);
      await tester.tap(find.text('Vào học'));
      await tester.pumpAndSettle();
      expect(find.text('Giảng viên E09'), findsOneWidget);
      await tester.ensureVisible(find.text('BẮT ĐẦU HỌC NGAY'));
      await tester.tap(find.text('BẮT ĐẦU HỌC NGAY'));
      await tester.pumpAndSettle();
      expect(find.text('Tiến độ học tập'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục học'));
      await tester.pumpAndSettle();
      expect(find.byType(CourseCover), findsOneWidget);
      expect(find.text('Nội dung học tập'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(
        (await db.doc('users/u/learning/c_l1').get()).data()?['completed'],
        true,
      );
      await tester.tap(find.text('Bài tiếp theo'));
      await tester.pumpAndSettle();
      expect(find.text('Bài 2'), findsWidgets);
      expect(find.text('HOÀN THÀNH BÀI HỌC'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('content editor requires a cover without saving empty data', (
    tester,
  ) async {
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => editLearningRecord(
                context,
                title: 'Ảnh bìa',
                fields: {},
                imageFolder: 'courses',
                imageRequired: true,
                save: (_) async {
                  saved = true;
                },
              ),
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(saved, false);
    expect(
      find.text('Vui lòng chọn ảnh bìa từ thiết bị trước khi lưu.'),
      findsNWidgets(2),
    );
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
  });
}
