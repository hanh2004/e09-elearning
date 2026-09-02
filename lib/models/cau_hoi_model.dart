import 'package:cloud_firestore/cloud_firestore.dart';

import 'lua_chon_dap_an_model.dart';

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
        .where((option) => option.noiDung.trim().isNotEmpty)
        .length;
    return content.isNotEmpty &&
        content != 'Câu hỏi chưa có nội dung' &&
        validOptionCount >= 2;
  }

  factory CauHoiModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> map = doc.data() as Map<String, dynamic>;
    return CauHoiModel.fromMap(map, doc.id);
  }

  factory CauHoiModel.fromMap(Map<String, dynamic> map, String docId) {
    List<LuaChonDapAnModel> convertedOptions = [];

    final rawOptions =
        map['options'] ??
        map['ds_lua_chon'] ??
        map['dsLuaChon'] ??
        map['answers'] ??
        map['choices'] ??
        map['dap_an'] ??
        map['cac_dap_an'];
    final optionList = rawOptions is List ? rawOptions : const [];
    final rawCorrect =
        map['correctAnswerIndex'] ??
        map['correctIndex'] ??
        map['correctAnswer'] ??
        map['dap_an_dung'] ??
        map['dapAnDung'];
    var correctIndex = rawCorrect is num
        ? rawCorrect.toInt()
        : int.tryParse(rawCorrect?.toString() ?? '') ?? -1;
    if (correctIndex < 0 && rawCorrect is String && rawCorrect.length == 1) {
      final letterIndex = rawCorrect.toUpperCase().codeUnitAt(0) - 65;
      if (letterIndex >= 0 && letterIndex < optionList.length) {
        correctIndex = letterIndex;
      }
    }

    for (var index = 0; index < optionList.length; index++) {
      final rawOption = optionList[index];
      if (rawOption is Map) {
        final option = LuaChonDapAnModel.fromMap(
          Map<String, dynamic>.from(rawOption),
        );
        convertedOptions.add(
          LuaChonDapAnModel(
            maLuaChon: option.maLuaChon.isEmpty
                ? index.toString()
                : option.maLuaChon,
            noiDung: option.noiDung,
            dapAnDung: option.dapAnDung || index == correctIndex,
          ),
        );
      } else {
        final text = rawOption.toString();
        convertedOptions.add(
          LuaChonDapAnModel(
            maLuaChon: index.toString(),
            noiDung: text,
            dapAnDung: index == correctIndex || rawCorrect == text,
          ),
        );
      }
    }

    return CauHoiModel(
      maCauHoi: docId,
      noiDung:
          (map['noi_dung'] ??
                  map['questionText'] ??
                  map['question'] ??
                  map['noiDung'] ??
                  map['content'] ??
                  map['text'] ??
                  map['cau_hoi'] ??
                  'Câu hỏi chưa có nội dung')
              .toString(),
      loaiCauHoi: map['loai_cau_hoi'] ?? 'SINGLE_CHOICE',
      dsLuaChon: convertedOptions,
    );
  }

  Map<String, dynamic> toMap() => {
    'noi_dung': noiDung,
    'loai_cau_hoi': loaiCauHoi,
    'ds_lua_chon': dsLuaChon.map((x) => x.toMap()).toList(),
  };
}
