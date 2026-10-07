// Bảng dữ liệu báo cáo: lọc đề thi/lượt thi và hiển thị kết quả theo học viên, đơn vị.
// Đây là phần tách riêng của bao_cao_thong_ke.dart.
part of "bao_cao_thong_ke.dart";

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
            child: AdminReportFilters(
              units: cacDonVi,
              subUnits: subUnits,
              selectedUnit: selectedUnit,
              selectedSubUnit: selectedSubUnit,
              searchController: searchController,
              searchLabel: 'Tìm học viên hoặc đơn vị',
              onUnitChanged: (value) => _setReportState(() {
                unitFilter = value;
                subUnitFilter = null;
                visibleRows = 50;
              }),
              onSubUnitChanged: (value) => _setReportState(() {
                subUnitFilter = value;
                visibleRows = 50;
              }),
              onSearchChanged: (_) => _setReportState(() => visibleRows = 50),
              exams: [
                for (final exam in sortedExams)
                  (exam.id, (exam.data()['title'] ?? exam.id).toString()),
              ],
              selectedExam: selectedExam,
              onExamChanged: (value) => _setReportState(() {
                examFilter = value;
                visibleRows = 50;
              }),
              onClear: () => _setReportState(() {
                searchController.clear();
                examFilter = null;
                unitFilter = null;
                subUnitFilter = null;
                visibleRows = 50;
              }),
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
        const SizedBox(height: 22),
        _dauMuc('Tiến độ theo đơn vị'),
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 8, 28, 8),
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
                  .where((u) {
                    final user = u.data();
                    return user['role'] == 'user' &&
                        AdminReport.matchesUser(
                          u.id,
                          user,
                          unit: donVi,
                          subUnit: selectedSubUnit,
                          search: searchController.text,
                        );
                  })
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
              final tiLeHoanThanh = thanhVien.isEmpty
                  ? 0.0
                  : daXong / thanhVien.length;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCECEE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.apartment_rounded,
                          color: AppTheme.red,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    donVi.isEmpty ? 'Chưa phân đơn vị' : donVi,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  thanhVien.isEmpty
                                      ? '—'
                                      : '${(tiLeHoanThanh * 100).round()}%',
                                  style: const TextStyle(
                                    color: AppTheme.navy,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$adminCount quản lý • ${thanhVien.length} học viên',
                              style: const TextStyle(color: Colors.blueGrey),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                minHeight: 8,
                                value: tiLeHoanThanh,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 20),
        _dauMuc('Phân bố điểm'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
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
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
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
                margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
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
            margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < rank.length && i < 10; i++)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: i == 0
                          ? const Color(0xFFFFF3CD)
                          : const Color(0xFFF9E8E8),
                      child: Text(
                        '#${i + 1}',
                        style: TextStyle(
                          color: i == 0
                              ? const Color(0xFFAA7600)
                              : AppTheme.red,
                        ),
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

  Widget _dauMuc(String giaTri) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: Text(
      giaTri,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppTheme.navy,
      ),
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
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: mau.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(bieuTuong, color: mau),
            ),
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
}
