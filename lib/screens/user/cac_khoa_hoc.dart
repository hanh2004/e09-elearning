// APP HỌC VIÊN: Thư viện khóa học và bài học dành cho học viên.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../services/ket_noi_api/dich_vu_bai_kiem_tra_bao_mat.dart';
import '../../widgets/anh_bia_khoa_hoc.dart';
import '../../models/bieu_mau_khoa_hoc.dart';
import '../../models/bieu_mau_bai_hoc.dart';
import '../../widgets/dau_trang_hoc_vien.dart';
import '../../widgets/danh_muc_khoa_hoc_hoc_vien.dart';
import '../../widgets/the_khoa_hoc_hoc_vien.dart';
import '../../widgets/tien_ich_giao_dien_hoc_tap.dart';
import '../../widgets/dieu_huong_hoc_vien.dart';
import 'doc_bai_hoc.dart';

part 'cac_bai_hoc_trong_khoa.dart';

typedef LessonDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

/// Thư viện khóa học và bài học dành cho học viên.
class UserCoursesScreen extends StatefulWidget {
  const UserCoursesScreen({super.key, required this.uid, this.service});
  final LearningService? service;
  final String uid;
  @override
  State<UserCoursesScreen> createState() => _TrangThaiKhoaHocHocVien();
}

