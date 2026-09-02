class CauTraLoiModel {
  final String maCauTraLoi;
  final String maCauHoi;
  final String? maLuaChon; // Nullable nếu là câu tự luận
  final String? noiDungTraLoi; // Nullable nếu là trắc nghiệm
  final bool traLoiDung;
  final double diemDatDuoc;

  CauTraLoiModel({
    required this.maCauTraLoi,
    required this.maCauHoi,
    this.maLuaChon,
    this.noiDungTraLoi,
    required this.traLoiDung,
    required this.diemDatDuoc,
  });

  factory CauTraLoiModel.fromMap(Map<String, dynamic> map, String id) {
    return CauTraLoiModel(
      maCauTraLoi: id,
      maCauHoi: map['ma_cau_hoi'] ?? '',
      maLuaChon: map['ma_lua_chon'],
      noiDungTraLoi: map['noi_dung_tra_loi'],
      traLoiDung: map['tra_loi_dung'] ?? false,
      diemDatDuoc: (map['diem_dat_duoc'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'ma_cau_hoi': maCauHoi,
    'ma_lua_chon': maLuaChon,
    'noi_dung_tra_loi': noiDungTraLoi,
    'tra_loi_dung': traLoiDung,
    'diem_dat_duoc': diemDatDuoc,
  };
}
