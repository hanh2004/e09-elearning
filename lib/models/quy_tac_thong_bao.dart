/// Suy ra mục đích cho thông báo cũ chưa lưu trường purpose.
String defaultNotificationPurpose(String title) {
  final normalized = title.toLowerCase();
  if (RegExp(r'(^|[\s:,.!?;()])thi($|[\s:,.!?;()])').hasMatch(normalized) ||
      normalized.contains('kiểm tra')) {
    return 'Làm bài kiểm tra';
  }
  if (normalized.contains('khóa học') || normalized.contains('bài học')) {
    return 'Học tập';
  }
  return 'Thông báo chung';
}
