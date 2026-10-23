// XỬ LÝ DỮ LIỆU / API: Chọn ảnh từ thiết bị, kiểm tra định dạng/kích thước và tải lên Firebase Storage.
// Các màn hình gọi mã ở đây; quyền truy cập cuối cùng do Firebase/API kiểm tra.

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Lỗi tải ảnh có thông báo an toàn để hiển thị trong form.
class ImageUploadException implements Exception {
  const ImageUploadException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SelectedUploadImage {
  const SelectedUploadImage({required this.bytes, required this.name});
  final Uint8List bytes;
  final String name;
  String get extension => name.split('.').last.toLowerCase();
}

class ImageUploadService {
  static const maxSizeMB = 20;
  static const maxBytes = maxSizeMB * 1024 * 1024;

  Future<SelectedUploadImage?> pick() async {
    final tep = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (tep == null) return null;
    final knownSize = tep.lengthSync();
    if (knownSize != null) _validateSize(knownSize);
    final duLieuByte = await tep.readAsBytes();
    final anh = SelectedUploadImage(bytes: duLieuByte, name: tep.name);
    validate(anh);
    try {
      final codec = await ui.instantiateImageCodec(
        duLieuByte,
        targetWidth: 800,
      );
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
    } catch (_) {
      throw const ImageUploadException(
        'Không đọc được ảnh. Hãy chọn file JPG, PNG hoặc WebP hợp lệ.',
      );
    }
    return anh;
  }

  static void validate(SelectedUploadImage anh) {
    _validateSize(anh.bytes.length);
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(anh.extension)) {
      throw const ImageUploadException('Chỉ hỗ trợ ảnh JPG, PNG hoặc WebP.');
    }
  }

  static void _validateSize(int bytes) {
    if (bytes < 1 || bytes > maxBytes) {
      throw const ImageUploadException(
        'Chọn ảnh có dung lượng từ 1 byte đến 20 MB.',
      );
    }
  }

  Future<String> upload(
    String thuMuc,
    SelectedUploadImage anh, {
    void Function(double tienDo)? onProgress,
  }) async {
    validate(anh);
    final duoiTep = anh.extension;
    final reference = FirebaseStorage.instance
        .ref()
        .child(thuMuc)
        .child('${DateTime.now().microsecondsSinceEpoch}.$duoiTep');
    final task = reference.putData(
      anh.bytes,
      SettableMetadata(
        contentType: 'image/${duoiTep == 'jpg' ? 'jpeg' : duoiTep}',
      ),
    );
    final dangKyTheoDoi = task.snapshotEvents.listen((duLieuNhan) {
      if (duLieuNhan.totalBytes > 0) {
        onProgress?.call(duLieuNhan.bytesTransferred / duLieuNhan.totalBytes);
      }
    }, onError: (Object _) {});
    try {
      await task.timeout(
        const Duration(seconds: 90),
        onTimeout: () async {
          await task.cancel();
          throw const ImageUploadException(
            'Tải ảnh quá lâu. Kiểm tra mạng rồi bấm Lưu để thử lại.',
          );
        },
      );
      return await reference.getDownloadURL().timeout(
        const Duration(seconds: 20),
      );
    } on TimeoutException {
      throw const ImageUploadException(
        'Chưa lấy được đường dẫn ảnh. Kiểm tra mạng rồi thử lại.',
      );
    } on FirebaseException catch (loi) {
      final thongDiep = switch (loi.code) {
        'permission-denied' || 'unauthorized' => 'Hình ảnh tải lên không thành công: tài khoản không có quyền tải ảnh. Vui lòng liên hệ quản lý tổng.',
        'unauthenticated' => 'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại.',
        'canceled' => 'Đã hủy tải ảnh.',
        'bucket-not-found' || 'no-default-bucket' =>
          'Kho ảnh chưa được cấu hình trên Firebase Storage.',
        'retry-limit-exceeded' =>
          'Kết nối tải ảnh bị gián đoạn. Kiểm tra mạng rồi thử lại.',
        'quota-exceeded' =>
          'Kho ảnh đã hết hạn mức. Cần kiểm tra dung lượng và gói Firebase.',
        _ =>
          'Hình ảnh tải lên không thành công (${loi.code}). Vui lòng thử lại.',
      };
      throw ImageUploadException(thongDiep);
    } finally {
      await dangKyTheoDoi.cancel();
    }
  }
}
