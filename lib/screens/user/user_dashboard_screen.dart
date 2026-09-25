// APP HỌC VIÊN: Trang tổng quan học viên: tiến độ và khóa học đang học.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import '../../widgets/learner_metrics.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/course_cover.dart';

import '../../app/app_theme.dart';
import '../../models/user_arguments.dart';
import '../../services/nghiep_vu/learning_service.dart';
import '../../widgets/learning_widgets.dart';
import 'user_courses_screen.dart';
import 'user_news.dart';
import '../../widgets/home_news_banner.dart';
import '../../services/nghiep_vu/news_service.dart';

/// Trang tổng quan học viên: tiến độ và khóa học đang học.
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
  State<UserDashboardScreen> createState() => _TrangThaiTongQuanHocVien();
}

class _TrangThaiTongQuanHocVien extends State<UserDashboardScreen> {
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
            builder: (context, duLieuNhan) {
              if (duLieuNhan.hasError) {
                return const Center(
                  child: Text('Không tải được hồ sơ học tập.'),
                );
              }
              if (!duLieuNhan.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final nguoiDung = duLieuNhan.data!.data() ?? {};
              return LearningList(
                stream: service.courses(
                  classId: nguoiDung['classId'] as String? ?? '',
                ),
                builder: (cacKhoaHoc) => ListView(
                  padding: EdgeInsets.all(
                    MediaQuery.sizeOf(context).width < 360 ? 16 : 20,
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.red,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Image.asset(AppTheme.logo, width: 48, height: 48),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'HỌC TẬP SỐ E09',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  nguoiDung['name'] as String? ??
                                      widget.args.userName,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Thông báo',
                            onPressed: () => widget.onSelect(3),
                            icon: const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    HomeNewsBanner(
                      service: NewsService(service.db),
                      uid: widget.args.userId,
                      onStudy: () => widget.onSelect(1),
                    ),
                    const SizedBox(height: 20),
                    UserNews(
                      service: service,
                      uid: widget.args.userId,
                      onViewAll: () => widget.onSelect(5),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Tiến độ học tập',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LearningList(
                      stream: learning,
                      builder: (cacMauTin) => LearnerMetrics(
                        children: [
                          _thongKe(
                            '${cacKhoaHoc.length}',
                            'Khóa học',
                            Icons.menu_book_outlined,
                          ),
                          _thongKe(
                            '${cacMauTin.where((r) => r.data()['completed'] == true).length}',
                            'Bài đã học',
                            Icons.check_circle_outline,
                          ),
                        ],
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
                    if (cacKhoaHoc.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Khóa học được phân cho bạn sẽ xuất hiện tại đây.',
                          ),
                        ),
                      ),
                    for (final khoaHoc in cacKhoaHoc.take(4))
                      Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CourseCover(
                            url: khoaHoc.data()['coverUrl'] ?? '',
                            width: 56,
                            height: 56,
                          ),
                          title: Text(
                            khoaHoc.data()['title'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(khoaHoc.data()['subject'] ?? ''),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => UserLessonsScreen(
                                uid: widget.args.userId,
                                course: khoaHoc,
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

  Widget _thongKe(String giaTri, String nhan, IconData bieuTuong) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      child: Column(
        children: [
          Icon(bieuTuong, color: AppTheme.red, size: 20),
          const SizedBox(height: 10),
          Text(
            giaTri,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            nhan,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
        ],
      ),
    ),
  );
}
