// XỬ LÝ DỮ LIỆU / API: Đọc file Excel nhập học viên, kiểm tra từng dòng và tạo bản xem trước.
// Các màn hình gọi mã ở đây; quyền truy cập cuối cùng do Firebase/API kiểm tra.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:xml/xml.dart';

import '../../models/du_lieu_nhap_hoc_vien.dart';

class UserExcelImport {
  static const maxFileBytes = 2 * 1024 * 1024;
  static const templateAsset = 'lib/assets/templates/users_template.xlsx';
  static const headers = [
    'Họ và tên',
    'Tên đăng nhập',
    'Mật khẩu',
    'Mã người dùng',
  ];

  UserImportPreview parse(Uint8List duLieuByte) {
    if (duLieuByte.isEmpty || duLieuByte.length > maxFileBytes) {
      return const UserImportPreview(
        errors: ['File phải có dữ liệu và không vượt quá 2 MB.'],
      );
    }
    try {
      final soExcel = decode(duLieuByte);
      final trangTinh =
          soExcel.tables['Users'] ??
          (soExcel.tables.length == 1 ? soExcel.tables.values.first : null);
      if (trangTinh == null) {
        return const UserImportPreview(
          errors: ['Không tìm thấy sheet Users. Hãy dùng file mẫu.'],
        );
      }
      return parseRows(
        trangTinh.rows
            .map((dong) => dong.map((oDuLieu) => oDuLieu?.value).toList())
            .toList(),
      );
    } catch (_) {
      return const UserImportPreview(
        errors: ['Không đọc được file Excel. Chỉ nhận .xlsx không mã hóa.'],
      );
    }
  }

  /// Excel 4.x yêu cầu tên phần tử SpreadsheetML không có tiền tố.
  /// Một số phần mềm tạo tệp hợp lệ lại dùng x:workbook/x:styleSheet.
  /// Chỉ chuẩn hóa tiền tố phần tử và đường dẫn quan hệ /xl/ trong bộ nhớ.
  /// Nội dung ô và công thức được giữ nguyên, tệp gốc không bị sửa.
  Excel decode(Uint8List duLieuByte) {
    if (duLieuByte.isEmpty || duLieuByte.length > maxFileBytes) {
      throw const FormatException('File size limit');
    }
    final archive = ZipDecoder().decodeBytes(duLieuByte);
    if (archive.length > 100 ||
        archive.files.fold<int>(0, (kichThuoc, tep) => kichThuoc + tep.size) >
            20 * 1024 * 1024) {
      throw const FormatException('Expanded workbook size limit');
    }
    final normalized = Archive();
    final namespace = RegExp(
      r'''xmlns:([A-Za-z_][\w.-]*)\s*=\s*["']http://schemas.openxmlformats.org/spreadsheetml/2006/main["']''',
    );
    for (final tep in archive.files) {
      if (!tep.isFile) continue;
      var duLieu = tep.content as List<int>;
      if (tep.name.startsWith('xl/') && tep.name.endsWith('.xml')) {
        var xml = utf8.decode(duLieu);
        final prefixes = namespace
            .allMatches(xml)
            .map((match) => match.group(1)!)
            .toSet();
        for (final prefix in prefixes) {
          xml = xml.replaceAll('<$prefix:', '<').replaceAll('</$prefix:', '</');
        }
        if (tep.name.startsWith('xl/worksheets/')) {
          final document = XmlDocument.parse(xml);
          for (final oDuLieu in document.findAllElements('c')) {
            if (oDuLieu.findElements('f').isNotEmpty) {
              // Luôn giữ ô công thức ở dạng công thức, kể cả khi có kết quả
              // chuỗi được lưu sẵn, để bước kiểm tra có thể từ chối chúng.
              oDuLieu.setAttribute('t', 'n');
            } else if (oDuLieu.getAttribute('t') == 'str') {
              final giaTri =
                  oDuLieu.findElements('v').firstOrNull?.innerText ?? '';
              oDuLieu.setAttribute('t', 'inlineStr');
              oDuLieu.children.clear();
              oDuLieu.children.add(
                XmlElement(XmlName('is'), [], [
                  XmlElement(XmlName('t'), [], [XmlText(giaTri)]),
                ]),
              );
            }
          }
          xml = document.toXmlString();
        }
        duLieu = utf8.encode(xml);
      }
      if (tep.name == 'xl/_rels/workbook.xml.rels') {
        final xml = utf8
            .decode(duLieu)
            .replaceAllMapped(
              RegExp(r'''Target=(["'])/xl/'''),
              (match) => 'Target=${match.group(1)}',
            );
        duLieu = utf8.encode(xml);
      }
      normalized.addFile(ArchiveFile(tep.name, duLieu.length, duLieu));
    }
    return Excel.decodeBytes(ZipEncoder().encode(normalized)!);
  }

