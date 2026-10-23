// DỮ LIỆU: Dữ liệu một lựa chọn trả lời trong câu hỏi.
// Giữ tên trường Firebase khi đổi cách hiển thị để đọc được dữ liệu đã lưu.

class LuaChonDapAnModel {
  final String maLuaChon;
  final String noiDung;
  final bool dapAnDung;

  LuaChonDapAnModel({
    required this.maLuaChon,
    required this.noiDung,
    required this.dapAnDung,
  });

  factory LuaChonDapAnModel.fromMap(Map<String, dynamic> bangAnhXa) {
    return LuaChonDapAnModel(
      maLuaChon: (bangAnhXa['ma_lua_chon'] ?? bangAnhXa['id'] ?? '').toString(),
      noiDung:
          (bangAnhXa['noi_dung'] ??
                  bangAnhXa['noiDung'] ??
                  bangAnhXa['text'] ??
                  bangAnhXa['content'] ??
                  bangAnhXa['answer'] ??
                  bangAnhXa['label'] ??
                  bangAnhXa['value'] ??
                  '')
              .toString(),
      dapAnDung:
          bangAnhXa['dap_an_dung'] == true ||
          bangAnhXa['dapAnDung'] == true ||
          bangAnhXa['isCorrect'] == true,
    );
  }
}