class _TrangThaiKhoaHocHocVien extends State<UserCoursesScreen> {
  late final service = widget.service ?? LearningService();
  late final Timer _refreshTimer;
  late final courses = service.courses(publishedOnly: true);
  late final progress = service.watchQuery(
    service.db.collection('users').doc(widget.uid).collection('learning'),
  );
  String search = '';
  String? subject;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: LearnerHeader(title: const Text('Thư viện học tập')),
    body: LearningList(
      stream: courses,
      errorTitle: 'Tải thư viện khóa học',
      builder: (cacBanGhi) => LearnerCourseCatalog(
        courses: cacBanGhi
            .where((course) => LearningPolicy.canRead(course.data()))
            .toList(),
        service: service,
        builder: (entries) => LearningList(
          stream: progress,
          errorTitle: 'Tải tiến độ học tập',
          builder: (cacMauTin) {
            final studyEntries = entries
                .where((entry) => !entry.hasExam)
                .toList();
            final subjects =
                studyEntries
                    .map(
                      (entry) =>
                          (entry.course.data()['subject'] as String? ?? '')
                              .trim(),
                    )
                    .where((value) => value.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();
            final daLoc = studyEntries
                .where(
                  (entry) =>
                      (subject == null ||
                          (entry.course.data()['subject'] as String? ?? '')
                                  .trim() ==
                              subject) &&
                      '${entry.course.data()['title']} ${entry.course.data()['subject']}'
                          .toLowerCase()
                          .contains(search),
                )
                .toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Tìm bài học, nghiệp vụ…',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) =>
                            setState(() => search = v.toLowerCase()),
                      ),
                      const SizedBox(height: 12),
                      LearnerSubjectFilter(
                        subjects: subjects,
                        selected: subject,
                        onSelected: (value) => setState(() => subject = value),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: daLoc.isEmpty
                      ? const Center(child: Text('Chưa có khóa học phù hợp.'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: daLoc.length,
                          itemBuilder: (context, viTri) {
                            final entry = daLoc[viTri];
                            final banGhi = entry.course;
                            return _TheThuVienKhoaHoc(
                              key: ValueKey(banGhi.id),
                              course: banGhi,
                              lessons: entry.lessons,
                              records: cacMauTin,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => UserLessonsScreen(
                                    uid: widget.uid,
                                    course: banGhi,
                                    service: service,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _TheThuVienKhoaHoc extends StatelessWidget {
  const _TheThuVienKhoaHoc({
    super.key,
    required this.course,
    required this.lessons,
    required this.records,
    required this.onTap,
  });
  final LessonDoc course;
  final List<LessonDoc> lessons;
  final List<LessonDoc> records;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final duLieu = course.data();
    final tyLe = LearningPolicy.completion(
      lessons.map((d) => d.id),
      records
          .where(
            (r) =>
                r.data()['courseId'] == course.id &&
                r.data()['completed'] == true,
          )
          .map((r) => r.data()['lessonId'] as String),
    );
    return LearnerCourseCard(
      courseData: duLieu,
      lessonCount: lessons.length,
      status: lessons.isEmpty
          ? 'Đang cập nhật nội dung'
          : tyLe == 0
          ? 'Chưa học'
          : tyLe == 1
          ? 'Đã hoàn thành'
          : 'Đang học (${(tyLe * 100).round()}%)',
      statusColor: tyLe > 0 ? Colors.green.shade700 : Colors.blueGrey,
      onTap: onTap,
      trailing: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          minimumSize: const Size(0, 38),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('Vào học', style: TextStyle(fontSize: 12)),
      ),
    );
  }
}

/// Danh sách bài học trong một khóa học để học viên tiếp tục học.
class UserLessonsScreen extends StatefulWidget {
  const UserLessonsScreen({
    super.key,
    required this.uid,
    required this.course,
    this.service,
    this.examService,
    this.testMode = false,
  });
  final String uid;
  final LessonDoc course;
  final LearningService? service;
  final SecureExamService? examService;
  final bool testMode;
  @override
  State<UserLessonsScreen> createState() => _TrangThaiBaiHocHocVien();
}

/// Chi tiết khóa học được mở từ mục Kiểm tra, dùng cùng bố cục nhưng giữ đúng
/// ngữ cảnh điều hướng và hiển thị cả bài học của khóa có bài kiểm tra.
class TestCourseDetailsScreen extends UserLessonsScreen {
  const TestCourseDetailsScreen({
    super.key,
    required super.uid,
    required super.course,
    super.service,
    super.examService,
  }) : super(testMode: true);
}

class _TrangThaiBaiHocHocVien extends State<UserLessonsScreen> {
  late final service = widget.service ?? LearningService();
  @override
  Widget build(BuildContext context) {
    final duLieu = widget.course.data();
    final objectives = (duLieu['objectives'] as String? ?? '')
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        bottomNavigationBar: LearnerNavigation(
          selectedIndex: widget.testMode ? 2 : 1,
        ),
        appBar: LearnerHeader(
          backgroundColor: AppTheme.red,
          title: const Text('Chi tiết khóa học'),
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, inner) => [
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  CourseCover(
                    url: duLieu['coverUrl'] ?? '',
                    width: double.infinity,
                    height: 190,
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.red.withValues(alpha: .35),
                            AppTheme.red.withValues(alpha: .95),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          duLieu['subject'] ?? 'Khóa học',
                          style: const TextStyle(
                            color: AppTheme.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          duLieu['title'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (CourseForm.formatReleaseDateTime(
                          duLieu['publishedAt'],
                        ).isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            CourseForm.formatReleaseDateTime(
                              duLieu['publishedAt'],
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if ((duLieu['instructor'] as String? ?? '').isNotEmpty)
              SliverToBoxAdapter(
                child: Card(
                  margin: const EdgeInsets.all(16),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(
                      duLieu['instructor']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: const Text('Giảng viên phụ trách'),
                  ),
                ),
              ),
            SliverPersistentHeader(pinned: true, delegate: _CacTabKhoaHoc()),
          ],
          body: TabBarView(
            children: [
              ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Mục tiêu huấn luyện',
                    style: TextStyle(
                      color: AppTheme.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (objectives.isEmpty)
                    Text(
                      duLieu['description'] ??
                          'Nội dung khóa học được cập nhật bởi đơn vị.',
                    ),
                  for (final goal in objectives)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(goal.trim())),
                        ],
                      ),
                    ),
                  if (objectives.isNotEmpty &&
                      (duLieu['description'] as String? ?? '').isNotEmpty)
                    Text(duLieu['description']),
                  const SizedBox(height: 20),
                  Builder(
                    builder: (tabContext) => FilledButton.icon(
                      onPressed: widget.testMode
                          ? () =>
                                DefaultTabController.of(tabContext).animateTo(1)
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => CourseChaptersScreen(
                                  uid: widget.uid,
                                  course: widget.course,
                                  service: service,
                                  examService: widget.examService,
                                ),
                              ),
                            ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('BẮT ĐẦU HỌC NGAY'),
                    ),
                  ),
                ],
              ),
              CourseChapterList(
                uid: widget.uid,
                course: widget.course,
                service: service,
                examService: widget.examService,
                includeExamLessons: widget.testMode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CacTabKhoaHoc extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => const ColoredBox(
    color: Color(0xFFF7F8FA),
    child: TabBar(
      labelColor: AppTheme.red,
      unselectedLabelColor: AppTheme.navy,
      indicatorColor: AppTheme.red,
      tabs: [
        Tab(text: 'Tổng quan'),
        Tab(text: 'Bài học'),
      ],
    ),
  );
  @override
  bool shouldRebuild(covariant _CacTabKhoaHoc oldDelegate) => false;
}
