// XỬ LÝ DỮ LIỆU / API: Đọc file Excel nhập học viên, kiểm tra từng dòng và tạo bản xem trước.
// Các màn hình gọi mã ở đây; quyền truy cập cuối cùng do Firebase/API kiểm tra.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:xml/xml.dart';

import '../../models/dinh_danh_tai_khoan.dart';
import '../../models/du_lieu_nhap_hoc_vien.dart';

class UserExcelImport {
  static const maxFileBytes = 2 * 1024 * 1024;
  static const templateAsset = 'lib/assets/templates/users_template.xlsx';
  static const headers = ['Họ và tên', 'Tên đăng nhập', 'Mật khẩu'];
  static const _headerAliases = [
    {'họ và tên', 'name'},
    {'tên đăng nhập', 'username'},
    {'mật khẩu', 'password'},
  ];
  static const _serialAliases = {'stt', 'số thứ tự'};

  String _normalizeHeader(String value) => value
      .replaceAll('\uFEFF', '')
      .replaceAll('\u00A0', ' ')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');

  bool _blank(CellValue? value) =>
      value == null ||
      value is TextCellValue && value.value.toString().trim().isEmpty;

  bool _hasSupportedHeaders(List<List<CellValue?>> rows) {
    if (rows.isEmpty) return false;
    final firstRow = rows.first;
    final offset = _hasSerialColumn(firstRow) ? 1 : 0;
    String headerAt(int index) {
      final cell = index < firstRow.length ? firstRow[index] : null;
      return cell is TextCellValue
          ? _normalizeHeader(cell.value.toString())
          : '';
    }

    return firstRow.length >= offset + headers.length &&
        List.generate(3, (index) => index).every(
          (index) => _headerAliases[index].contains(headerAt(index + offset)),
        ) &&
        firstRow.skip(offset + headers.length).every(_blank);
  }

  bool _hasSerialColumn(List<CellValue?> header) =>
      header.isNotEmpty &&
      header.first is TextCellValue &&
      _serialAliases.contains(
        _normalizeHeader((header.first as TextCellValue).value.toString()),
      );

  Sheet? _findUserSheet(Excel workbook) {
    final sheets = workbook.tables.entries.toList();
    for (final entry in sheets) {
      if (_normalizeHeader(entry.key) == 'users') return entry.value;
    }
    final matchingSheets = sheets.where((entry) {
      final rows = entry.value.rows
          .map((row) => row.map((cell) => cell?.value).toList())
          .toList();
      return _hasSupportedHeaders(rows);
    }).toList();
    if (matchingSheets.length == 1) return matchingSheets.single.value;
    if (sheets.length == 1) return sheets.single.value;
    return null;
  }

