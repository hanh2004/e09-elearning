import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:xml/xml.dart';

import '../models/user_import.dart';

class UserExcelImport {
  static const maxFileBytes = 2 * 1024 * 1024;
  static const templateAsset = 'lib/assets/templates/users_template.xlsx';
  static const headers = ['Họ và tên', 'Tên đăng nhập', 'Mật khẩu'];

  UserImportPreview parse(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxFileBytes) {
      return const UserImportPreview(
        errors: ['File phải có dữ liệu và không vượt quá 2 MB.'],
      );
    }
    try {
      final book = decode(bytes);
      final sheet =
          book.tables['Users'] ??
          (book.tables.length == 1 ? book.tables.values.first : null);
      if (sheet == null) {
        return const UserImportPreview(
          errors: ['Không tìm thấy sheet Users. Hãy dùng file mẫu.'],
        );
      }
      return parseRows(
        sheet.rows
            .map((row) => row.map((cell) => cell?.value).toList())
            .toList(),
      );
    } catch (_) {
      return const UserImportPreview(
        errors: ['Không đọc được file Excel. Chỉ nhận .xlsx không mã hóa.'],
      );
    }
  }

  /// excel 4.x expects unprefixed SpreadsheetML element names. Some valid
  /// producers use x:workbook/x:styleSheet instead. Normalize only element
  /// prefixes and absolute /xl/ relationship paths in memory. Cell contents
  /// and formulas are preserved.
  /// The source file is never modified.
  Excel decode(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxFileBytes) {
      throw const FormatException('File size limit');
    }
    final archive = ZipDecoder().decodeBytes(bytes);
    if (archive.length > 100 ||
        archive.files.fold<int>(0, (size, file) => size + file.size) >
            20 * 1024 * 1024) {
      throw const FormatException('Expanded workbook size limit');
    }
    final normalized = Archive();
    final namespace = RegExp(
      r'''xmlns:([A-Za-z_][\w.-]*)\s*=\s*["']http://schemas.openxmlformats.org/spreadsheetml/2006/main["']''',
    );
    for (final file in archive.files) {
      if (!file.isFile) continue;
      var data = file.content as List<int>;
      if (file.name.startsWith('xl/') && file.name.endsWith('.xml')) {
        var xml = utf8.decode(data);
        final prefixes = namespace
            .allMatches(xml)
            .map((match) => match.group(1)!)
            .toSet();
        for (final prefix in prefixes) {
          xml = xml.replaceAll('<$prefix:', '<').replaceAll('</$prefix:', '</');
        }
        if (file.name.startsWith('xl/worksheets/')) {
          final document = XmlDocument.parse(xml);
          for (final cell in document.findAllElements('c')) {
            if (cell.findElements('f').isNotEmpty) {
              // Always keep formula cells typed as formulas, including ones
              // with cached string results, so validation rejects them.
              cell.setAttribute('t', 'n');
            } else if (cell.getAttribute('t') == 'str') {
              final value = cell.findElements('v').firstOrNull?.innerText ?? '';
              cell.setAttribute('t', 'inlineStr');
              cell.children.clear();
              cell.children.add(
                XmlElement(XmlName('is'), [], [
                  XmlElement(XmlName('t'), [], [XmlText(value)]),
                ]),
              );
            }
          }
          xml = document.toXmlString();
        }
        data = utf8.encode(xml);
      }
      if (file.name == 'xl/_rels/workbook.xml.rels') {
        final xml = utf8
            .decode(data)
            .replaceAllMapped(
              RegExp(r'''Target=(["'])/xl/'''),
              (match) => 'Target=${match.group(1)}',
            );
        data = utf8.encode(xml);
      }
      normalized.addFile(ArchiveFile(file.name, data.length, data));
    }
    return Excel.decodeBytes(ZipEncoder().encode(normalized)!);
  }

  // Kept separate from file IO so validation can be tested without Firebase.
  UserImportPreview parseRows(List<List<CellValue?>> source) {
    if (source.isEmpty) {
      return const UserImportPreview(errors: ['File Excel trống.']);
    }
    String text(CellValue? value) =>
        value is TextCellValue ? value.value.toString() : '';
    bool blank(CellValue? value) =>
        value == null || value is TextCellValue && text(value).trim().isEmpty;
    final header = source.first;
    const aliases = [
      {'họ và tên', 'name'},
      {'tên đăng nhập', 'username'},
      {'mật khẩu', 'password'},
    ];
    if (header.length < 3 ||
        List.generate(3, (i) => i).any(
          (i) => !aliases[i].contains(text(header[i]).trim().toLowerCase()),
        ) ||
        header.skip(3).any((cell) => !blank(cell))) {
      return const UserImportPreview(
        errors: [
          'Dòng 1 phải có đúng 3 cột: Họ và tên, Tên đăng nhập, Mật khẩu. Không thêm cột vai trò.',
        ],
      );
    }
    final rows = <UserImportRow>[];
    for (var i = 1; i < source.length; i++) {
      final cells = source[i];
      if (cells.every(blank)) continue;
      if (rows.length >= UserImportPreview.maxUsers) {
        return const UserImportPreview(
          errors: ['Mỗi lần chỉ nhập tối đa 200 User. Hãy chia nhỏ file.'],
        );
      }
      final errors = <String>[];
      final values = <String>[];
      for (var col = 0; col < 3; col++) {
        final value = col < cells.length ? cells[col] : null;
        if (blank(value)) {
          errors.add('Thiếu ${headers[col].toLowerCase()}.');
        } else if (value is! TextCellValue) {
          errors.add(
            '${headers[col]} phải là Text, không dùng số, ngày hoặc công thức.',
          );
        }
        values.add(text(value).trim());
      }
      if (cells.skip(3).any((cell) => !blank(cell))) {
        errors.add('Có dữ liệu ngoài 3 cột cho phép.');
      }
      if (values[0].length > 100) errors.add('Họ và tên tối đa 100 ký tự.');
      if (values[1].isNotEmpty &&
          !RegExp(r'^[A-Za-z0-9_.@-]{3,64}$').hasMatch(values[1])) {
        errors.add(
          'Tên đăng nhập dài 3–64 ký tự: chữ không dấu, số, _, ., @, -.',
        );
      }
      if (values[2].isNotEmpty &&
          (values[2].length < 6 || values[2].length > 128)) {
        errors.add('Mật khẩu dài 6–128 ký tự.');
      }
      rows.add(
        UserImportRow(
          rowNumber: i + 1,
          name: values[0],
          username: values[1],
          password: values[2],
          errors: errors,
        ),
      );
    }
    if (rows.isEmpty) {
      return const UserImportPreview(
        errors: ['Chưa có User. Điền dữ liệu từ dòng 2 trong sheet Users.'],
      );
    }
    final counts = <String, int>{};
    for (final row in rows) {
      final key = row.username.toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return UserImportPreview(
      rows: rows
          .map(
            (row) =>
                row.username.isNotEmpty &&
                    counts[row.username.toLowerCase()]! > 1
                ? row.withError('Tên đăng nhập bị trùng trong file.')
                : row,
          )
          .toList(),
    );
  }
}
