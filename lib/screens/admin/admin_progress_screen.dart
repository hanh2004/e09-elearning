import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_exam_screen.dart';
import 'admin_home_screen.dart';
import 'admin_report_screen.dart';
import 'admin_settings_screen.dart';
import '../../services/firestore_service.dart';
import 'admin_responsive_shell.dart';

class AdminProgressScreen extends StatefulWidget {
  const AdminProgressScreen({super.key});

  @override
  State<AdminProgressScreen> createState() => _AdminProgressScreenState();
}

class _AdminProgressScreenState extends State<AdminProgressScreen> {
  static const primaryColor = Color(0xFF6B0000);
  final FirestoreService _firestoreService = FirestoreService();

  void _onNavigationTap(int index) {
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
      selectedIndex: 2,
      onSelected: _onNavigationTap,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          title: const Text(
            'Theo dõi bài thi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestoreService.getExamsStream(),
          builder: (context, examSnapshot) {
            if (examSnapshot.hasError) {
              return _buildError('Không tải được bài thi', examSnapshot.error);
            }
            if (!examSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestoreService.getExamAttemptsStream(),
              builder: (context, attemptSnapshot) {
                if (attemptSnapshot.hasError) {
                  return _buildError(
                    'Không tải được lượt làm bài',
                    attemptSnapshot.error,
                  );
                }
                if (!attemptSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestoreService.getUsersStream(),
                  builder: (context, userSnapshot) {
                    final userNames = <String, String>{};
                    for (final user in userSnapshot.data?.docs ?? const []) {
                      final data = user.data();
                      userNames[user.id] =
                          (data['name'] ?? data['username'] ?? user.id)
                              .toString();
                    }
                    return _buildContent(
                      examSnapshot.data!.docs,
                      attemptSnapshot.data!.docs,
                      userNames,
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
                currentIndex: 2,
                onTap: _onNavigationTap,
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

  Widget _buildContent(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> exams,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allAttempts,
    Map<String, String> userNames,
  ) {
    final resultRecords = allAttempts
        .where((attempt) => _attemptCount(attempt) > 0)
        .toList();
    final inProgressCount = allAttempts
        .where((attempt) => attempt.data()['status'] == 'in_progress')
        .length;
    final completedUsers = resultRecords
        .map((attempt) => attempt.data()['userId']?.toString())
        .whereType<String>()
        .toSet();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildOverview(
          examCount: exams.length,
          completedUserCount: completedUsers.length,
          attemptCount: resultRecords.fold(
            0,
            (total, attempt) => total + _attemptCount(attempt),
          ),
          inProgressCount: inProgressCount,
        ),
        const SizedBox(height: 24),
        const Text(
          'Kết quả theo bài thi',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (exams.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Chưa có bài thi nào.')),
          )
        else
          ...exams.map((exam) {
            final attempts = resultRecords
                .where((attempt) => attempt.data()['examId'] == exam.id)
                .toList();
            return _buildExamCard(exam, attempts, userNames);
          }),
      ],
    );
  }

  Widget _buildOverview({
    required int examCount,
    required int completedUserCount,
    required int attemptCount,
    required int inProgressCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tổng quan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSummaryItem('Bài thi', examCount, Icons.quiz_outlined),
              _buildSummaryItem(
                'Người đã làm',
                completedUserCount,
                Icons.people_outline,
              ),
              _buildSummaryItem('Lượt đã nộp', attemptCount, Icons.task_alt),
              _buildSummaryItem(
                'Đang làm',
                inProgressCount,
                Icons.timer_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: primaryColor),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(
    QueryDocumentSnapshot<Map<String, dynamic>> exam,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> attempts,
    Map<String, String> userNames,
  ) {
    final examData = exam.data();
    final users = attempts
        .map((attempt) => attempt.data()['userId']?.toString())
        .whereType<String>()
        .toSet();
    final bestScores = _groupAttemptsByUser(attempts).values
        .map(_bestScore)
        .toList();
    final average = bestScores.isEmpty
        ? 0.0
        : bestScores.reduce((a, b) => a + b) / bestScores.length;
    final totalAttemptCount = attempts.fold(
      0,
      (total, attempt) => total + _attemptCount(attempt),
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
        onTap: () => _showExamDetails(exam, attempts, userNames),
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
                  _buildExamMetric('Người đã làm', '${users.length}'),
                  _buildExamMetric('Tổng lượt làm', '$totalAttemptCount'),
                  _buildExamMetric('Điểm tốt TB', average.toStringAsFixed(1)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _groupAttemptsByUser(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> attempts,
  ) {
    final grouped =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final attempt in attempts) {
      final userId = attempt.data()['userId']?.toString() ?? 'unknown';
      grouped.putIfAbsent(userId, () => []).add(attempt);
    }
    return grouped;
  }

  double _bestScore(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> attempts,
  ) {
    var best = 0.0;
    for (final attempt in attempts) {
      final data = attempt.data();
      final score =
          (data['bestScore'] as num?)?.toDouble() ??
          (data['diemSo'] as num?)?.toDouble() ??
          0;
      if (score > best) best = score;
    }
    return best;
  }

  int _attemptCount(QueryDocumentSnapshot<Map<String, dynamic>> attempt) {
    final data = attempt.data();
    return (data['attemptCount'] as num?)?.toInt() ??
        (data['status'] == 'completed' ? 1 : 0);
  }

  void _showExamDetails(
    QueryDocumentSnapshot<Map<String, dynamic>> exam,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> attempts,
    Map<String, String> userNames,
  ) {
    final grouped = _groupAttemptsByUser(attempts);
    final totalAttemptCount = attempts.fold(
      0,
      (total, attempt) => total + _attemptCount(attempt),
    );
    final entries = grouped.entries.toList()
      ..sort((a, b) => _bestScore(b.value).compareTo(_bestScore(a.value)));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, controller) => Column(
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
                          (exam.data()['title'] ?? 'Bài kiểm tra').toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${entries.length} người • $totalAttemptCount lượt làm',
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
              child: entries.isEmpty
                  ? const Center(child: Text('Chưa có học viên nộp bài.'))
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.all(12),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return _buildStudentResult(
                          userNames[entry.key] ?? entry.key,
                          entry.value,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentResult(
    String userName,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> attempts,
  ) {
    final best = _bestScore(attempts);
    final attemptCount = attempts.fold(
      0,
      (total, attempt) => total + _attemptCount(attempt),
    );
    DateTime? bestDate;
    for (final attempt in attempts) {
      final data = attempt.data();
      final date =
          (data['bestCompletedAt'] ?? data['completedAt']) as Timestamp?;
      if (date != null &&
          (bestDate == null || date.toDate().isAfter(bestDate))) {
        bestDate = date.toDate();
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: primaryColor.withValues(alpha: 0.1),
          child: Text(
            userName.isEmpty ? '?' : userName[0].toUpperCase(),
            style: const TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          userName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Đã làm $attemptCount lần • ${_formatDate(bestDate)}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              best.toStringAsFixed(1),
              style: TextStyle(
                color: best >= 5 ? Colors.green : Colors.red,
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chưa có thời gian nộp';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.hour)}:${two(date.minute)} ${two(date.day)}/${two(date.month)}/${date.year}';
  }

  Widget _buildError(String message, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('$message\n$error', textAlign: TextAlign.center),
      ),
    );
  }
}