  UserImportPreview parse(Uint8List duLieuByte) {
    if (duLieuByte.isEmpty || duLieuByte.length > maxFileBytes) {
      return const UserImportPreview(
        errors: ['File phải có dữ liệu và không vượt quá 2 MB.'],
      );
    }
    try {
      final soExcel = decode(duLieuByte);
      final trangTinh = _findUserSheet(soExcel);
      if (trangTinh == null) {
        return const UserImportPreview(
          errors: [
            'Không tìm thấy sheet Users hoặc tiêu đề đúng mẫu. Hãy tải mẫu Excel và nhập trong sheet Users.',
          ],
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
    bool blank(CellValue? giaTri) => _blank(giaTri);
    final dauTrang = source.first;
    if (!_hasSupportedHeaders(source)) {
      return const UserImportPreview(
        errors: [
          'Dòng 1 cần đúng mẫu: Họ và tên, Tên đăng nhập, Mật khẩu. Không thêm cột khác; cột STT ở đầu được bỏ qua.',
        ],
      );
    }
    final offset = _hasSerialColumn(dauTrang) ? 1 : 0;
    final cacDong = <UserImportRow>[];
    final seenUsernames = <String>{};
    var lastSerialNumber = 0;
    for (var i = 1; i < source.length; i++) {
      final cells = source[i];
      if (cells.skip(offset).every(blank)) continue;
      final rowNumber = i + 1;
      final serialCell = offset == 1 && cells.isNotEmpty ? cells.first : null;
      var serialNumber = offset == 0
          ? cacDong.length + 1
          : lastSerialNumber + 1;
      var serialNumberAvailable = true;
      String? serialError;
      if (serialCell != null && !blank(serialCell)) {
        if (serialCell is IntCellValue && serialCell.value > 0) {
          serialNumber = serialCell.value;
        } else if (serialCell is DoubleCellValue &&
            serialCell.value.isFinite &&
            serialCell.value > 0 &&
            serialCell.value == serialCell.value.truncateToDouble()) {
          serialNumber = serialCell.value.toInt();
        } else if (serialCell is TextCellValue &&
            RegExp(r'^\d+$').hasMatch(serialCell.value.toString().trim()) &&
            (int.tryParse(serialCell.value.toString().trim()) ?? 0) > 0) {
          serialNumber = int.parse(serialCell.value.toString().trim());
        } else if (serialCell is FormulaCellValue &&
            serialCell.formula
                    .replaceAll(RegExp(r'\s+'), '')
                    .replaceFirst(RegExp(r'^='), '')
                    .toUpperCase() ==
                'ROW()-1') {
          serialNumber = i;
        } else {
          serialNumberAvailable = false;
          serialError =
              'STT phải là số nguyên dương hoặc công thức STT tự động của mẫu.';
        }
      }
      if (serialError == null && serialNumber <= lastSerialNumber) {
        serialError = 'STT phải tăng dần.';
      }
      if (cacDong.length >= UserImportPreview.maxUsers) {
        return UserImportPreview(
          rows: cacDong,
          errors: ['STT $serialNumber: Mỗi lần chỉ nhập tối đa 200 học viên.'],
        );
      }
      final errors = <String>[];
      if (serialError != null) errors.add(serialError);
      final cacGiaTri = <String>[];
      for (var col = 0; col < 3; col++) {
        final valueIndex = col + offset;
        final giaTri = valueIndex < cells.length ? cells[valueIndex] : null;
        if (blank(giaTri)) {
          errors.add('Thiếu ${headers[col].toLowerCase()}.');
        } else if (giaTri is! TextCellValue) {
          errors.add(
            '${headers[col]} phải là Text, không dùng số, ngày hoặc công thức.',
          );
        }
        cacGiaTri.add(text(giaTri).trim());
      }
      const allowedColumnCount = 3;
      final totalAllowedColumnCount = offset + allowedColumnCount;
      if (cells
          .skip(totalAllowedColumnCount)
          .any((oDuLieu) => !blank(oDuLieu))) {
        errors.add('Có dữ liệu ngoài $totalAllowedColumnCount cột cho phép.');
      }
      if (cacGiaTri[0].length > 100) errors.add('Họ và tên tối đa 100 ký tự.');
      if (cacGiaTri[1].isNotEmpty &&
          !AccountIdentity.isValidUsername(cacGiaTri[1])) {
        errors.add(
          'Tên đăng nhập dài 3–64 ký tự: chữ không dấu, số, _, ., @, -.',
        );
      }
      if (cacGiaTri[2].isNotEmpty &&
          (cacGiaTri[2].length < 6 || cacGiaTri[2].length > 128)) {
        errors.add('Mật khẩu dài 6–128 ký tự.');
      }
      if (cacGiaTri[1].isNotEmpty &&
          AccountIdentity.isValidUsername(cacGiaTri[1]) &&
          !seenUsernames.add(cacGiaTri[1].toLowerCase())) {
        errors.add('Tên đăng nhập bị trùng trong file.');
      }
      cacDong.add(
        UserImportRow(
          rowNumber: rowNumber,
          serialNumber: serialNumberAvailable ? serialNumber : null,
          name: cacGiaTri[0],
          username: cacGiaTri[1],
          password: cacGiaTri[2],
          errors: errors,
        ),
      );
      if (serialError == null) lastSerialNumber = serialNumber;
      if (errors.isNotEmpty) break;
    }
    if (cacDong.isEmpty) {
      return const UserImportPreview(
        errors: ['Chưa có học viên. Điền dữ liệu từ dòng 2 trong sheet Users.'],
      );
    }
    return UserImportPreview(rows: cacDong);
  }
}
