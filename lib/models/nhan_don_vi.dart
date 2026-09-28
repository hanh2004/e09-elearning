// DỮ LIỆU: Hiển thị tên đơn vị từ hồ sơ, hỗ trợ dữ liệu cũ.
// Giữ tên trường Firebase khi đổi cách hiển thị để đọc được dữ liệu đã lưu.

String unitLabel(Map<String, dynamic> duLieu) {
  final donVi = (duLieu['unit'] ?? '').toString().trim();
  final prefix = (duLieu['subUnit'] ?? '').toString().trim();
  if (prefix.isEmpty) return donVi;
  return donVi.isEmpty ? prefix : '$prefix-$donVi';
}
