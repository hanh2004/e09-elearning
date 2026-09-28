// DỮ LIỆU: Thông tin phiên thi đang thực hiện.
// Giữ tên trường Firebase khi đổi cách hiển thị để đọc được dữ liệu đã lưu.

class ExamAttemptSession {
  final String attemptId;
  final DateTime? startedAt;
  final DateTime endsAt;
  final Map<int, int> selectedAnswers;
  final int currentQuestionIndex;

  const ExamAttemptSession({
    required this.attemptId,
    this.startedAt,
    required this.endsAt,
    required this.selectedAnswers,
    required this.currentQuestionIndex,
  });
}
