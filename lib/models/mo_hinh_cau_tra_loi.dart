// DỮ LIỆU: Dữ liệu câu trả lời của học viên khi lưu hoặc nộp bài.
// Giữ tên trường Firebase khi đổi cách hiển thị để đọc được dữ liệu đã lưu.

class CauTraLoiModel {
  final String maCauHoi;
  final String? maLuaChon; // Nullable nếu là câu tự luận
  final String? noiDungTraLoi; // Nullable nếu là trắc nghiệm
  final bool traLoiDung;
  final double diemDatDuoc;

  CauTraLoiModel({
    required this.maCauHoi,
    this.maLuaChon,
    this.noiDungTraLoi,
    required this.traLoiDung,
    required this.diemDatDuoc,
  });

  Map<String, dynamic> toMap() => {
    'ma_cau_hoi': maCauHoi,
    'ma_lua_chon': maLuaChon,
    'noi_dung_tra_loi': noiDungTraLoi,
    'tra_loi_dung': traLoiDung,
    'diem_dat_duoc': diemDatDuoc,
  };
}
