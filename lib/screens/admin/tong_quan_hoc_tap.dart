// WEB ADMIN: Bảng tổng hợp tiến độ học tập theo học viên và đơn vị.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'package:flutter/material.dart';

import '../../models/quy_tac_hoc_tap.dart';
import '../../services/nguon_du_lieu_bao_cao_quan_tri.dart';
import '../../widgets/giao_dien_quan_tri.dart';
import '../../widgets/bo_loc_bao_cao_quan_tri.dart';

/// Bảng tổng hợp tiến độ học tập theo học viên và đơn vị.
class AdminLearningDashboard extends StatefulWidget {
  const AdminLearningDashboard({super.key, required this.reportData});
  final AdminReportData reportData;
  @override
  State<AdminLearningDashboard> createState() =>
      _TrangThaiTongQuanHocTapQuanTri();
}

class _TrangThaiTongQuanHocTapQuanTri extends State<AdminLearningDashboard> {
  final searchController = TextEditingController();
  AdminReportData? _reportInputs;
  Future<List<Map<String, dynamic>>>? _report;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load(AdminReportData data) async {
    final cacHocVien = data.users
        .where((user) => user.data()['role'] == 'user')
        .toList();
    final cacKhoaHoc = data.visibleCourses;
    final cacBaiHoc = <String, Set<String>>{};
    for (final khoaHoc in cacKhoaHoc) {
      cacBaiHoc[khoaHoc.id] =
          (await khoaHoc.reference.collection('lessons').get()).docs
              .map((d) => d.id)
              .toSet();
    }
    final cacDong = <Map<String, dynamic>>[];
    for (final hocVien in cacHocVien) {
      final hoSo = hocVien.data();
      final tienDo = await hocVien.reference.collection('learning').get();
      var tongSo = 0;
      var daHoanThanh = 0;
      for (final khoaHoc in cacKhoaHoc.where(
        (c) => LearningPolicy.canRead(c.data(), hoSo['classId'] ?? ''),
      )) {
        final cacMa = cacBaiHoc[khoaHoc.id]!;
        tongSo += cacMa.length;
        daHoanThanh += tienDo.docs
            .where(
              (d) =>
                  d.data()['courseId'] == khoaHoc.id &&
                  d.data()['completed'] == true,
            )
            .map((d) => d.data()['lessonId'])
            .toSet()
            .intersection(cacMa)
            .length;
      }
      cacDong.add({
        'userId': hocVien.id,
        'name': hoSo['name'] ?? '',
        'classId': hoSo['classId'] ?? '',
        'unit': hoSo['unit'] ?? '',
        'subUnit': hoSo['subUnit'] ?? '',
        'completed': daHoanThanh,
        'total': tongSo,
      });
    }
    return cacDong;
  }

  Future<List<Map<String, dynamic>>> _loadFor(AdminReportData data) {
    if (_report == null ||
        !(_reportInputs?.hasSameLearningInputs(data) ?? false)) {
      _reportInputs = data;
      _report = _load(data);
    }
    return _report!;
  }

  void _refresh(AdminReportData data) => setState(() {
    _reportInputs = null;
    _report = null;
  });

  String search = '';
  bool incomplete = false;
  String? unitFilter;
  String? subUnitFilter;
  @override
  Widget build(BuildContext context) => _dungBang(widget.reportData);

