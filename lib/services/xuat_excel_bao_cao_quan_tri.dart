// XỬ LÝ DỮ LIỆU / API: Tạo file Excel báo cáo tổng hợp cho Web Admin.

import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/bao_cao_quan_tri.dart';
import '../models/bao_cao_hoan_thanh_khoa_hoc.dart';
import 'tep/tai_excel_bao_cao.dart';

class CourseProgressExcelRow {
  const CourseProgressExcelRow({required this.courseTitle, required this.row});

  final String courseTitle;
  final CourseCompletionRow row;
}

class AdminReportExcelExport {
  static const overview = 'overview';
  static const progress = 'progress';
  static const results = 'results';
  static const units = 'units';
  static const incomplete = 'incomplete';

  Future<void> export({
    required AdminReport report,
    required Map<String, Map<String, dynamic>> users,
    required DateTime from,
    required DateTime to,
    required String fileName,
    required Set<String> sections,
    required List<CourseProgressExcelRow> courseProgress,
    String? unit,
    String? examTitle,
  }) async {
    final soExcel = Excel.createExcel();
    if (sections.contains(overview)) {
      _themTongQuan(soExcel['Tổng quan'], report, from, to, unit, examTitle);
    }
    if (sections.contains(progress)) {
      _themTienDo(soExcel['Tiến độ khóa học'], courseProgress, to);
    }
    if (sections.contains(results)) {
      _themKetQua(soExcel['Kết quả kiểm tra'], report);
    }
    if (sections.contains(units)) {
      _themDonVi(soExcel['Tổng hợp đơn vị'], courseProgress);
    }
    if (sections.contains(incomplete)) {
      _themChuaHoanThanh(soExcel['Học viên chưa hoàn thành'], courseProgress);
    }

    // Excel tạo sẵn một sheet mẫu; xóa để file chỉ còn mục đã chọn.
    if (soExcel.tables.containsKey('Sheet1')) soExcel.delete('Sheet1');

    final duLieuByte = soExcel.encode();
    if (duLieuByte == null || duLieuByte.isEmpty) {
      throw StateError('Không tạo được dữ liệu Excel.');
    }
    await downloadReportExcel(Uint8List.fromList(duLieuByte), fileName);
  }

  void _themTongQuan(
    Sheet trangTinh,
    AdminReport baoCao,
    DateTime tuNgay,
    DateTime denNgay,
    String? donVi,
    String? examTitle,
  ) {
    _ghiDong(trangTinh, [
      ['BÁO CÁO TỔNG HỢP', null],
      ['Từ ngày', _ngayHienThi(tuNgay)],
      ['Đến ngày', _ngayHienThi(denNgay)],
      ['Đơn vị', donVi ?? 'Tất cả đơn vị'],
      ['Khóa học / Bài thi', examTitle ?? 'Tất cả'],
      [null, null],
      ['Chỉ số', 'Giá trị'],
      ['Bài thi', baoCao.examCount],
      ['Học viên đã thi', baoCao.participants],
      ['Lượt đã nộp', baoCao.attempts],
      ['Điểm TB tốt nhất', baoCao.average?.toStringAsFixed(2) ?? '—'],
      [
        'Tỷ lệ đạt',
        baoCao.passRate == null
            ? '—'
            : '${baoCao.passRate!.toStringAsFixed(1)}%',
      ],
      ['Kết quả chưa đạt', baoCao.failed],
      ['Học viên trong phạm vi lọc', baoCao.studentCount],
    ]);
  }

  void _themTienDo(
    Sheet trangTinh,
    List<CourseProgressExcelRow> tienDoKhoaHoc,
    DateTime denNgay,
  ) {
    _ghiDong(trangTinh, [
      ['Tiến độ được tính đến', _ngayHienThi(denNgay)],
      [
        'Đơn vị',
        'Khóa học',
        'Học viên',
        'Bài đã hoàn thành',
        'Tổng bài học',
        'Trạng thái',
      ],
      for (final tienDo in tienDoKhoaHoc)
        [
          tienDo.row.unit,
          tienDo.courseTitle,
          tienDo.row.name,
          tienDo.row.completed,
          tienDo.row.total,
          tienDo.row.status,
        ],
    ]);
  }

