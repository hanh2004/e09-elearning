// DỮ LIỆU: Mã và tên đề thi truyền sang trang ngân hàng câu hỏi.
// Giữ tên trường Firebase khi đổi cách hiển thị để đọc được dữ liệu đã lưu.

class QuestionBankArguments {
  final String examId;
  final String examTitle;

  const QuestionBankArguments({required this.examId, required this.examTitle});
}
