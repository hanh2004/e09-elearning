import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../models/account_identity.dart';
import '../../models/admin_report.dart';
import 'admin_responsive_shell.dart';
import 'admin_account_screen.dart';
import 'admin_classes_screen.dart';
import 'admin_courses_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_learning_dashboard.dart';
import 'admin_exam_screen.dart';
import 'admin_report_screen.dart';
import 'admin_progress_screen.dart';
import 'admin_settings_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key, this.firestore});
  final FirebaseFirestore? firestore;
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late Future<List<QuerySnapshot<Map<String, dynamic>>>>? data = _load();
  Future<List<QuerySnapshot<Map<String, dynamic>>>>? _load() {
    if (widget.firestore == null && Firebase.apps.isEmpty) return null;
    final db = widget.firestore ?? FirebaseFirestore.instance;
    return Future.wait(
      [
        'users',
        'courses',
        'exams',
        'exam_attempts',
      ].map((c) => db.collection(c).get()),
    );
  }

  void open(Widget page) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  void tab(int index) {
    if (index == 0) return;
    Navigator.pushReplacement(
      context,
      adminTabRoute(
        [
          const SizedBox(),
          const AdminExamScreen(),
          const AdminReportScreen(),
          const AdminSettingsScreen(),
        ][index],
      ),
    );
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
        appBar: AppBar(
          backgroundColor: Colors.white,
          centerTitle: false,
          title: const Text('Trang chủ quản trị'),
          actions: [
            IconButton(
              tooltip: 'Làm mới',
              onPressed: () => setState(() => data = _load()),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Cài đặt và đăng xuất',
              onPressed: () => tab(3),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
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
                        'HỆ THỐNG HỌC TẬP SỐ E09',
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
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: AppTheme.navy,
                    ),
                    onPressed: () => tab(2),
                    icon: const Icon(Icons.bar_chart),
                    label: const Text('Xem báo cáo tổng hợp'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<QuerySnapshot<Map<String, dynamic>>>>(
              future: data,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Card(
                    child: ListTile(
                      title: const Text('Không tải được thống kê'),
                      subtitle: const Text('Bấm làm mới để thử lại.'),
                      trailing: IconButton(
                        onPressed: () => setState(() => data = _load()),
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Đang tải thống kê…')),
                  );
                }
                final docs = snapshot.data!;
                final users = {for (final d in docs[0].docs) d.id: d.data()};
                final report = AdminReport.build(
                  users: users,
                  exams: {for (final d in docs[2].docs) d.id: d.data()},
                  attempts: docs[3].docs.map((d) => d.data()).toList(),
                );
                final students = users.entries
                    .where((u) => u.value['role'] == 'user')
                    .toList();
                final units =
                    students
                        .map((u) => (u.value['unit'] ?? '').toString())
                        .toSet()
                        .toList()
                      ..sort();
                final participants = report.rows.map((r) => r.userId).toSet();
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
                            for (final entry in <(String, String, IconData)>[
                              (
                                'Tổng học viên',
                                '${students.length}',
                                Icons.people_outline,
                              ),
                              (
                                'Khóa học',
                                '${docs[1].docs.length}',
                                Icons.menu_book_outlined,
                              ),
                              (
                                'Lượt thi đã nộp',
                                '${report.attempts}',
                                Icons.assignment_turned_in_outlined,
                              ),
                              (
                                'Điểm TB tốt nhất',
                                report.average?.toStringAsFixed(2) ?? '—',
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
                                        Icon(entry.$3, color: AppTheme.red),
                                        const SizedBox(height: 12),
                                        Text(
                                          entry.$2,
                                          style: const TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(entry.$1),
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
                            if (units.isEmpty) const Text('Chưa có học viên.'),
                            for (final unit in units)
                              Builder(
                                builder: (context) {
                                  final members = students
                                      .where(
                                        (u) => (u.value['unit'] ?? '') == unit,
                                      )
                                      .toList();
                                  final done = members
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
                                                unit.isEmpty
                                                    ? 'Chưa phân đơn vị'
                                                    : unit,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '$done/${members.length} đã làm',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        LinearProgressIndicator(
                                          value: members.isEmpty
                                              ? 0
                                              : done / members.length,
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
                        'Quản lý Tài khoản',
                        'Học viên và phân quyền',
                        Icons.people_outline,
                        const AdminAccountScreen(),
                      ),
                      (
                        'Khóa học và bài học',
                        'Nội dung học tập',
                        Icons.menu_book,
                        const AdminCoursesScreen(),
                      ),
                      (
                        'Quản lý Kiểm tra',
                        'Đề thi và câu hỏi',
                        Icons.assignment_outlined,
                        const AdminExamScreen(),
                      ),
                      (
                        'Đơn vị học viên',
                        'Tra cứu theo đơn vị',
                        Icons.groups_outlined,
                        const AdminClassesScreen(),
                      ),
                      (
                        'Lịch học và lịch thi',
                        'Kế hoạch học tập',
                        Icons.calendar_month,
                        const AdminScheduleScreen(),
                      ),
                      (
                        'Thông báo',
                        'Thông tin trong hệ thống',
                        Icons.notifications_outlined,
                        const AdminNotificationsScreen(),
                      ),
                      (
                        'Tổng quan học tập',
                        'Chi tiết hoàn thành bài học',
                        Icons.dashboard_outlined,
                        const AdminLearningDashboard(),
                      ),
                      (
                        'Theo dõi Tiến độ',
                        'Học viên và lượt làm bài',
                        Icons.show_chart,
                        const AdminProgressScreen(),
                      ),
                      (
                        'Báo cáo Tổng hợp',
                        'Kết quả theo đơn vị',
                        Icons.bar_chart,
                        const AdminReportScreen(),
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
        bottomNavigationBar: AdminResponsiveShell.isDesktop(context)
            ? null
            : BottomNavigationBar(
                currentIndex: 0,
                onTap: tab,
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: 'Trang chủ',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.assignment),
                    label: 'Bài thi',
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
}