  void _themKetQua(Sheet trangTinh, AdminReport baoCao) {
    _ghiDong(trangTinh, [
      [
        'Học viên',
        'Đơn vị',
        'Bài thi',
        'Lượt nộp',
        'Điểm tốt nhất',
        'Kết quả',
        'Nộp gần nhất',
      ],
      for (final dong in baoCao.rows)
        [
          dong.name,
          _tenDonVi(dong.subUnit, dong.unit),
          dong.examTitle,
          dong.attempts,
          dong.score?.toStringAsFixed(2) ?? '—',
          dong.passed == null
              ? 'Thiếu điểm'
              : dong.passed!
              ? 'Đạt'
              : 'Chưa đạt',
          _ngayGio(dong.submittedAt),
        ],
    ]);
  }

  void _themDonVi(Sheet trangTinh, List<CourseProgressExcelRow> tienDoKhoaHoc) {
    _ghiDong(trangTinh, [
      [
        'Đơn vị',
        'Khóa học',
        'Tổng học viên',
        'Đã hoàn thành khóa',
        'Chưa hoàn thành',
        'Tỷ lệ hoàn thành',
      ],
      for (final capDuLieu in _tongHopTienDo(tienDoKhoaHoc)) capDuLieu,
    ]);
  }

  List<List<Object?>> _tongHopTienDo(
    List<CourseProgressExcelRow> tienDoKhoaHoc,
  ) {
    final nhom = <String, List<CourseProgressExcelRow>>{};
    for (final tienDo in tienDoKhoaHoc) {
      final khoa = '${tienDo.row.unit}\u0000${tienDo.courseTitle}';
      nhom.putIfAbsent(khoa, () => []).add(tienDo);
    }
    return [
      for (final capDuLieu in nhom.entries)
        () {
          final cacHang = capDuLieu.value;
          final daHoanThanh = cacHang.where((d) => d.row.done).length;
          final tong = cacHang.length;
          return <Object?>[
            cacHang.first.row.unit,
            cacHang.first.courseTitle,
            tong,
            daHoanThanh,
            tong - daHoanThanh,
            tong == 0 ? '0%' : '${(daHoanThanh * 100 / tong).round()}%',
          ];
        }(),
    ];
  }

  void _themChuaHoanThanh(
    Sheet trangTinh,
    List<CourseProgressExcelRow> tienDoKhoaHoc,
  ) {
    _ghiDong(trangTinh, [
      [
        'Học viên',
        'Đơn vị',
        'Khóa học',
        'Bài đã hoàn thành',
        'Tổng bài học',
        'Trạng thái',
      ],
      for (final tienDo in tienDoKhoaHoc)
        if (!tienDo.row.done)
          [
            tienDo.row.name,
            tienDo.row.unit,
            tienDo.courseTitle,
            tienDo.row.completed,
            tienDo.row.total,
            tienDo.row.status,
          ],
    ]);
  }

  void _ghiDong(Sheet trangTinh, List<List<Object?>> cacDong) {
    for (final dong in cacDong) {
      trangTinh.appendRow(dong.map(_giaTriO).toList());
    }
  }

  CellValue _giaTriO(Object? giaTri) {
    if (giaTri is int) return IntCellValue(giaTri);
    if (giaTri is num) return DoubleCellValue(giaTri.toDouble());
    return TextCellValue('${giaTri ?? ''}');
  }

  String _tenDonVi(String trucThuoc, String donVi) =>
      trucThuoc.isEmpty ? donVi : '$trucThuoc-$donVi';

  String _ngayHienThi(DateTime giaTri) =>
      '${giaTri.day.toString().padLeft(2, '0')}/${giaTri.month.toString().padLeft(2, '0')}/${giaTri.year}';

  String _ngayGio(DateTime? giaTri) => giaTri == null
      ? 'Chưa có thời gian'
      : '${_ngayHienThi(giaTri)} ${giaTri.hour.toString().padLeft(2, '0')}:${giaTri.minute.toString().padLeft(2, '0')}';
}
