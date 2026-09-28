// DỮ LIỆU: Dữ liệu truyền vào trang xem kết quả thi.
// Giữ tên trường Firebase khi đổi cách hiển thị để đọc được dữ liệu đã lưu.

class ExamResultArguments {
  final double diemSo;
  final int tongSoCau;
  final int soCauDung;
  final String thoiGianLamBai;

  const ExamResultArguments({
    required this.diemSo,
    required this.tongSoCau,
    required this.soCauDung,
    required this.thoiGianLamBai,
  });
}