  Widget _dungBang(
    AdminReportData data,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _loadFor(data),
    builder: (context, duLieuNhan) {
      if (duLieuNhan.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Không tải được thống kê.'),
              TextButton(
                onPressed: () => _refresh(data),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        );
      }
      if (!duLieuNhan.hasData) {
        return const AdminLoading();
      }
      final scoresByUser = <String, List<double>>{};
      for (final attempt in data.visibleAttempts) {
        final attemptData = attempt.data();
        final userId = attemptData['userId']?.toString();
        final score = attemptData['diemSo'];
        if (userId != null && score is num) {
          scoresByUser.putIfAbsent(userId, () => []).add(score.toDouble());
        }
      }
      final cacDong = duLieuNhan.data!.map((row) {
        final scores = scoresByUser[row['userId']] ?? const <double>[];
        return {
          ...row,
          'average': scores.isEmpty
              ? null
              : scores.reduce((a, b) => a + b) / scores.length,
        };
      }).toList();
      final cacDonVi =
          cacDong
              .map((dong) => dong['unit'].toString().trim())
              .where((donVi) => donVi.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      final selectedUnit = cacDonVi.contains(unitFilter) ? unitFilter : null;
      final subUnits =
          cacDong
              .where((dong) => dong['unit'] == selectedUnit)
              .map((dong) => dong['subUnit'].toString().trim())
              .where((trucThuoc) => trucThuoc.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      final selectedSubUnit = subUnits.contains(subUnitFilter)
          ? subUnitFilter
          : null;
      final filteredRows = cacDong.where((dong) {
        final vanBan =
            '${dong['name']} ${dong['classId']} ${dong['unit']} ${dong['subUnit']}'
                .toLowerCase();
        return (selectedUnit == null || dong['unit'] == selectedUnit) &&
            (selectedSubUnit == null || dong['subUnit'] == selectedSubUnit) &&
            vanBan.contains(search) &&
            (!incomplete || dong['completed'] < dong['total']);
      }).toList();
      final notStarted = filteredRows
          .where((dong) => dong['completed'] == 0)
          .length;
      final filterLabel = selectedSubUnit != null
          ? '$selectedUnit / $selectedSubUnit'
          : selectedUnit ?? 'tất cả đơn vị';
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          AdminPageHeading(
            title: 'Tổng quan học tập',
            subtitle:
                'Theo dõi mức độ hoàn thành bài học theo học viên và đơn vị.',
            action: OutlinedButton.icon(
              onPressed: () => _refresh(data),
              icon: const Icon(Icons.refresh),
              label: const Text('Làm mới'),
            ),
          ),
          const SizedBox(height: 4),
          AdminReportFilters(
            units: cacDonVi,
            subUnits: subUnits,
            selectedUnit: selectedUnit,
            selectedSubUnit: selectedSubUnit,
            searchController: searchController,
            searchLabel: 'Lọc học viên, đơn vị',
            onUnitChanged: (value) => setState(() {
              unitFilter = value;
              subUnitFilter = null;
            }),
            onSubUnitChanged: (value) => setState(() => subUnitFilter = value),
            onSearchChanged: (value) =>
                setState(() => search = value.toLowerCase()),
          ),
          const SizedBox(height: 12),
          Card(
            color: notStarted == 0
                ? Colors.green.shade50
                : Colors.orange.shade50,
            child: ListTile(
              leading: Icon(
                notStarted == 0
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
                color: notStarted == 0
                    ? Colors.green.shade700
                    : Colors.orange.shade800,
              ),
              title: Text(
                notStarted == 0
                    ? 'Mọi người trong $filterLabel đã bắt đầu học'
                    : '$filterLabel còn $notStarted người chưa làm',
              ),
              subtitle: Text(
                'Chưa làm bài nào • Phạm vi hiện tại: ${filteredRows.length} học viên',
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Chỉ học viên chưa hoàn thành'),
            value: incomplete,
            onChanged: (v) => setState(() => incomplete = v),
          ),
          for (final dong in filteredRows)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dong['name']} • ${dong['unit']}${dong['subUnit'].toString().trim().isEmpty ? '' : ' • ${dong['subUnit']}'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${dong['completed']}/${dong['total']} bài học • Điểm TB tốt nhất: ${(dong['average'] as double?)?.toStringAsFixed(2) ?? 'Chưa thi'}',
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: dong['total'] == 0
                          ? 0
                          : dong['completed'] / dong['total'],
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
