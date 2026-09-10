import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../models/user_arguments.dart';
import '../../services/learning_service.dart';
import '../../widgets/learning_widgets.dart';
import 'user_courses_screen.dart';
import 'user_schedule_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({
    super.key,
    required this.args,
    required this.onSelect,
    this.service,
  });
  final UserArguments args;
  final ValueChanged<int> onSelect;
  final LearningService? service;
  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  late final service = widget.service ?? LearningService();
  late final profile = service.db
      .collection('users')
      .doc(widget.args.userId)
      .snapshots();
  late final learning = service.db
      .collection('users')
      .doc(widget.args.userId)
      .collection('learning')
      .snapshots();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: profile,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Không tải được hồ sơ học tập.'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final user = snapshot.data!.data() ?? {};
              return LearningList(
                stream: service.courses(
                  classId: user['classId'] as String? ?? '',
                ),
                builder: (courses) => ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        Image.asset(AppTheme.logo, width: 48, height: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Chào mừng trở lại',
                                style: TextStyle(
                                  color: Colors.blueGrey,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                user['name'] as String? ?? widget.args.userName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Thông báo',
                          onPressed: () => widget.onSelect(3),
                          icon: const Icon(Icons.notifications_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [AppTheme.red, Color(0xFF7E151D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'HỌC TẬP MỖI NGÀY',
                            style: TextStyle(
                              color: AppTheme.gold,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Bồi dưỡng kiến thức.\nVững vàng nghiệp vụ.',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 26,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Tiếp nối hành trình học tập của bạn với tài liệu và bài kiểm tra được cập nhật.',
                            style: TextStyle(
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.red,
                            ),
                            onPressed: () => widget.onSelect(1),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('KHÁM PHÁ KHÓA HỌC'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Hoạt động học tập',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LearningList(
                      stream: learning,
                      builder: (records) => Row(
                        children: [
                          Expanded(
                            child: _stat(
                              '${courses.length}',
                              'Khóa học',
                              Icons.menu_book_outlined,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _stat(
                              '${records.where((r) => r.data()['completed'] == true).length}',
                              'Bài đã học',
                              Icons.check_circle_outline,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _stat(
                              '${records.where((r) => r.data()['favorite'] == true).length}',
                              'Yêu thích',
                              Icons.favorite_outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: const Icon(
                          Icons.calendar_month_outlined,
                          color: AppTheme.red,
                        ),
                        title: const Text(
                          'Lịch học và lịch thi',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text(
                          'Chủ động sắp xếp thời gian học tập',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                UserScheduleScreen(uid: widget.args.userId),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Danh mục học tập',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => widget.onSelect(1),
                          child: const Text('Xem tất cả'),
                        ),
                      ],
                    ),
                    if (courses.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Khóa học được phân cho bạn sẽ xuất hiện tại đây.',
                          ),
                        ),
                      ),
                    for (final course in courses.take(4))
                      Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9ECE7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.auto_stories_outlined,
                              color: AppTheme.red,
                            ),
                          ),
                          title: Text(
                            course.data()['title'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(course.data()['subject'] ?? ''),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => UserLessonsScreen(
                                uid: widget.args.userId,
                                course: course,
                                service: service,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _stat(String value, String label, IconData icon) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 18),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.red, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
        ],
      ),
    ),
  );
}
