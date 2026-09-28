// HÀM DÙNG CHUNG: ghi/xóa nhiều tài liệu Firestore theo từng lô an toàn.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Xóa các tài liệu theo từng lô nhỏ hơn giới hạn của Firestore.
/// Không tạo batch rỗng khi danh sách không có phần tử.
Future<void> deleteFirestoreDocuments(
  FirebaseFirestore db,
  Iterable<DocumentReference<Map<String, dynamic>>> documents, {
  int batchSize = 450,
}) async {
  if (batchSize < 1) {
    throw ArgumentError.value(batchSize, 'batchSize', 'Phải lớn hơn 0.');
  }
  final danhSach = documents.toList(growable: false);
  for (var batDau = 0; batDau < danhSach.length; batDau += batchSize) {
    final loGhi = db.batch();
    final ketThuc = batDau + batchSize < danhSach.length
        ? batDau + batchSize
        : danhSach.length;
    for (final document in danhSach.sublist(batDau, ketThuc)) {
      loGhi.delete(document);
    }
    await loGhi.commit();
  }
}
