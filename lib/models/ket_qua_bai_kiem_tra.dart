// DỮ LIỆU: Đọc điểm và kết quả đạt/chưa đạt, hỗ trợ bản ghi cũ.
// Giữ tên trường Firebase khi đổi cách hiển thị để đọc được dữ liệu đã lưu.

class ExamOutcome {
  static double score(Map<String, dynamic> giaTri) =>
      ((giaTri['bestScore'] ?? giaTri['diemSo'] ?? giaTri['score']) as num?)
          ?.toDouble() ??
      0;

  // Dữ liệu cũ chưa có điểm đạt tùy chỉnh nên dùng mức 5/10.
  static bool passed(Map<String, dynamic> giaTri) => giaTri['passed'] is bool
      ? giaTri['passed'] as bool
      : score(giaTri) >= ((giaTri['passScore'] as num?)?.toDouble() ?? 5);
}
