// WEB ADMIN: Theo dõi các lượt làm bài, điểm số và học viên đã thi.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../models/bao_cao_quan_tri.dart';
import '../../widgets/giao_dien_quan_tri.dart';
import '../../widgets/anh_dai_dien_mac_dinh.dart';

import '../../services/nguon_du_lieu_bao_cao_quan_tri.dart';

/// Theo dõi các lượt làm bài, điểm số và học viên đã thi.
class AdminProgressScreen extends StatefulWidget {
  const AdminProgressScreen({super.key, required this.reportData});
  final AdminReportData reportData;

  @override
  State<AdminProgressScreen> createState() => _TrangThaiTienDoQuanTri();
}

class _TrangThaiTienDoQuanTri extends State<AdminProgressScreen> {
  static const primaryColor = Color(0xFFB51F24);

  @override
  Widget build(BuildContext context) => _dungDuLieu(widget.reportData);

  Widget _dungDuLieu(AdminReportData data) {
    final report = AdminReport.build(
      users: {for (final user in data.users) user.id: user.data()},
      exams: {for (final exam in data.visibleExams) exam.id: exam.data()},
      attempts: data.visibleAttempts.map((attempt) => attempt.data()).toList(),
    );
    return _dungNoiDung(data.visibleExams, data.visibleAttempts, report);
  }

  Widget _dungNoiDung(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cacBaiThi,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allAttempts,
    AdminReport report,
  ) {
    final inProgressCount = allAttempts
        .where((luotThi) => luotThi.data()['status'] == 'in_progress')
        .length;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 16, 28, 12),
          child: Text(
            'Theo dõi tiến độ',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: _dungTongQuan(
            examCount: cacBaiThi.length,
            completedUserCount: report.participants,
            attemptCount: report.attempts,
            inProgressCount: inProgressCount,
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            'Kết quả theo bài thi',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (cacBaiThi.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Chưa có bài thi nào.')),
          )
        else
          ...cacBaiThi.map((baiThi) {
            final cacLuotThi = report.rows
                .where((luotThi) => luotThi.examId == baiThi.id)
                .toList();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _dungTheBaiThi(baiThi, cacLuotThi),
            );
          }),
      ],
    );
  }

  Widget _dungTongQuan({
    required int examCount,
    required int completedUserCount,
    required int attemptCount,
    required int inProgressCount,
  }) {
    final cards = [
      ('Bài thi', examCount, Icons.quiz_outlined, Colors.blue),
      ('Người đã làm', completedUserCount, Icons.people_outline, AppTheme.navy),
      ('Lượt đã nộp', attemptCount, Icons.task_alt, Colors.green),
      ('Đang làm', inProgressCount, Icons.timer_outlined, Colors.orange),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          for (final card in cards)
            SizedBox(
              width: constraints.maxWidth >= 900
                  ? (constraints.maxWidth - 36) / 4
                  : constraints.maxWidth >= 560
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth,
              child: _dungTheTongQuan(
                value: '${card.$2}',
                label: card.$1,
                icon: card.$3,
                color: card.$4,
              ),
            ),
        ],
      ),
    );
  }

  Widget _dungTheTongQuan({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) => AdminCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 25),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.navy,
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF60779A), fontSize: 14),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _dungTheBaiThi(
    QueryDocumentSnapshot<Map<String, dynamic>> baiThi,
    List<AdminReportRow> cacLuotThi,
  ) {
    final examData = baiThi.data();
    final bestScores = cacLuotThi
        .map((luotThi) => luotThi.score)
        .whereType<double>()
        .toList();
    final average = bestScores.isEmpty
        ? null
        : bestScores.reduce((a, b) => a + b) / bestScores.length;
    final totalAttemptCount = cacLuotThi.fold(
      0,
      (tongSo, luotThi) => tongSo + luotThi.attempts,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AdminUi.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _hienChiTietBaiThi(baiThi, cacLuotThi),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.assignment_rounded,
                      color: primaryColor,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      (examData['title'] ?? 'Bài kiểm tra').toString(),
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF292929),
                    size: 24,
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: AdminUi.border),
              ),
              Row(
                children: [
                  Expanded(
                    child: _dungChiSoBaiThi(
                      'Người đã làm',
                      '${cacLuotThi.length}',
                    ),
                  ),
                  const SizedBox(
                    height: 40,
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AdminUi.border,
                    ),
                  ),
                  Expanded(
                    child: _dungChiSoBaiThi(
                      'Tổng lượt làm',
                      '$totalAttemptCount',
                    ),
                  ),
                  const SizedBox(
                    height: 40,
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AdminUi.border,
                    ),
                  ),
                  Expanded(
                    child: _dungChiSoBaiThi(
                      'Điểm tốt TB',
                      average?.toStringAsFixed(1) ?? '—',
                      valueColor: average != null && average > 0
                          ? const Color(0xFF159B43)
                          : AppTheme.navy,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dungChiSoBaiThi(
    String nhan,
    String giaTri, {
    Color valueColor = AppTheme.navy,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          giaTri,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          nhan,
          style: const TextStyle(color: Color(0xFF7185A5), fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _hienChiTietBaiThi(
    QueryDocumentSnapshot<Map<String, dynamic>> baiThi,
    List<AdminReportRow> cacLuotThi,
  ) {
    final totalAttemptCount = cacLuotThi.fold(
      0,
      (tongSo, luotThi) => tongSo + luotThi.attempts,
    );
    final cacCapDuLieu = cacLuotThi.toList()
      ..sort((a, b) => (b.score ?? -1).compareTo(a.score ?? -1));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, boDieuKhien) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (baiThi.data()['title'] ?? 'Bài kiểm tra').toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${cacCapDuLieu.length} người • $totalAttemptCount lượt làm',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: cacCapDuLieu.isEmpty
                  ? const Center(child: Text('Chưa có học viên nộp bài.'))
                  : ListView.builder(
                      controller: boDieuKhien,
                      padding: const EdgeInsets.all(12),
                      itemCount: cacCapDuLieu.length,
                      itemBuilder: (context, viTri) {
                        return _dungKetQuaHocVien(cacCapDuLieu[viTri]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dungKetQuaHocVien(AdminReportRow row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: const DefaultUserAvatar(radius: 20),
        title: Text(
          row.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Đã làm ${row.attempts} lần • ${_dinhDangNgay(row.bestAt ?? row.submittedAt)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              row.score?.toStringAsFixed(1) ?? 'Thiếu điểm',
              style: TextStyle(
                color: row.passed == null
                    ? Colors.blueGrey
                    : row.passed!
                    ? Colors.green
                    : Colors.red,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text('cao nhất', style: TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  String _dinhDangNgay(DateTime? ngay) {
    if (ngay == null) return 'Chưa có thời gian nộp';
    String two(int giaTri) => giaTri.toString().padLeft(2, '0');
    return '${two(ngay.hour)}:${two(ngay.minute)} ${two(ngay.day)}/${two(ngay.month)}/${ngay.year}';
  }
}
