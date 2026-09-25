part of "admin_report_screen.dart";

extension _AdminReportExport on _TrangThaiBaoCaoQuanTri {
  Future<void> _moHopThoaiXuat(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cacBaiThi,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cacLuotThi,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cacNguoiDung,
  ) async {
    final cacDonVi =
        cacNguoiDung
            .map(
              (banGhi) => banGhi.data()['role'] == 'super_admin'
                  ? 'E09'
                  : '${banGhi.data()['unit'] ?? ''}',
            )
            .where((giaTri) => giaTri.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final sortedExams = cacBaiThi.toList()
      ..sort(
        (a, b) => '${a.data()['title']}'.compareTo('${b.data()['title']}'),
      );
    final cauHinh = await showDialog<_CauHinhXuatBaoCao>(
      context: context,
      builder: (context) => _HopThoaiXuatBaoCao(
        units: cacDonVi,
        exams: sortedExams
            .map(
              (banGhi) => _BaiThiXuatBaoCao(
                id: banGhi.id,
                title: '${banGhi.data()['title'] ?? banGhi.id}',
              ),
            )
            .toList(),
        initialUnit: unitFilter,
        initialExam: examFilter,
      ),
    );
    if (cauHinh == null || !mounted) return;

    final selectedSubUnit = cauHinh.unit == unitFilter ? subUnitFilter : null;
    final userMap = {
      for (final banGhi in cacNguoiDung)
        if (AdminReport.matchesUser(
          banGhi.id,
          banGhi.data(),
          unit: cauHinh.unit,
          subUnit: selectedSubUnit,
          search: searchController.text,
        ))
          banGhi.id: banGhi.data(),
    };
    final examMap = {for (final banGhi in cacBaiThi) banGhi.id: banGhi.data()};
    final batDau = DateTime(
      cauHinh.from.year,
      cauHinh.from.month,
      cauHinh.from.day,
    );
    final ketThuc = DateTime(
      cauHinh.to.year,
      cauHinh.to.month,
      cauHinh.to.day + 1,
    );
    final tenTep = _tenTepExcel(cauHinh.fileName);
    final exporter = AdminReportExcelExport();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
    try {
      final filteredAttempts = await AdminReportAttempts.trongKhoang(
        summaries: cacLuotThi,
        userIds: userMap.keys.toSet(),
        examId: cauHinh.examId,
        from: batDau,
        until: ketThuc,
        db: _dichVuFirestore.db,
      );
      final baoCao = AdminReport.build(
        users: userMap,
        exams: examMap,
        attempts: filteredAttempts,
        examId: cauHinh.examId,
        unit: cauHinh.unit,
        subUnit: selectedSubUnit,
        search: searchController.text,
      );
      final canTienDoKhoaHoc = cauHinh.sections.any(
        (muc) =>
            muc == AdminReportExcelExport.progress ||
            muc == AdminReportExcelExport.units ||
            muc == AdminReportExcelExport.incomplete,
      );
      final tienDoKhoaHoc = canTienDoKhoaHoc
          ? await _taiTienDoKhoaHoc(
              users: userMap,
              examId: cauHinh.examId,
              endsAt: ketThuc,
            )
          : const <CourseProgressExcelRow>[];
      await exporter.export(
        report: baoCao,
        users: userMap,
        from: cauHinh.from,
        to: cauHinh.to,
        fileName: tenTep,
        sections: cauHinh.sections,
        courseProgress: tienDoKhoaHoc,
        unit: cauHinh.unit,
        examTitle: cauHinh.examTitle,
      );
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Đã xuất $tenTep')));
      }
    } catch (loi) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không xuất được Excel: $loi')));
      }
    }
  }

  Future<List<CourseProgressExcelRow>> _taiTienDoKhoaHoc({
    required Map<String, Map<String, dynamic>> users,
    required String? examId,
    required DateTime endsAt,
  }) async {
    final cacKhoaHoc = await _dichVuFirestore.db
        .collection('courses')
        .where('published', isEqualTo: true)
        .get();
    final cacBaiHocTheoKhoa = <String, QuerySnapshot<Map<String, dynamic>>>{};
    for (var batDau = 0; batDau < cacKhoaHoc.docs.length; batDau += 10) {
      await Future.wait(
        cacKhoaHoc.docs.skip(batDau).take(10).map((khoa) async {
          cacBaiHocTheoKhoa[khoa.id] = await khoa.reference
              .collection('lessons')
              .get();
        }),
      );
    }

    final khoaHocTrongPhamVi = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final khoa in cacKhoaHoc.docs) {
      final duLieuKhoa = khoa.data();
      final ngayBatDau = LearningPolicy.readDateTime(duLieuKhoa['startsAt']);
      if (ngayBatDau != null && !ngayBatDau.isBefore(endsAt)) continue;
      final cacBaiHoc = cacBaiHocTheoKhoa[khoa.id]?.docs ?? const [];
      final dungBaiThi =
          examId == null ||
          duLieuKhoa['examId'] == examId ||
          cacBaiHoc.any((bai) => bai.data()['examId'] == examId);
      if (dungBaiThi) khoaHocTrongPhamVi.add(khoa);
    }
    if (khoaHocTrongPhamVi.isEmpty || users.isEmpty) return const [];

    final tienDoTheoHocVien = <String, List<Map<String, dynamic>>>{};
    final hocVien = users.entries.where((cap) => cap.value['role'] == 'user');
    final danhSachHocVien = hocVien.toList();
    for (var batDau = 0; batDau < danhSachHocVien.length; batDau += 10) {
      await Future.wait(
        danhSachHocVien.skip(batDau).take(10).map((capDuLieu) async {
          final cacTienDo = await _dichVuFirestore.db
              .collection('users')
              .doc(capDuLieu.key)
              .collection('learning')
              .get();
          tienDoTheoHocVien[capDuLieu.key] = cacTienDo.docs
              .map((banGhi) => banGhi.data())
              .toList();
        }),
      );
    }

    final ketQua = <CourseProgressExcelRow>[];
    for (final khoa in khoaHocTrongPhamVi) {
      final baiHoc = cacBaiHocTheoKhoa[khoa.id]?.docs ?? const [];
      final maBaiHoc = baiHoc.map((banGhi) => banGhi.id).toSet();
      if (maBaiHoc.isEmpty) continue;
      final khoaHocData = khoa.data();
      final doiTuong = (khoaHocData['audience'] ?? 'all').toString();
      final hocVienTrongKhoa = {
        for (final capDuLieu in danhSachHocVien)
          if (doiTuong == 'all' ||
              (doiTuong.startsWith('class:') &&
                  capDuLieu.value['classId'] == doiTuong.substring(6)))
            capDuLieu.key: capDuLieu.value,
      };
      if (hocVienTrongKhoa.isEmpty) continue;
      final baoCaoTienDo = CourseCompletionReport.build(
        users: hocVienTrongKhoa,
        lessonIds: maBaiHoc,
        progress: tienDoTheoHocVien,
        courseId: khoa.id,
        endsAt: endsAt,
        course: khoaHocData,
        lessons: {for (final bai in baiHoc) bai.id: bai.data()},
      );
      ketQua.addAll(
        baoCaoTienDo.rows.map(
          (dong) => CourseProgressExcelRow(
            courseTitle: '${khoaHocData['title'] ?? khoa.id}',
            row: dong,
          ),
        ),
      );
    }
    return ketQua;
  }

  String _tenTepExcel(String giaTri) {
    final cleaned = giaTri.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final ten = cleaned.isEmpty ? 'Bao_cao_tong_hop_E09' : cleaned;
    return ten.toLowerCase().endsWith('.xlsx') ? ten : '$ten.xlsx';
  }
}

