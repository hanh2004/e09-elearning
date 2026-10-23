import 'dart:io';
import 'dart:typed_data';

import 'package:e09_elearning/services/tep/dich_vu_tai_anh.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

final class _PickedImage extends PlatformFile {
  _PickedImage(this.size);

  final int? size;
  var reads = 0;

  @override
  String get name => 'image.png';

  @override
  int? lengthSync() => size;

  @override
  Future<Uint8List> readAsBytes() async {
    reads++;
    return File('assets/sample-content/course-study.png').readAsBytesSync();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImagePicker extends FilePickerPlatform {
  _ImagePicker(this.image);

  final PlatformFile image;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in [0, ImageUploadService.maxBytes + 1]) {
    test(
      'rejects a known invalid size $size before reading image bytes',
      () async {
        final originalPicker = FilePickerPlatform.instance;
        addTearDown(() => FilePickerPlatform.instance = originalPicker);
        final image = _PickedImage(size);
        FilePickerPlatform.instance = _ImagePicker(image);

        await expectLater(
          ImageUploadService().pick(),
          throwsA(isA<ImageUploadException>()),
        );
        expect(image.reads, 0);
      },
    );
  }

  testWidgets('reads and validates an image when metadata has no size', (
    tester,
  ) async {
    final originalPicker = FilePickerPlatform.instance;
    addTearDown(() => FilePickerPlatform.instance = originalPicker);
    final image = _PickedImage(null);
    FilePickerPlatform.instance = _ImagePicker(image);

    final selected = await tester.runAsync(ImageUploadService().pick);

    expect(selected?.name, 'image.png');
    expect(image.reads, 1);
    expect(tester.takeException(), isNull);
  });
}
