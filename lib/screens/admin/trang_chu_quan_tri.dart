// WEB ADMIN: Trang tổng quan quản trị với các chỉ số học tập và lối tắt báo cáo.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../models/quy_tac_hoc_tap.dart';
import '../../widgets/giao_dien_quan_tri.dart';
import '../../models/dinh_danh_tai_khoan.dart';
import '../../models/bao_cao_quan_tri.dart';
import '../../services/thong_bao_loi_ung_dung.dart';
import 'khung_giao_dien_quan_tri.dart';
import 'quan_ly_tai_khoan.dart';
import 'quan_ly_khoa_hoc.dart';
import 'quan_ly_thong_bao.dart';
import 'quan_ly_tin_tuc.dart';
import 'bao_cao_hub.dart';

/// Trang tổng quan quản trị với các chỉ số học tập và lối tắt báo cáo.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key, this.firestore});
  final FirebaseFirestore? firestore;
  @override
  State<AdminHomeScreen> createState() => _TrangThaiTrangChuQuanTri();
}

class _TrangThaiTrangChuQuanTri extends State<AdminHomeScreen> {
  late Future<List<QuerySnapshot<Map<String, dynamic>>>>? data = _taiDuLieu();
  Future<List<QuerySnapshot<Map<String, dynamic>>>>? _taiDuLieu() {
    if (widget.firestore == null && Firebase.apps.isEmpty) return null;
    final db = widget.firestore ?? FirebaseFirestore.instance;
    return Future.wait(
      ['users', 'courses', 'exams', 'exam_attempts'].map(
        (c) => db.collection(c).get(const GetOptions(source: Source.server)),
      ),
    );
  }

  void open(Widget page) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  void tab(int viTri) {
    if (viTri == 0) return;
    pushAdminPrimary(context, viTri);
  }

