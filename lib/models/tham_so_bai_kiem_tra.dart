// DỮ LIỆU: Dữ liệu truyền vào màn hình làm bài thi.
// Giữ tên trường Firebase khi đổi cách hiển thị để đọc được dữ liệu đã lưu.

import 'mo_hinh_cau_hoi.dart';

class ExamArguments {
  final String maBaiKiemTra;
  final List<String> dsMaCauHoi;
  final String maNguoiDung;
  final int thoiGianLamBaiPhut;
  final String tenBaiKiemTra;
  final int? soLuotLamToiDa;
  final List<CauHoiModel> questions;
  final String? courseId, lessonId;

  const ExamArguments({
    required this.maBaiKiemTra,
    required this.dsMaCauHoi,
    required this.maNguoiDung,
    this.thoiGianLamBaiPhut = 45,
    this.tenBaiKiemTra = 'Bài kiểm tra',
    this.soLuotLamToiDa,
    this.questions = const [],
    this.courseId,
    this.lessonId,
  });
}
