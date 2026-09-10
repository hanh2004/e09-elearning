import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/admin_report.dart';
import '../../app/app_theme.dart';

import '../../services/firestore_service.dart';
import 'admin_exam_screen.dart';
import 'admin_home_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_responsive_shell.dart';

class AdminReportScreen extends StatefulWidget {
  const AdminReportScreen({super.key, this.service});
  final FirestoreService? service;

  @override
  State<AdminReportScreen> createState() => _AdminReportScreenState();
}

class _AdminReportScreenState extends State<AdminReportScreen> {
  static const _primaryColor = Color(0xFFB51F24);
  late final FirestoreService _firestoreService =
      widget.service ?? FirestoreService();
  late final examStream = _firestoreService.getExamsStream();
  late final attemptStream = _firestoreService.getExamAttemptsStream();
  late final userStream = _firestoreService.getUsersStream();
  final searchController = TextEditingController();
  String? classFilter;
  String? examFilter;
  String? unitFilter;
  int visibleRows = 50;
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  final int _selectedIndex = 2;

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    final pages = <Widget>[
      const AdminHomeScreen(),
      const AdminExamScreen(),
      const AdminReportScreen(),
      const AdminSettingsScreen(),
    ];
    Navigator.pushReplacement(context, adminTabRoute(pages[index]));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AdminResponsiveShell.isDesktop(context);
    return AdminResponsiveShell(
      selectedIndex: _selectedIndex,
      onSelected: _onItemTapped,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          title: const Text(
            'Báo cáo tổng hợp',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: examStream,
          builder: (context, examSnapshot) {
            if (examSnapshot.hasError) {
              return _buildError('Không tải được danh sách bài thi.');
            }
            if (!examSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: attemptStream,
              builder: (context, attemptSnapshot) {
                if (attemptSnapshot.hasError) {
                  return _buildError('Không tải được kết quả làm bài.');
                }
                if (!attemptSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: userStream,
                  builder: (context, userSnapshot) {
                    if (userSnapshot.hasError) {
                      return _buildError(
                        'Không tải được tài khoản người dùng.',
                      );
                    }
                    if (!userSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _buildReport(
                      examSnapshot.data!.docs,
                      attemptSnapshot.data!.docs,
                      userSnapshot.data!.docs,
                    );
                  },
                );
              },
            );
          },
        ),
        bottomNavigationBar: isDesktop
            ? null
            : BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: _primaryColor,
                unselectedItemColor: Colors.grey,
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

  Widget _buildReport(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> exams,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> attempts,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
  ) {
    DateTime? date(Object? value) => value is Timestamp ? value.toDate() : null;
    final userMap = {for (final doc in users) doc.id: doc.data()};
    final examMap = {for (final doc in exams) doc.id: doc.data()};
    const String? selectedClass = null;
    final selectedExam = examMap.containsKey(examFilter) ? examFilter : null;
    final units =
        users
            .map(
              (u) => u.data()['role'] == 'super_admin'
                  ? 'E09'
                  : (u.data()['unit'] ?? '').toString(),
            )
            .toSet()
            .toList()
          ..sort();
    final selectedUnit = units.contains(unitFilter) ? unitFilter : null;
    final report = AdminReport.build(
      users: userMap,
      exams: examMap,
      attempts: attempts
          .map(
            (d) => {
              ...d.data(),
              'reportLastAt': date(
                d.data()['lastAttemptAt'] ?? d.data()['completedAt'],
              ),
              'reportBestAt': date(
                d.data()['bestCompletedAt'] ?? d.data()['completedAt'],
              ),
            },
          )
          .toList(),
      classId: selectedClass,
      examId: selectedExam,
      unit: selectedUnit,
      search: searchController.text,
    );
    final rank = report.ranking;
    final distribution = report.distribution;
    final scored = distribution.fold(0, (total, v) => total + v);
    final sortedExams = exams.toList()
      ..sort(
        (a, b) => '${a.data()['title']}'.compareTo('${b.data()['title']}'),
      );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Tổng quan kết quả học tập',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppTheme.navy,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Theo dõi kết quả theo đơn vị, học viên và bài thi.',
          style: TextStyle(color: Colors.blueGrey),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 700
                    ? (constraints.maxWidth - 24) / 3
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: width,
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
                          for (final unit in units)
                            DropdownMenuItem(
                              value: unit,
                              child: Text(
                                unit.isEmpty ? 'Chưa phân đơn vị' : unit,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() {
                          unitFilter = v;
                          visibleRows = 50;
                        }),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          labelText: 'Tìm học viên hoặc đơn vị',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => setState(() => visibleRows = 50),
                      ),
                    ),
                    SizedBox(
                      width: width,
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
                          for (final doc in sortedExams)
                            DropdownMenuItem(
                              value: doc.id,
                              child: Text(
                                doc.data()['title'] ?? doc.id,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() {
                          examFilter = v;
                          visibleRows = 50;
                        }),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        searchController.clear();
                        classFilter = null;
                        examFilter = null;
                        unitFilter = null;
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
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1050
                ? 6
                : constraints.maxWidth >= 650
                ? 3
                : 2;
            final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric(
                  width,
                  'Bài thi',
                  '${report.examCount}',
                  Icons.quiz_outlined,
                  Colors.blue,
                ),
                _metric(
                  width,
                  'Học viên đã thi',
                  '${report.participants}',
                  Icons.people_outline,
                  AppTheme.navy,
                ),
                _metric(
                  width,
                  'Lượt đã nộp',
                  '${report.attempts}',
                  Icons.assignment_turned_in_outlined,
                  Colors.orange,
                ),
                _metric(
                  width,
                  'Điểm TB tốt nhất',
                  report.average?.toStringAsFixed(2) ?? '—',
                  Icons.trending_up,
                  AppTheme.red,
                ),
                _metric(
                  width,
                  'Tỷ lệ đạt',
                  report.passRate == null
                      ? '—'
                      : '${report.passRate!.toStringAsFixed(1)}%',
                  Icons.check_circle_outline,
                  Colors.green,
                ),
                _metric(
                  width,
                  'Kết quả chưa đạt',
                  '${report.failed}',
                  Icons.pending_actions_outlined,
                  Colors.deepOrange,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          '${report.studentCount} học viên trong phạm vi lọc • ${report.rows.length} kết quả học viên–bài thi.',
          style: const TextStyle(color: Colors.blueGrey),
        ),
        const SizedBox(height: 6),
        const Text(
          'Mỗi học viên được tính một kết quả tốt nhất cho mỗi đề. Tỷ lệ đạt và điểm trung bình tính trên các kết quả này; số lượt đã nộp vẫn tính tất cả lượt.',
          style: TextStyle(fontSize: 12, color: Colors.blueGrey, height: 1.5),
        ),
        if (report.ungraded > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${report.ungraded} kết quả thiếu điểm hợp lệ, chưa tính vào điểm trung bình và tỷ lệ đạt.',
            ),
          ),
        const SizedBox(height: 22),
        _heading('Tiến độ theo đơn vị'),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Đã làm = học viên có ít nhất một lượt đã nộp trong bài thi đang lọc; mỗi người chỉ tính một lần.',
            style: TextStyle(color: Colors.blueGrey, fontSize: 12),
          ),
        ),
        for (final unit in units.where(
          (u) => selectedUnit == null || u == selectedUnit,
        ))
          Builder(
            builder: (context) {
              final members = users
                  .where(
                    (u) =>
                        u.data()['role'] == 'user' &&
                        (u.data()['unit'] ?? '') == unit &&
                        (selectedClass == null ||
                            (u.data()['classId'] ?? '') == selectedClass) &&
                        '${u.id} ${u.data()['name'] ?? ''} ${u.data()['username'] ?? ''} ${u.data()['unit'] ?? ''} ${u.data()['subUnit'] ?? ''} ${u.data()['subUnit'] ?? ''}-${u.data()['unit'] ?? ''}'
                            .toLowerCase()
                            .contains(
                              searchController.text.trim().toLowerCase(),
                            ),
                  )
                  .map((u) => u.id)
                  .toSet();
              final done = report.rows
                  .where((r) => members.contains(r.userId))
                  .map((r) => r.userId)
                  .toSet()
                  .length;
              final adminCount = users
                  .where(
                    (u) =>
                        ['admin', 'super_admin'].contains(u.data()['role']) &&
                        (u.data()['role'] == 'super_admin'
                                ? 'E09'
                                : u.data()['unit'] ?? '') ==
                            unit,
                  )
                  .length;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.apartment, color: AppTheme.red),
                  title: Text(
                    unit.isEmpty ? 'Chưa phân đơn vị' : unit,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '$adminCount quản trị viên • ${members.length} học viên\nĐã làm: $done • Chưa làm: ${members.length - done}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    members.isEmpty
                        ? '—'
                        : '${(done * 100 / members.length).round()}%',
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
                _heading('Phân bố điểm tốt nhất'),
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
        _heading('Kết quả chi tiết (${report.rows.length})'),
        const SizedBox(height: 8),
        if (report.rows.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text('Chưa có kết quả phù hợp với bộ lọc.'),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final rows = report.rows.take(visibleRows).toList();
              if (constraints.maxWidth < 750) {
                return Column(
                  children: [
                    for (final row in rows)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${row.subUnit.isEmpty ? '' : '${row.subUnit}-'}${row.unit}',
                                style: const TextStyle(color: Colors.blueGrey),
                              ),
                              const SizedBox(height: 8),
                              Text(row.examTitle),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text('${row.attempts} lượt'),
                                  Text(
                                    'Điểm: ${row.score?.toStringAsFixed(2) ?? '—'}',
                                  ),
                                  _status(row),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Nộp gần nhất: ${_date(row.submittedAt)}',
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
                      for (final row in rows)
                        DataRow(
                          cells: [
                            DataCell(
                              SizedBox(width: 150, child: Text(row.name)),
                            ),
                            DataCell(
                              SizedBox(
                                width: 130,
                                child: Text(
                                  '${row.subUnit.isEmpty ? '' : '${row.subUnit}-'}${row.unit}',
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(width: 200, child: Text(row.examTitle)),
                            ),
                            DataCell(Text('${row.attempts}')),
                            DataCell(
                              Text(row.score?.toStringAsFixed(2) ?? '—'),
                            ),
                            DataCell(_status(row)),
                            DataCell(Text(_date(row.submittedAt))),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        if (report.rows.length > visibleRows)
          TextButton(
            onPressed: () => setState(() => visibleRows += 50),
            child: const Text('Xem thêm kết quả'),
          ),
        const SizedBox(height: 20),
        _heading('Người dùng có điểm cao nhất'),
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

  Widget _heading(String value) => Text(
    value,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      color: AppTheme.navy,
    ),
  );
  String _date(DateTime? value) => value == null
      ? 'Chưa có thời gian'
      : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  Widget _status(AdminReportRow row) {
    final color = row.passed == null
        ? Colors.blueGrey
        : row.passed!
        ? Colors.green
        : Colors.deepOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        row.passed == null
            ? 'Thiếu điểm'
            : row.passed!
            ? 'Đạt'
            : 'Chưa đạt',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _metric(
    double width,
    String label,
    String value,
    IconData icon,
    Color color,
  ) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _buildError(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
