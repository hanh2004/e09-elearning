// WEB ADMIN: Theo dõi các lượt làm bài, điểm số và học viên đã thi.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../models/ket_qua_bai_kiem_tra.dart';
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
    final userNames = {
      for (final user in data.users)
        user.id: (user.data()['name'] ?? user.data()['username'] ?? user.id)
            .toString(),
    };
    return _dungNoiDung(data.visibleExams, data.visibleAttempts, userNames);
  }

  Widget _dungNoiDung(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cacBaiThi,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allAttempts,
    Map<String, String> userNames,
  ) {
    final resultRecords = allAttempts
        .where((luotThi) => _soLuotThi(luotThi) > 0)
        .toList();
    final inProgressCount = allAttempts
        .where((luotThi) => luotThi.data()['status'] == 'in_progress')
        .length;
    final completedUsers = resultRecords
        .map((luotThi) => luotThi.data()['userId']?.toString())
        .whereType<String>()
        .toSet();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const AdminPageHeading(
          title: 'Theo dõi tiến độ',
          subtitle: 'Theo dõi tình trạng thực hiện và kết quả từng bài thi.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: _dungTongQuan(
            examCount: cacBaiThi.length,
            completedUserCount: completedUsers.length,
            attemptCount: resultRecords.fold(
              0,
              (tongSo, luotThi) => tongSo + _soLuotThi(luotThi),
            ),
            inProgressCount: inProgressCount,
          ),
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            'Kết quả theo bài thi',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (cacBaiThi.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Chưa có bài thi nào.')),
          )
        else
          ...cacBaiThi.map((baiThi) {
            final cacLuotThi = resultRecords
                .where((luotThi) => luotThi.data()['examId'] == baiThi.id)
                .toList();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _dungTheBaiThi(baiThi, cacLuotThi, userNames),
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
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final card in cards)
            SizedBox(
              width: constraints.maxWidth >= 900
                  ? (constraints.maxWidth - 48) / 4
                  : constraints.maxWidth >= 560
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth,
              child: AdminMetricCard(
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

  Widget _dungTheBaiThi(
    QueryDocumentSnapshot<Map<String, dynamic>> baiThi,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cacLuotThi,
    Map<String, String> userNames,
  ) {
    final examData = baiThi.data();
    final cacNguoiDung = cacLuotThi
        .map((luotThi) => luotThi.data()['userId']?.toString())
        .whereType<String>()
        .toSet();
    final bestScores = _nhomLuotThiTheoHocVien(cacLuotThi).values
        .map(_diemCaoNhat)
        .toList();
    final average = bestScores.isEmpty
        ? 0.0
        : bestScores.reduce((a, b) => a + b) / bestScores.length;
    final totalAttemptCount = cacLuotThi.fold(
      0,
      (tongSo, luotThi) => tongSo + _soLuotThi(luotThi),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AdminUi.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _hienChiTietBaiThi(baiThi, cacLuotThi, userNames),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.assignment_rounded,
                      color: primaryColor,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      (examData['title'] ?? 'Bài kiểm tra').toString(),
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF292929),
                    size: 28,
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: AdminUi.border),
              ),
              Row(
                children: [
                  Expanded(
                    child: _dungChiSoBaiThi(
                      'Người đã làm',
                      '${cacNguoiDung.length}',
                    ),
                  ),
                  const SizedBox(
                    height: 48,
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
                    height: 48,
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AdminUi.border,
                    ),
                  ),
                  Expanded(
                    child: _dungChiSoBaiThi(
                      'Điểm tốt TB',
                      average.toStringAsFixed(1),
                      valueColor: average > 0
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
            fontSize: 22,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          nhan,
          style: const TextStyle(color: Color(0xFF7185A5), fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _nhomLuotThiTheoHocVien(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cacLuotThi,
  ) {
    final grouped =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final luotThi in cacLuotThi) {
      final userId = luotThi.data()['userId']?.toString() ?? 'unknown';
      grouped.putIfAbsent(userId, () => []).add(luotThi);
    }
    return grouped;
  }

  double _diemCaoNhat(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cacLuotThi,
  ) {
    var totNhat = 0.0;
    for (final luotThi in cacLuotThi) {
      final duLieu = luotThi.data();
      final diem =
          (duLieu['bestScore'] as num?)?.toDouble() ??
          (duLieu['diemSo'] as num?)?.toDouble() ??
          0;
      if (diem > totNhat) totNhat = diem;
    }
    return totNhat;
  }

  int _soLuotThi(QueryDocumentSnapshot<Map<String, dynamic>> luotThi) {
    final duLieu = luotThi.data();
    return (duLieu['attemptCount'] as num?)?.toInt() ??
        (duLieu['status'] == 'completed' ? 1 : 0);
  }

  void _hienChiTietBaiThi(
    QueryDocumentSnapshot<Map<String, dynamic>> baiThi,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cacLuotThi,
    Map<String, String> userNames,
  ) {
    final grouped = _nhomLuotThiTheoHocVien(cacLuotThi);
    final totalAttemptCount = cacLuotThi.fold(
      0,
      (tongSo, luotThi) => tongSo + _soLuotThi(luotThi),
    );
    final cacCapDuLieu = grouped.entries.toList()
      ..sort((a, b) => _diemCaoNhat(b.value).compareTo(_diemCaoNhat(a.value)));

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
                        final capDuLieu = cacCapDuLieu[viTri];
                        return _dungKetQuaHocVien(
                          userNames[capDuLieu.key] ?? capDuLieu.key,
                          capDuLieu.value,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dungKetQuaHocVien(
    String userName,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cacLuotThi,
  ) {
    final totNhat = _diemCaoNhat(cacLuotThi);
    final ordered = cacLuotThi.toList()
      ..sort(
        (a, b) =>
            ExamOutcome.score(b.data()).compareTo(ExamOutcome.score(a.data())),
      );
    final daDat =
        ordered.isNotEmpty && ExamOutcome.passed(ordered.first.data());
    final attemptCount = cacLuotThi.fold(
      0,
      (tongSo, luotThi) => tongSo + _soLuotThi(luotThi),
    );
    DateTime? bestDate;
    for (final luotThi in cacLuotThi) {
      final duLieu = luotThi.data();
      final ngay =
          (duLieu['bestCompletedAt'] ?? duLieu['completedAt']) as Timestamp?;
      if (ngay != null &&
          (bestDate == null || ngay.toDate().isAfter(bestDate))) {
        bestDate = ngay.toDate();
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: const DefaultUserAvatar(radius: 20),
        title: Text(
          userName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Đã làm $attemptCount lần • ${_dinhDangNgay(bestDate)}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              totNhat.toStringAsFixed(1),
              style: TextStyle(
                color: daDat ? Colors.green : Colors.red,
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