  @override
  Widget build(BuildContext context) {
    if (AccountSession.current?.isAdmin != true) {
      return const Scaffold(
        body: Center(child: Text('Cần đăng nhập quản trị.')),
      );
    }
    return AdminResponsiveShell(
      selectedIndex: 0,
      onSelected: tab,
      child: Scaffold(
        appBar: AdminUi.appBar('Trang chủ quản trị'),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [AppTheme.red, Color(0xFF79121C)],
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 20,
                runSpacing: 16,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CẢNH SÁT CƠ ĐỘNG • HỌC TẬP SỐ E09',
                        style: TextStyle(
                          color: AppTheme.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tổng quan học tập',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Theo dõi học viên, đơn vị và kết quả kiểm tra.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                        ),
                        onPressed: () => setState(() => data = _taiDuLieu()),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Làm mới'),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: AppTheme.navy,
                        ),
                        onPressed: () => tab(2),
                        icon: const Icon(Icons.bar_chart),
                        label: const Text('Mở báo cáo'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<QuerySnapshot<Map<String, dynamic>>>>(
              future: data,
              builder: (context, duLieuNhan) {
                if (duLieuNhan.hasError) {
                  return Card(
                    child: ListTile(
                      title: Text(
                        AppErrorMessage.from(
                          duLieuNhan.error!,
                          feature: 'Tải thống kê trang chủ Admin',
                          fallbackAction: 'Kiểm tra quyền quản trị, kết nối và cấu hình máy chủ.',
                        ),
                      ),
                      subtitle: const Text('Bấm làm mới để thử lại.'),
                      trailing: IconButton(
                        onPressed: () => setState(() => data = _taiDuLieu()),
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                  );
                }
                if (!duLieuNhan.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Đang tải thống kê…')),
                  );
                }
                final cacBanGhi = duLieuNhan.data!;
                final cacNguoiDung = {
                  for (final d in cacBanGhi[0].docs) d.id: d.data(),
                };
                final visibility = LearningContentVisibility.fromDocuments(
                  courses: cacBanGhi[1].docs,
                  exams: cacBanGhi[2].docs,
                );
                final launchedCourses = cacBanGhi[1].docs
                    .where(visibility.includesCourse)
                    .toList();
                final launchedExams = cacBanGhi[2].docs
                    .where(visibility.includesExam)
                    .toList();
                final launchedAttempts = cacBanGhi[3].docs
                    .where(visibility.includesAttempt)
                    .toList();
                final baoCao = AdminReport.build(
                  users: cacNguoiDung,
                  exams: {for (final d in launchedExams) d.id: d.data()},
                  attempts: launchedAttempts.map((d) => d.data()).toList(),
                );
                final cacHocVien = cacNguoiDung.entries
                    .where((u) => u.value['role'] == 'user')
                    .toList();
                final cacDonVi =
                    cacHocVien
                        .map((u) => (u.value['unit'] ?? '').toString())
                        .toSet()
                        .toList()
                      ..sort();
                final participants = baoCao.rows.map((r) => r.userId).toSet();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, c) {
                        final columns = c.maxWidth > 900 ? 4 : 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final capDuLieu
                                in <(String, String, IconData)>[
                                  (
                                    'Tổng học viên',
                                    '${cacHocVien.length}',
                                    Icons.people_outline,
                                  ),
                                  (
                                    'Khóa học',
                                    '${launchedCourses.length}',
                                    Icons.menu_book_outlined,
                                  ),
                                  (
                                    'Lượt thi đã nộp',
                                    '${baoCao.attempts}',
                                    Icons.assignment_turned_in_outlined,
                                  ),
                                  (
                                    'Điểm TB tốt nhất',
                                    baoCao.average?.toStringAsFixed(2) ?? '—',
                                    Icons.insights,
                                  ),
                                ])
                              SizedBox(
                                width:
                                    (c.maxWidth - 12 * (columns - 1)) / columns,
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(capDuLieu.$3, color: AppTheme.red),
                                        const SizedBox(height: 12),
                                        Text(
                                          capDuLieu.$2,
                                          style: const TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(capDuLieu.$1),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
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
                            const Text(
                              'Tình hình tham gia theo đơn vị',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Số học viên đã nộp ít nhất một bài kiểm tra.',
                            ),
                            const SizedBox(height: 16),
                            if (cacDonVi.isEmpty)
                              const Text('Chưa có học viên.'),
                            for (final donVi in cacDonVi)
                              Builder(
                                builder: (context) {
                                  final thanhVien = cacHocVien
                                      .where(
                                        (u) => (u.value['unit'] ?? '') == donVi,
                                      )
                                      .toList();
                                  final daXong = thanhVien
                                      .where(
                                        (u) => participants.contains(u.key),
                                      )
                                      .length;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                donVi.isEmpty
                                                    ? 'Chưa phân đơn vị'
                                                    : donVi,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '$daXong/${thanhVien.length} đã làm',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        LinearProgressIndicator(
                                          value: thanhVien.isEmpty
                                              ? 0
                                              : daXong / thanhVien.length,
                                          minHeight: 7,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Quản lý và tra cứu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, c) {
                final columns = c.maxWidth > 900
                    ? 3
                    : c.maxWidth > 550
                    ? 2
                    : 1;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final e in <(String, String, IconData, Widget)>[
                      (
                        'Tin tức',
                        'Bài viết và nội dung đã đăng',
                        Icons.newspaper_outlined,
                        const AdminNewsScreen(),
                      ),
                      (
                        'Thông báo',
                        'Gửi thông báo cho học viên',
                        Icons.notifications_outlined,
                        const AdminNotificationsScreen(),
                      ),
                      (
                        'Quản lý Tài khoản',
                        'Học viên và phân quyền',
                        Icons.people_outline,
                        const AdminAccountScreen(),
                      ),
                      (
                        'Khóa học không kiểm tra',
                        'Nội dung học tập không có bài kiểm tra',
                        Icons.menu_book,
                        const AdminCoursesScreen(
                          initialCourseModeFilter: 'study_only',
                        ),
                      ),
                      (
                        'Khóa học có kiểm tra',
                        'Nội dung học tập kèm bài kiểm tra',
                        Icons.assignment_outlined,
                        const AdminCoursesScreen(
                          initialCourseModeFilter: 'study_exam',
                        ),
                      ),
                      (
                        'Báo cáo',
                        'Tiến độ học tập, lượt thi và kết quả',
                        Icons.bar_chart,
                        const AdminReportsHubScreen(),
                      ),
                    ])
                      SizedBox(
                        width: (c.maxWidth - 12 * (columns - 1)) / columns,
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Icon(e.$3, color: AppTheme.red),
                            title: Text(
                              e.$1,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(e.$2),
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () => open(e.$4),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        bottomNavigationBar: adminMobileNavigationBar(
          context,
          selectedIndex: 0,
          onSelected: tab,
        ),
      ),
    );
  }
}
