part of "admin_report_screen.dart";

extension _AdminReportTable on _TrangThaiBaoCaoQuanTri {
  Widget _dungBaoCao(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cacBaiThi,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cacLuotThi,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cacNguoiDung,
  ) {
    final userMap = {
      for (final banGhi in cacNguoiDung) banGhi.id: banGhi.data(),
    };
    final examMap = {for (final banGhi in cacBaiThi) banGhi.id: banGhi.data()};
    final selectedExam = examMap.containsKey(examFilter) ? examFilter : null;
    final cacDonVi =
        cacNguoiDung
            .map(
              (u) => u.data()['role'] == 'super_admin'
                  ? 'E09'
                  : (u.data()['unit'] ?? '').toString(),
            )
            .toSet()
            .toList()
          ..sort();
    final selectedUnit = cacDonVi.contains(unitFilter) ? unitFilter : null;
    final subUnits =
        cacNguoiDung
            .where(
              (nguoiDung) =>
                  nguoiDung.data()['role'] == 'user' &&
                  (nguoiDung.data()['unit'] ?? '').toString() == selectedUnit,
            )
            .map(
              (nguoiDung) =>
                  (nguoiDung.data()['subUnit'] ?? '').toString().trim(),
            )
            .where((giaTri) => giaTri.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final selectedSubUnit = subUnits.contains(subUnitFilter)
        ? subUnitFilter
        : null;
    final baoCao = AdminReport.build(
      users: userMap,
      exams: examMap,
      attempts: _luotThiBaoCao(cacLuotThi),
      examId: selectedExam,
      unit: selectedUnit,
      subUnit: selectedSubUnit,
      search: searchController.text,
    );
    final rank = baoCao.ranking;
    final distribution = baoCao.distribution;
    final scored = distribution.fold(0, (tongSo, v) => tongSo + v);
    final sortedExams = cacBaiThi.toList()
      ..sort(
        (a, b) => '${a.data()['title']}'.compareTo('${b.data()['title']}'),
      );
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        AdminPageHeading(
          title: 'Tổng quan kết quả học tập',
          subtitle: 'Theo dõi kết quả theo đơn vị, học viên và bài thi.',
          action: FilledButton.icon(
            onPressed: () =>
                _moHopThoaiXuat(cacBaiThi, cacLuotThi, cacNguoiDung),
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('Xuất Excel'),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chieuRong = constraints.maxWidth >= 700
                    ? (constraints.maxWidth - 24) / 3
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: chieuRong,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('unit:$selectedUnit'),
                        initialValue: selectedUnit,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Đơn vị',
                          prefixIcon: Icon(Icons.apartment),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tất cả đơn vị'),
                          ),
                          for (final donVi in cacDonVi)
                            DropdownMenuItem(
                              value: donVi,
                              child: Text(
                                donVi.isEmpty ? 'Chưa phân đơn vị' : donVi,
                              ),
                            ),
                        ],
                        onChanged: (v) => _setReportState(() {
                          unitFilter = v;
                          subUnitFilter = null;
                          visibleRows = 50;
                        }),
                      ),
                    ),
                    if (selectedUnit != null)
                      SizedBox(
                        width: chieuRong,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(
                            'sub-unit:$selectedUnit:$selectedSubUnit',
                          ),
                          initialValue: selectedSubUnit,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Trực thuộc',
                            prefixIcon: Icon(Icons.account_tree_outlined),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Tất cả trực thuộc'),
                            ),
                            for (final giaTri in subUnits)
                              DropdownMenuItem(
                                value: giaTri,
                                child: Text(giaTri),
                              ),
                          ],
                          onChanged: (v) => _setReportState(() {
                            subUnitFilter = v;
                            visibleRows = 50;
                          }),
                        ),
                      ),
                    SizedBox(
                      width: chieuRong,
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          labelText: 'Tìm học viên hoặc đơn vị',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) =>
                            _setReportState(() => visibleRows = 50),
                      ),
                    ),
                    SizedBox(
                      width: chieuRong,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('exam:$selectedExam'),
                        initialValue: selectedExam,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Bài thi',
                          prefixIcon: Icon(Icons.assignment_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tất cả bài thi'),
                          ),
                          for (final banGhi in sortedExams)
                            DropdownMenuItem(
                              value: banGhi.id,
                              child: Text(
                                banGhi.data()['title'] ?? banGhi.id,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => _setReportState(() {
                          examFilter = v;
                          visibleRows = 50;
                        }),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _setReportState(() {
                        searchController.clear();
                        examFilter = null;
                        unitFilter = null;
                        subUnitFilter = null;
                        visibleRows = 50;
                      }),
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: const Text('Xóa bộ lọc'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1050
                  ? 6
                  : constraints.maxWidth >= 650
                  ? 3
                  : 2;
              final chieuRong =
                  (constraints.maxWidth - 12 * (columns - 1)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _chiSo(
                    chieuRong,
                    'Bài thi',
                    '${baoCao.examCount}',
                    Icons.quiz_outlined,
                    Colors.blue,
                  ),
                  _chiSo(
                    chieuRong,
                    'Học viên đã thi',
                    '${baoCao.participants}',
                    Icons.people_outline,
                    AppTheme.navy,
                  ),
                  _chiSo(
                    chieuRong,
                    'Lượt đã nộp',
                    '${baoCao.attempts}',
                    Icons.assignment_turned_in_outlined,
                    Colors.orange,
                  ),
                  _chiSo(
                    chieuRong,
                    'Điểm TB tốt nhất',
                    baoCao.average?.toStringAsFixed(2) ?? '—',
                    Icons.trending_up,
                    AppTheme.red,
                  ),
                  _chiSo(
                    chieuRong,
                    'Tỷ lệ đạt',
                    baoCao.passRate == null
                        ? '—'
                        : '${baoCao.passRate!.toStringAsFixed(1)}%',
                    Icons.check_circle_outline,
                    Colors.green,
                  ),
                  _chiSo(
                    chieuRong,
                    'Kết quả chưa đạt',
                    '${baoCao.failed}',
                    Icons.pending_actions_outlined,
                    Colors.deepOrange,
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${baoCao.studentCount} học viên trong phạm vi lọc • ${baoCao.rows.length} kết quả học viên–bài thi.',
          style: const TextStyle(color: Colors.blueGrey),
        ),
        const SizedBox(height: 6),
        const Text(
          'Mỗi học viên được tính một kết quả tốt nhất cho mỗi đề. Tỷ lệ đạt và điểm trung bình tính trên các kết quả này; số lượt đã nộp vẫn tính tất cả lượt.',
          style: TextStyle(fontSize: 12, color: Colors.blueGrey, height: 1.5),
        ),
        if (baoCao.ungraded > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${baoCao.ungraded} kết quả thiếu điểm hợp lệ, chưa tính vào điểm trung bình và tỷ lệ đạt.',
            ),
          ),
        const SizedBox(height: 22),
        _dauMuc('Tiến độ theo đơn vị'),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Đã làm = học viên có ít nhất một lượt đã nộp trong bài thi đang lọc; mỗi người chỉ tính một lần.',
            style: TextStyle(color: Colors.blueGrey, fontSize: 12),
          ),
        ),
        for (final donVi in cacDonVi.where(
          (u) => selectedUnit == null || u == selectedUnit,
        ))
          Builder(
            builder: (context) {
              final thanhVien = cacNguoiDung
                  .where(
                    (u) =>
                        u.data()['role'] == 'user' &&
                        (u.data()['unit'] ?? '') == donVi &&
                        '${u.id} ${u.data()['name'] ?? ''} ${u.data()['username'] ?? ''} ${u.data()['unit'] ?? ''} ${u.data()['subUnit'] ?? ''} ${u.data()['subUnit'] ?? ''}-${u.data()['unit'] ?? ''}'
                            .toLowerCase()
                            .contains(
                              searchController.text.trim().toLowerCase(),
                            ),
                  )
                  .map((u) => u.id)
                  .toSet();
              final daXong = baoCao.rows
                  .where((r) => thanhVien.contains(r.userId))
                  .map((r) => r.userId)
                  .toSet()
                  .length;
              final adminCount = cacNguoiDung
                  .where(
                    (u) =>
                        ['admin', 'super_admin'].contains(u.data()['role']) &&
                        (u.data()['role'] == 'super_admin'
                                ? 'E09'
                                : u.data()['unit'] ?? '') ==
                            donVi,
                  )
                  .length;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.apartment, color: AppTheme.red),
                  title: Text(
                    donVi.isEmpty ? 'Chưa phân đơn vị' : donVi,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '$adminCount quản lý • ${thanhVien.length} học viên\nĐã làm: $daXong • Chưa làm: ${thanhVien.length - daXong}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    thanhVien.isEmpty
                        ? '—'
                        : '${(daXong * 100 / thanhVien.length).round()}%',
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dauMuc('Phân bố điểm tốt nhất'),
                const SizedBox(height: 16),
                for (var i = 0; i < 5; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 65,
                          child: Text(
                            i == 4 ? '8–10' : '${i * 2}–<${i * 2 + 2}',
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              minHeight: 10,
                              value: scored == 0 ? 0 : distribution[i] / scored,
                              color: AppTheme.red,
                              backgroundColor: const Color(0xFFF2E6E7),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 46,
                          child: Text(
                            '${distribution[i]}',
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Text(
                  'Số kết quả trong từng khoảng điểm, thang điểm 10.',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _dauMuc('Kết quả chi tiết (${baoCao.rows.length})'),
        const SizedBox(height: 8),
        if (baoCao.rows.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text('Chưa có kết quả phù hợp với bộ lọc.'),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final cacDong = baoCao.rows.take(visibleRows).toList();
              if (constraints.maxWidth < 750) {
                return Column(
                  children: [
                    for (final dong in cacDong)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dong.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${dong.subUnit.isEmpty ? '' : '${dong.subUnit}-'}${dong.unit}',
                                style: const TextStyle(color: Colors.blueGrey),
                              ),
                              const SizedBox(height: 8),
                              Text(dong.examTitle),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text('${dong.attempts} lượt'),
                                  Text(
                                    'Điểm: ${dong.score?.toStringAsFixed(2) ?? '—'}',
                                  ),
                                  _trangThai(dong),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Nộp gần nhất: ${_ngayHienThi(dong.submittedAt)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              }
              return Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Học viên')),
                      DataColumn(label: Text('Đơn vị')),
                      DataColumn(label: Text('Bài thi')),
                      DataColumn(label: Text('Lượt nộp'), numeric: true),
                      DataColumn(label: Text('Điểm tốt nhất'), numeric: true),
                      DataColumn(label: Text('Kết quả')),
                      DataColumn(label: Text('Nộp gần nhất')),
                    ],
                    rows: [
                      for (final dong in cacDong)
                        DataRow(
                          cells: [
                            DataCell(
                              SizedBox(width: 150, child: Text(dong.name)),
                            ),
                            DataCell(
                              SizedBox(
                                width: 130,
                                child: Text(
                                  '${dong.subUnit.isEmpty ? '' : '${dong.subUnit}-'}${dong.unit}',
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(width: 200, child: Text(dong.examTitle)),
                            ),
                            DataCell(Text('${dong.attempts}')),
                            DataCell(
                              Text(dong.score?.toStringAsFixed(2) ?? '—'),
                            ),
                            DataCell(_trangThai(dong)),
                            DataCell(Text(_ngayHienThi(dong.submittedAt))),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        if (baoCao.rows.length > visibleRows)
          TextButton(
            onPressed: () => _setReportState(() => visibleRows += 50),
            child: const Text('Xem thêm kết quả'),
          ),
        const SizedBox(height: 20),
        _dauMuc('Người dùng có điểm cao nhất'),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '10 học viên có điểm tốt nhất trong phạm vi lọc.',
            style: TextStyle(color: Colors.blueGrey, fontSize: 12),
          ),
        ),
        if (rank.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Chưa có kết quả đã nộp.'),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < rank.length && i < 10; i++)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFF9E8E8),
                      child: Text(
                        '#${i + 1}',
                        style: const TextStyle(color: AppTheme.red),
                      ),
                    ),
                    title: Text(
                      rank[i].name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(rank[i].examTitle),
                    trailing: Text(
                      rank[i].score!.toStringAsFixed(2),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.red,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _dauMuc(String giaTri) => Text(
    giaTri,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      color: AppTheme.navy,
    ),
  );
  String _ngayHienThi(DateTime? giaTri) => giaTri == null
      ? 'Chưa có thời gian'
      : '${giaTri.day.toString().padLeft(2, '0')}/${giaTri.month.toString().padLeft(2, '0')}/${giaTri.year} ${giaTri.hour.toString().padLeft(2, '0')}:${giaTri.minute.toString().padLeft(2, '0')}';
  Widget _trangThai(AdminReportRow dong) {
    final mau = dong.passed == null
        ? Colors.blueGrey
        : dong.passed!
        ? Colors.green
        : Colors.deepOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        dong.passed == null
            ? 'Thiếu điểm'
            : dong.passed!
            ? 'Đạt'
            : 'Chưa đạt',
        style: TextStyle(color: mau, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _chiSo(
    double chieuRong,
    String nhan,
    String giaTri,
    IconData bieuTuong,
    Color mau,
  ) => SizedBox(
    width: chieuRong,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(bieuTuong, color: mau),
            const SizedBox(height: 12),
            Text(
              giaTri,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              nhan,
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _dungThongBaoLoi(String thongDiep) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(thongDiep, textAlign: TextAlign.center),
    ),
  );
}