class _BaiThiXuatBaoCao {
  const _BaiThiXuatBaoCao({required this.id, required this.title});

  final String id;
  final String title;
}

class _CauHinhXuatBaoCao {
  const _CauHinhXuatBaoCao({
    required this.from,
    required this.to,
    required this.unit,
    required this.examId,
    required this.examTitle,
    required this.sections,
    required this.fileName,
  });

  final DateTime from;
  final DateTime to;
  final String? unit;
  final String? examId;
  final String? examTitle;
  final Set<String> sections;
  final String fileName;
}

class _HopThoaiXuatBaoCao extends StatefulWidget {
  const _HopThoaiXuatBaoCao({
    required this.units,
    required this.exams,
    this.initialUnit,
    this.initialExam,
  });

  final List<String> units;
  final List<_BaiThiXuatBaoCao> exams;
  final String? initialUnit;
  final String? initialExam;

  @override
  State<_HopThoaiXuatBaoCao> createState() => _TrangThaiHopThoaiXuatBaoCao();
}

class _TrangThaiHopThoaiXuatBaoCao extends State<_HopThoaiXuatBaoCao> {
  late DateTime from;
  late DateTime to;
  late String? unit;
  late String? examId;
  late final TextEditingController fileNameController;
  String? error;
  final selected = <String>{
    AdminReportExcelExport.overview,
    AdminReportExcelExport.progress,
    AdminReportExcelExport.results,
    AdminReportExcelExport.units,
    AdminReportExcelExport.incomplete,
  };

  @override
  void initState() {
    super.initState();
    final hienTai = DateTime.now();
    from = DateTime(hienTai.year, hienTai.month, 1);
    to = DateTime(hienTai.year, hienTai.month, hienTai.day);
    unit = widget.units.contains(widget.initialUnit)
        ? widget.initialUnit
        : null;
    examId = widget.exams.any((baiThi) => baiThi.id == widget.initialExam)
        ? widget.initialExam
        : null;
    fileNameController = TextEditingController(
      text:
          'Bao_cao_tong_hop_E09_${_ngayHienThi(to).replaceAll('/', '-')}.xlsx',
    );
  }

