// DỮ LIỆU: Chuyển dữ liệu câu hỏi từ Firebase sang đối tượng Dart.
// Giữ tên trường Firebase khi đổi cách hiển thị để đọc được dữ liệu đã lưu.

import 'mo_hinh_lua_chon_dap_an.dart';

class CauHoiModel {
  final String maCauHoi;
  final String noiDung;
  final String loaiCauHoi; // SINGLE_CHOICE, MULTIPLE_CHOICE, ESSAY
  final List<LuaChonDapAnModel> dsLuaChon;

  CauHoiModel({
    required this.maCauHoi,
    required this.noiDung,
    required this.loaiCauHoi,
    required this.dsLuaChon,
  });

  bool get isValidForExam {
    final content = noiDung.trim();
    final validOptionCount = dsLuaChon
        .where((luaChon) => luaChon.noiDung.trim().isNotEmpty)
        .length;
    return loaiCauHoi == 'SINGLE_CHOICE' &&
        dsLuaChon.where((luaChon) => luaChon.dapAnDung).length == 1 &&
        content.isNotEmpty &&
        content != 'Câu hỏi chưa có nội dung' &&
        validOptionCount >= 2 &&
        validOptionCount == dsLuaChon.length;
  }

  factory CauHoiModel.fromMap(Map<String, dynamic> bangAnhXa, String docId) {
    List<LuaChonDapAnModel> convertedOptions = [];

    final rawOptions =
        bangAnhXa['options'] ??
        bangAnhXa['ds_lua_chon'] ??
        bangAnhXa['dsLuaChon'] ??
        bangAnhXa['answers'] ??
        bangAnhXa['choices'] ??
        bangAnhXa['dap_an'] ??
        bangAnhXa['cac_dap_an'];
    final optionList = rawOptions is List ? rawOptions : const [];
    final rawCorrect =
        bangAnhXa['correctAnswerIndex'] ??
        bangAnhXa['correctIndex'] ??
        bangAnhXa['correctAnswer'] ??
        bangAnhXa['dap_an_dung'] ??
        bangAnhXa['dapAnDung'];
    var correctIndex = rawCorrect is num
        ? rawCorrect.toInt()
        : int.tryParse(rawCorrect?.toString() ?? '') ?? -1;
    if (correctIndex < 0 && rawCorrect is String && rawCorrect.length == 1) {
      final letterIndex = rawCorrect.toUpperCase().codeUnitAt(0) - 65;
      if (letterIndex >= 0 && letterIndex < optionList.length) {
        correctIndex = letterIndex;
      }
    }

    for (var viTri = 0; viTri < optionList.length; viTri++) {
      final rawOption = optionList[viTri];
      if (rawOption is Map) {
        final luaChon = LuaChonDapAnModel.fromMap(
          Map<String, dynamic>.from(rawOption),
        );
        convertedOptions.add(
          LuaChonDapAnModel(
            maLuaChon: luaChon.maLuaChon.isEmpty
                ? viTri.toString()
                : luaChon.maLuaChon,
            noiDung: luaChon.noiDung,
            dapAnDung: luaChon.dapAnDung || viTri == correctIndex,
          ),
        );
      } else {
        final vanBan = rawOption.toString();
        convertedOptions.add(
          LuaChonDapAnModel(
            maLuaChon: viTri.toString(),
            noiDung: vanBan,
            dapAnDung: viTri == correctIndex || rawCorrect == vanBan,
          ),
        );
      }
    }

    return CauHoiModel(
      maCauHoi: docId,
      noiDung:
          (bangAnhXa['noi_dung'] ??
                  bangAnhXa['questionText'] ??
                  bangAnhXa['question'] ??
                  bangAnhXa['noiDung'] ??
                  bangAnhXa['content'] ??
                  bangAnhXa['text'] ??
                  bangAnhXa['cau_hoi'] ??
                  'Câu hỏi chưa có nội dung')
              .toString(),
      loaiCauHoi: bangAnhXa['loai_cau_hoi'] ?? 'SINGLE_CHOICE',
      dsLuaChon: convertedOptions,
    );
  }
}
