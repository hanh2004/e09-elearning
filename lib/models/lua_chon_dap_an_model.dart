class LuaChonDapAnModel {
  final String maLuaChon;
  final String noiDung;
  final bool dapAnDung;

  LuaChonDapAnModel({
    required this.maLuaChon,
    required this.noiDung,
    required this.dapAnDung,
  });

  factory LuaChonDapAnModel.fromMap(Map<String, dynamic> map) {
    return LuaChonDapAnModel(
      maLuaChon: (map['ma_lua_chon'] ?? map['id'] ?? '').toString(),
      noiDung:
          (map['noi_dung'] ??
                  map['noiDung'] ??
                  map['text'] ??
                  map['content'] ??
                  map['answer'] ??
                  map['label'] ??
                  map['value'] ??
                  '')
              .toString(),
      dapAnDung:
          map['dap_an_dung'] == true ||
          map['dapAnDung'] == true ||
          map['isCorrect'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'ma_lua_chon': maLuaChon,
    'noi_dung': noiDung,
    'dap_an_dung': dapAnDung,
  };
}
