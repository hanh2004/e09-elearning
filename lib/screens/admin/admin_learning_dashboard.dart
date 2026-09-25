// WEB ADMIN: Bảng tổng hợp tiến độ học tập theo học viên và đơn vị.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'admin_responsive_shell.dart';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../services/nghiep_vu/learning_service.dart';
import '../../widgets/admin_ui.dart';

/// Bảng tổng hợp tiến độ học tập theo học viên và đơn vị.
class AdminLearningDashboard extends StatefulWidget {
  const AdminLearningDashboard({super.key});
  @override
  State<AdminLearningDashboard> createState() =>
      _TrangThaiTongQuanHocTapQuanTri();
}

class _TrangThaiTongQuanHocTapQuanTri extends State<AdminLearningDashboard> {
  final service = LearningService();
  late Future<Map<String, dynamic>> report = load();
  Future<Map<String, dynamic>> load() async {
    final cacDuLieuNhan = await Future.wait([
      service.db.collection('users').where('role', isEqualTo: 'user').get(),
      service.db.collection('courses').get(),
      service.db.collection('exam_attempts').get(),
    ]);
    final cacHocVien = cacDuLieuNhan[0].docs;
    final cacKhoaHoc = cacDuLieuNhan[1].docs;
    final cacLuotThi = cacDuLieuNhan[2].docs;
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
      final scores = cacLuotThi
          .where(
            (a) =>
                a.data()['userId'] == hocVien.id && a.data()['diemSo'] is num,
          )
          .map((a) => (a.data()['diemSo'] as num).toDouble())
          .toList();
      cacDong.add({
        'name': hoSo['name'] ?? '',
        'classId': hoSo['classId'] ?? '',
        'unit': hoSo['unit'] ?? '',
        'subUnit': hoSo['subUnit'] ?? '',
        'completed': daHoanThanh,
        'total': tongSo,
        'average': scores.isEmpty
            ? null
            : scores.reduce((a, b) => a + b) / scores.length,
      });
    }
    final scores = cacLuotThi
        .where((a) => a.data()['diemSo'] is num)
        .map((a) => (a.data()['diemSo'] as num).toDouble())
        .toList();
    return {
      'students': cacHocVien.length,
      'courses': cacKhoaHoc.length,
      'lessons': cacBaiHoc.values.fold<int>(
        0,
        (tongSo, cacMa) => tongSo + cacMa.length,
      ),
      'attempts': cacLuotThi.fold<int>(
        0,
        (tongSo, a) =>
            tongSo +
            ((a.data()['attemptCount'] as num?)?.toInt() ??
                (a.data()['status'] == 'completed' ? 1 : 0)),
      ),
      'average': scores.isEmpty
          ? '—'
          : (scores.reduce((a, b) => a + b) / scores.length).toStringAsFixed(2),
      'rows': cacDong,
    };
  }

  String search = '';
  bool incomplete = false;
  String? unitFilter;
  String? subUnitFilter;
  @override
  Widget build(BuildContext context) => AdminResponsiveShell(
    selectedIndex: 2,
    onSelected: (viTri) => pushAdminPrimary(context, viTri),
    activeExtra: 'Tổng quan học tập',
    child: Scaffold(
      appBar: AdminUi.appBar(
        'Tổng quan học tập',
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: () => setState(() => report = load()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: report,
        builder: (context, duLieuNhan) {
          if (duLieuNhan.hasError) {
            return const Center(
              child: Text('Không tải được thống kê. Bấm làm mới để thử lại.'),
            );
          }
          if (!duLieuNhan.hasData) {
            return const AdminLoading();
          }
          final duLieu = duLieuNhan.data!;
          final cacDong = duLieu['rows'] as List<Map<String, dynamic>>;
          final cacDonVi =
              cacDong
                  .map((dong) => dong['unit'].toString().trim())
                  .where((donVi) => donVi.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
          final selectedUnit = cacDonVi.contains(unitFilter)
              ? unitFilter
              : null;
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
                (selectedSubUnit == null ||
                    dong['subUnit'] == selectedSubUnit) &&
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
              const AdminPageHeading(
                title: 'Tổng quan học tập',
                subtitle: 'Theo dõi kết quả học tập của học viên theo đơn vị.',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final capDuLieu in {
                      'students': (
                        'Học viên',
                        Icons.people_outline,
                        Colors.blue,
                      ),
                      'courses': (
                        'Khóa học',
                        Icons.menu_book_outlined,
                        AppTheme.red,
                      ),
                      'lessons': (
                        'Bài học',
                        Icons.description_outlined,
                        Colors.orange,
                      ),
                      'attempts': (
                        'Lượt thi',
                        Icons.check_circle_outline,
                        Colors.green,
                      ),
                      'average': (
                        'Điểm TB tốt nhất',
                        Icons.bar_chart_outlined,
                        Colors.deepPurple,
                      ),
                    }.entries)
                      SizedBox(
                        width: 220,
                        child: AdminMetricCard(
                          value: '${duLieu[capDuLieu.key]}',
                          label: capDuLieu.value.$1,
                          icon: capDuLieu.value.$2,
                          color: capDuLieu.value.$3,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(height: 4),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Lọc học viên, đơn vị',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => search = v.toLowerCase()),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedUnit,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Đơn vị',
                        prefixIcon: Icon(Icons.apartment),
                      ),
                      hint: const Text('Tất cả đơn vị'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Tất cả đơn vị'),
                        ),
                        for (final donVi in cacDonVi)
                          DropdownMenuItem(value: donVi, child: Text(donVi)),
                      ],
                      onChanged: (giaTri) => setState(() {
                        unitFilter = giaTri;
                        subUnitFilter = null;
                      }),
                    ),
                  ),
                  if (selectedUnit != null)
                    SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedSubUnit,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Trực thuộc',
                          prefixIcon: Icon(Icons.account_tree_outlined),
                        ),
                        hint: const Text('Tất cả trực thuộc'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tất cả trực thuộc'),
                          ),
                          for (final trucThuoc in subUnits)
                            DropdownMenuItem(
                              value: trucThuoc,
                              child: Text(trucThuoc),
                            ),
                        ],
                        onChanged: (giaTri) =>
                            setState(() => subUnitFilter = giaTri),
                      ),
                    ),
                ],
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
      ),
    ),
  );
}
