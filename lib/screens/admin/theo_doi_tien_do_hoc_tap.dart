// WEB ADMIN: Theo dõi các lượt làm bài, điểm số và học viên đã thi.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../models/ket_qua_bai_kiem_tra.dart';
import '../../models/quy_tac_hoc_tap.dart';
import '../../widgets/giao_dien_quan_tri.dart';
import '../../widgets/anh_dai_dien_mac_dinh.dart';

import '../../services/du_lieu/dich_vu_firestore.dart';
import 'khung_giao_dien_quan_tri.dart';

/// Theo dõi các lượt làm bài, điểm số và học viên đã thi.
class AdminProgressScreen extends StatefulWidget {
  const AdminProgressScreen({super.key});

  @override
  State<AdminProgressScreen> createState() => _TrangThaiTienDoQuanTri();
}

class _TrangThaiTienDoQuanTri extends State<AdminProgressScreen> {
  static const primaryColor = Color(0xFFB51F24);
  final FirestoreService _dichVuFirestore = FirestoreService();

  void _chonDieuHuong(int viTri) {
    pushAdminPrimary(context, viTri);
  }

  @override
  Widget build(BuildContext context) {
    final laMayTinh = AdminResponsiveShell.isDesktop(context);
    return AdminResponsiveShell(
      selectedIndex: 2,
      onSelected: _chonDieuHuong,
      activeExtra: 'Theo dõi tiến độ',
      child: Scaffold(
        backgroundColor: AdminUi.page,
        appBar: AdminUi.appBar('Theo dõi tiến độ'),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _dichVuFirestore.getExamsStream(),
          builder: (context, examSnapshot) {
            if (examSnapshot.hasError) {
              return _dungThongBaoLoi(
                'Không tải được bài thi',
                examSnapshot.error,
              );
            }
            if (!examSnapshot.hasData) {
              return const AdminLoading();
            }
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _dichVuFirestore.getExamAttemptsStream(),
              builder: (context, attemptSnapshot) {
                if (attemptSnapshot.hasError) {
                  return _dungThongBaoLoi(
                    'Không tải được lượt làm bài',
                    attemptSnapshot.error,
                  );
                }
                if (!attemptSnapshot.hasData) {
                  return const AdminLoading();
                }
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _dichVuFirestore.getUsersStream(),
                  builder: (context, userSnapshot) {
                    final userNames = <String, String>{};
                    for (final nguoiDung
                        in userSnapshot.data?.docs ?? const []) {
                      final duLieu = nguoiDung.data();
                      userNames[nguoiDung.id] =
                          (duLieu['name'] ?? duLieu['username'] ?? nguoiDung.id)
                              .toString();
                    }
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _dichVuFirestore.db
                          .collection('courses')
                          .snapshots(),
                      builder: (context, courseSnapshot) {
                        if (courseSnapshot.hasError) {
                          return _dungThongBaoLoi(
                            'Không tải được danh sách khóa học',
                            courseSnapshot.error,
                          );
                        }
                        if (!courseSnapshot.hasData) {
                          return const AdminLoading();
                        }
                        final visibility =
                            LearningContentVisibility.fromDocuments(
                              courses: courseSnapshot.data!.docs,
                              exams: examSnapshot.data!.docs,
                            );
                        return _dungNoiDung(
                          examSnapshot.data!.docs
                              .where(visibility.includesExam)
                              .toList(),
                          attemptSnapshot.data!.docs
                              .where(visibility.includesAttempt)
                              .toList(),
                          userNames,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
        bottomNavigationBar: laMayTinh
            ? null
            : BottomNavigationBar(
                currentIndex: 2,
                onTap: _chonDieuHuong,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: primaryColor,
                unselectedItemColor: Colors.grey,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: 'Trang chủ',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.assignment),
                    label: 'Quản lý khóa học',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.bar_chart),
                    label: 'Báo cáo',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings),
                    label: 'Cài đặt',
                  ),
                ],
              ),
      ),
    );
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
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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
            return _dungTheBaiThi(baiThi, cacLuotThi, userNames);
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
        runSpacing: 12,
        children: [
          for (final card in cards)
            SizedBox(
              width: constraints.maxWidth >= 900
                  ? (constraints.maxWidth - 36) / 4
                  : constraints.maxWidth >= 560
                  ? (constraints.maxWidth - 12) / 2
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
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _hienChiTietBaiThi(baiThi, cacLuotThi, userNames),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                    child: const Icon(Icons.assignment, color: primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      (examData['title'] ?? 'Bài kiểm tra').toString(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _dungChiSoBaiThi('Người đã làm', '${cacNguoiDung.length}'),
                  _dungChiSoBaiThi('Tổng lượt làm', '$totalAttemptCount'),
                  _dungChiSoBaiThi('Điểm tốt TB', average.toStringAsFixed(1)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dungChiSoBaiThi(String nhan, String giaTri) {
    return Column(
      children: [
        Text(
          giaTri,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(nhan, style: const TextStyle(color: Colors.grey, fontSize: 11)),
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
      margin: const EdgeInsets.only(bottom: 10),
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

  Widget _dungThongBaoLoi(String thongDiep, Object? loi) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('$thongDiep\n$loi', textAlign: TextAlign.center),
      ),
    );
  }
}
