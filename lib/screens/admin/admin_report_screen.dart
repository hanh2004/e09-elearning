import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
import 'admin_exam_screen.dart';
import 'admin_home_screen.dart';
import 'admin_settings_screen.dart';

class AdminReportScreen extends StatefulWidget {
  const AdminReportScreen({super.key});

  @override
  State<AdminReportScreen> createState() => _AdminReportScreenState();
}

class _AdminReportScreenState extends State<AdminReportScreen> {
  static const _primaryColor = Color(0xFF6B0000);
  final FirestoreService _firestoreService = FirestoreService();
  final int _selectedIndex = 2;

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    final pages = <Widget>[
      const AdminHomeScreen(),
      const AdminExamScreen(),
      const AdminReportScreen(),
      const AdminSettingsScreen(),
    ];
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => pages[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        stream: _firestoreService.getExamsStream(),
        builder: (context, examSnapshot) {
          if (examSnapshot.hasError) {
            return _buildError('Không tải được danh sách bài thi.');
          }
          if (!examSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestoreService.getExamAttemptsStream(),
            builder: (context, attemptSnapshot) {
              if (attemptSnapshot.hasError) {
                return _buildError('Không tải được kết quả làm bài.');
              }
              if (!attemptSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestoreService.getUsersStream(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.hasError) {
                    return _buildError('Không tải được tài khoản người dùng.');
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Bài thi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Báo cáo',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Cài đặt'),
        ],
      ),
    );
  }

  Widget _buildReport(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> exams,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> attempts,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
  ) {
    final completed = attempts
        .where((doc) => _attemptCount(doc.data()) > 0)
        .toList();
    final totalAttempts = completed.fold<int>(
      0,
      (total, doc) => total + _attemptCount(doc.data()),
    );
    final passedRecords = completed
        .where((doc) => _bestScore(doc.data()) >= 5)
        .length;
    final passRate = completed.isEmpty
        ? 0.0
        : passedRecords * 100 / completed.length;

    final names = <String, String>{
      for (final user in users)
        user.id:
            (user.data()['name'] ?? user.data()['username'] ?? 'Người dùng')
                .toString(),
    };
    final bestByUser = <String, double>{};
    for (final attempt in completed) {
      final data = attempt.data();
      final userId = data['userId']?.toString();
      if (userId == null || userId.isEmpty) continue;
      final score = _bestScore(data);
      if (score > (bestByUser[userId] ?? -1)) {
        bestByUser[userId] = score;
      }
    }
    final ranking = bestByUser.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Bài thi',
                value: '${exams.length}',
                icon: Icons.quiz_outlined,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                title: 'Lượt đã nộp',
                value: '$totalAttempts',
                icon: Icons.assignment_turned_in_outlined,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                title: 'Tỷ lệ đạt',
                value: '${passRate.toStringAsFixed(1)}%',
                icon: Icons.check_circle_outline,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Người dùng có điểm cao nhất',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (ranking.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Chưa có kết quả đã nộp.')),
            ),
          )
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < ranking.length && index < 10;
                  index++
                ) ...[
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _primaryColor.withValues(alpha: 0.1),
                      child: Text(
                        '#${index + 1}',
                        style: const TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      names[ranking[index].key] ?? ranking[index].key,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Điểm tốt nhất'),
                    trailing: Text(
                      ranking[index].value.toStringAsFixed(1),
                      style: const TextStyle(
                        color: _primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (index < ranking.length - 1 && index < 9)
                    Divider(height: 1, color: Colors.grey[200]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  int _attemptCount(Map<String, dynamic> data) {
    return (data['attemptCount'] as num?)?.toInt() ??
        (data['status'] == 'completed' ? 1 : 0);
  }

  double _bestScore(Map<String, dynamic> data) {
    return (data['bestScore'] as num?)?.toDouble() ??
        (data['diemSo'] as num?)?.toDouble() ??
        0;
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
