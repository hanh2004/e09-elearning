import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:e09_elearning/services/tep/dich_vu_tai_anh.dart';
import 'package:e09_elearning/widgets/tien_ich_giao_dien_hoc_tap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestUploader extends ImageUploadService {
  final image = SelectedUploadImage(
    bytes: File('assets/sample-content/course-study.png').readAsBytesSync(),
    name: 'course-study.png',
  );
  int uploads = 0;
  Completer<String> result = Completer<String>();
  @override
  Future<SelectedUploadImage?> pick() async => image;
  @override
  Future<String> upload(
    String folder,
    SelectedUploadImage image, {
    void Function(double progress)? onProgress,
  }) {
    expect(folder, 'courses');
    uploads++;
    onProgress?.call(.5);
    return result.future;
  }
}

void main() {
  test('client accepts 20 MB and rejects oversized or unsupported files', () {
    ImageUploadService.validate(
      SelectedUploadImage(
        bytes: Uint8List(20 * 1024 * 1024),
        name: 'photo.JPG',
      ),
    );
    for (final image in [
      SelectedUploadImage(
        bytes: Uint8List(20 * 1024 * 1024 + 1),
        name: 'large.png',
      ),
      SelectedUploadImage(bytes: Uint8List(0), name: 'empty.png'),
      SelectedUploadImage(bytes: Uint8List(10), name: 'file.txt'),
    ]) {
      expect(
        () => ImageUploadService.validate(image),
        throwsA(isA<ImageUploadException>()),
      );
    }
  });

  testWidgets(
    'preview precedes upload; failed upload retains selection for retry',
    (tester) async {
      final uploader = TestUploader();
      Map<String, String>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => editLearningRecord(
                  context,
                  title: 'Tạo khóa học',
                  fields: {},
                  imageFolder: 'courses',
                  imageService: uploader,
                  imageRequired: true,
                  save: (values) async {
                    saved = values;
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
      await tester.tap(find.text('Chọn ảnh từ thiết bị (tối đa 20 MB)'));
      await tester.pumpAndSettle();
      expect(uploader.uploads, 0);
      expect(find.text('course-study.png'), findsOneWidget);
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        isA<ResizeImage>(),
      );
      await tester.tap(find.text('Lưu'));
      await tester.pump();
      expect(saved, isNull);
      expect(find.text('Đang tải ảnh: 50%'), findsOneWidget);
      uploader.result.completeError(
        const ImageUploadException('Kết nối bị gián đoạn'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kết nối bị gián đoạn'), findsNWidgets(2));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('course-study.png'), findsOneWidget);
      expect(saved, isNull);
      uploader.result = Completer<String>();
      await tester.tap(find.text('Lưu'));
      await tester.pump();
      uploader.result.complete('https://example.org/uploaded.png');
      await tester.pumpAndSettle();
      expect(saved?['imageUrl'], 'https://example.org/uploaded.png');
      expect(uploader.uploads, 2);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
