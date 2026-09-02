import 'cau_hoi_model.dart';

class ExamArguments {
  final String maBaiKiemTra;
  final List<String> dsMaCauHoi;
  final String maNguoiDung;
  final int thoiGianLamBaiPhut;
  final String tenBaiKiemTra;
  final int? soLuotLamToiDa;
  final List<CauHoiModel> questions;

  const ExamArguments({
    required this.maBaiKiemTra,
    required this.dsMaCauHoi,
    required this.maNguoiDung,
    this.thoiGianLamBaiPhut = 45,
    this.tenBaiKiemTra = 'Bài kiểm tra',
    this.soLuotLamToiDa,
    this.questions = const [],
  });
}