  @override
  void dispose() {
    fileNameController.dispose();
    super.dispose();
  }

  String _ngayHienThi(DateTime giaTri) =>
      '${giaTri.day.toString().padLeft(2, '0')}/${giaTri.month.toString().padLeft(2, '0')}/${giaTri.year}';

  Future<void> _chonNgay(bool isFrom) async {
    final giaTri = await showDatePicker(
      context: context,
      initialDate: isFrom ? from : to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: isFrom ? 'Chọn ngày bắt đầu' : 'Chọn ngày kết thúc',
    );
    if (giaTri == null) return;
    setState(() {
      if (isFrom) {
        from = giaTri;
      } else {
        to = giaTri;
      }
      error = null;
    });
  }

  void _gui() {
    if (from.isAfter(to)) {
      setState(() => error = 'Từ ngày không được sau Đến ngày.');
      return;
    }
    if (selected.isEmpty) {
      setState(() => error = 'Chọn ít nhất một nội dung để xuất.');
      return;
    }
    final selectedExam = widget.exams.where((baiThi) => baiThi.id == examId);
    Navigator.of(context).pop(
      _CauHinhXuatBaoCao(
        from: from,
        to: to,
        unit: unit,
        examId: examId,
        examTitle: selectedExam.isEmpty ? null : selectedExam.first.title,
        sections: Set.unmodifiable(selected),
        fileName: fileNameController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Xuất báo cáo Excel',
                      style: TextStyle(
                        color: AppTheme.navy,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                'Chọn phạm vi và nội dung cần xuất',
                style: TextStyle(color: Color(0xFF60779A), fontSize: 15),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final chieuRong = (constraints.maxWidth - 14) / 2;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _oChonNgay(
                        'Từ ngày',
                        from,
                        () => _chonNgay(true),
                        chieuRong,
                      ),
                      _oChonNgay(
                        'Đến ngày',
                        to,
                        () => _chonNgay(false),
                        chieuRong,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final chieuRong = (constraints.maxWidth - 14) / 2;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: chieuRong,
                        child: DropdownButtonFormField<String>(
                          initialValue: unit ?? '',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Đơn vị',
                            prefixIcon: Icon(Icons.apartment),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Tất cả đơn vị'),
                            ),
                            for (final giaTri in widget.units)
                              DropdownMenuItem(
                                value: giaTri,
                                child: Text(giaTri),
                              ),
                          ],
                          onChanged: (giaTri) => setState(
                            () => unit = giaTri == null || giaTri.isEmpty
                                ? null
                                : giaTri,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: chieuRong,
                        child: DropdownButtonFormField<String>(
                          initialValue: examId ?? '',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Khóa học / Bài thi',
                            prefixIcon: Icon(Icons.assignment_outlined),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Tất cả'),
                            ),
                            for (final baiThi in widget.exams)
                              DropdownMenuItem(
                                value: baiThi.id,
                                child: Text(
                                  baiThi.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (giaTri) => setState(
                            () => examId = giaTri == null || giaTri.isEmpty
                                ? null
                                : giaTri,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Nội dung xuất',
                style: TextStyle(
                  color: AppTheme.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              for (final luaChon in const [
                (AdminReportExcelExport.overview, 'Tổng quan'),
                (AdminReportExcelExport.progress, 'Tiến độ học tập'),
                (AdminReportExcelExport.results, 'Kết quả kiểm tra'),
                (AdminReportExcelExport.units, 'Tổng hợp đơn vị'),
                (AdminReportExcelExport.incomplete, 'Học viên chưa hoàn thành'),
              ])
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: selected.contains(luaChon.$1),
                  activeColor: _TrangThaiBaoCaoQuanTri._mauChuDao,
                  title: Text(luaChon.$2),
                  onChanged: (giaTri) => setState(() {
                    if (giaTri == true) {
                      selected.add(luaChon.$1);
                    } else {
                      selected.remove(luaChon.$1);
                    }
                  }),
                ),
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 16),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F5FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Color(0xFF60779A),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dữ liệu xuất theo bộ lọc đang chọn.',
                        style: TextStyle(color: Color(0xFF60779A)),
                      ),
                    ),
                  ],
                ),
              ),
              TextField(
                controller: fileNameController,
                decoration: const InputDecoration(
                  labelText: 'Tên tệp tin',
                  prefixIcon: Icon(Icons.insert_drive_file_outlined),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _gui,
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text('Xuất Excel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _oChonNgay(
    String nhan,
    DateTime giaTri,
    VoidCallback onTap,
    double chieuRong,
  ) => SizedBox(
    width: chieuRong,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: nhan,
          prefixIcon: const Icon(Icons.calendar_month_outlined),
        ),
        child: Text(_ngayHienThi(giaTri)),
      ),
    ),
  );
}