  // Tách khỏi đọc/ghi tệp để có thể kiểm thử việc kiểm tra mà không cần Firebase.
  UserImportPreview parseRows(List<List<CellValue?>> source) {
    if (source.isEmpty) {
      return const UserImportPreview(errors: ['File Excel trống.']);
    }
    String text(CellValue? giaTri) =>
        giaTri is TextCellValue ? giaTri.value.toString() : '';
    bool blank(CellValue? giaTri) =>
        giaTri == null ||
        giaTri is TextCellValue && text(giaTri).trim().isEmpty;
    final dauTrang = source.first;
    const aliases = [
      {'họ và tên', 'name'},
      {'tên đăng nhập', 'username'},
      {'mật khẩu', 'password'},
    ];
    const codeAliases = {'mã người dùng', 'user code', 'code'};
    if (dauTrang.length < 3 ||
        List.generate(3, (i) => i).any(
          (i) => !aliases[i].contains(text(dauTrang[i]).trim().toLowerCase()),
        ) ||
        (dauTrang.length >= 4 &&
            !codeAliases.contains(text(dauTrang[3]).trim().toLowerCase())) ||
        dauTrang.skip(4).any((oDuLieu) => !blank(oDuLieu))) {
      return const UserImportPreview(
        errors: [
          'Dòng 1 cần 3 cột bắt buộc: Họ và tên, Tên đăng nhập, Mật khẩu; cột Mã người dùng là tùy chọn. Không thêm cột vai trò.',
        ],
      );
    }
    final hasCodeColumn = dauTrang.length >= 4;
    final cacDong = <UserImportRow>[];
    for (var i = 1; i < source.length; i++) {
      final cells = source[i];
      if (cells.every(blank)) continue;
      if (cacDong.length >= UserImportPreview.maxUsers) {
        return const UserImportPreview(
          errors: ['Mỗi lần chỉ nhập tối đa 200 học viên. Hãy chia nhỏ file.'],
        );
      }
      final errors = <String>[];
      final cacGiaTri = <String>[];
      final codeCell = hasCodeColumn && cells.length > 3 ? cells[3] : null;
      final userCodeSuffix = text(codeCell).trim();
      if (!blank(codeCell) && codeCell is! TextCellValue) {
        errors.add('Mã người dùng phải là Text.');
      }
      if (userCodeSuffix.isNotEmpty &&
          !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.@-]{0,63}$')
              .hasMatch(userCodeSuffix)) {
        errors.add(
          'Mã người dùng là phần đuôi: 1–64 ký tự không dấu, số, _, ., @ hoặc -.',
        );
      }
      for (var col = 0; col < 3; col++) {
        final giaTri = col < cells.length ? cells[col] : null;
        if (blank(giaTri)) {
          errors.add('Thiếu ${headers[col].toLowerCase()}.');
        } else if (giaTri is! TextCellValue) {
          errors.add(
            '${headers[col]} phải là Text, không dùng số, ngày hoặc công thức.',
          );
        }
        cacGiaTri.add(text(giaTri).trim());
      }
      if (cells.skip(hasCodeColumn ? 4 : 3).any((oDuLieu) => !blank(oDuLieu))) {
        errors.add('Có dữ liệu ngoài ${hasCodeColumn ? 4 : 3} cột cho phép.');
      }
      if (cacGiaTri[0].length > 100) errors.add('Họ và tên tối đa 100 ký tự.');
      if (cacGiaTri[1].isNotEmpty &&
          !RegExp(r'^[A-Za-z0-9_.@-]{3,64}$').hasMatch(cacGiaTri[1])) {
        errors.add(
          'Tên đăng nhập dài 3–64 ký tự: chữ không dấu, số, _, ., @, -.',
        );
      }
      if (cacGiaTri[2].isNotEmpty &&
          (cacGiaTri[2].length < 6 || cacGiaTri[2].length > 128)) {
        errors.add('Mật khẩu dài 6–128 ký tự.');
      }
      cacDong.add(
        UserImportRow(
          rowNumber: i + 1,
          name: cacGiaTri[0],
          username: cacGiaTri[1],
          password: cacGiaTri[2],
          userCodeSuffix: userCodeSuffix.isEmpty ? null : userCodeSuffix,
          errors: errors,
        ),
      );
    }
    if (cacDong.isEmpty) {
      return const UserImportPreview(
        errors: ['Chưa có học viên. Điền dữ liệu từ dòng 2 trong sheet Users.'],
      );
    }
    final counts = <String, int>{};
    for (final dong in cacDong) {
      final khoa = dong.username.toLowerCase();
      counts[khoa] = (counts[khoa] ?? 0) + 1;
    }
    return UserImportPreview(
      rows: cacDong
          .map(
            (dong) =>
                dong.username.isNotEmpty &&
                    counts[dong.username.toLowerCase()]! > 1
                ? dong.withError('Tên đăng nhập bị trùng trong file.')
                : dong,
          )
          .toList(),
    );
  }
}
