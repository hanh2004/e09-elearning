// APP HỌC VIÊN: Thư viện khóa học và bài học dành cho học viên.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../widgets/anh_bia_khoa_hoc.dart';
import '../../models/bieu_mau_khoa_hoc.dart';
import '../../models/bieu_mau_bai_hoc.dart';
import '../../widgets/dau_trang_hoc_vien.dart';
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
  late final courses = service.courses(classId: '');
  late final progress = service.db
      .collection('users')
      .doc(widget.uid)
      .collection('learning')
      .snapshots();
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
      builder: (cacBanGhi) => LearningList(
        stream: progress,
        builder: (cacMauTin) {
          final subjects =
              cacBanGhi
                  .map((d) => (d.data()['subject'] as String? ?? '').trim())
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
          final daLoc = cacBanGhi
              .where(
                (d) =>
                    LearningPolicy.canRead(d.data(), '') &&
                    !CourseForm.hasExam(d.data()) &&
                    (subject == null || d.data()['subject'] == subject) &&
                    '${d.data()['title']} ${d.data()['subject']}'
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
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final s in <String?>[null, ...subjects])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                showCheckmark: false,
                                selectedColor: AppTheme.red,
                                label: Text(
                                  s ?? 'Tất cả',
                                  style: TextStyle(
                                    color: subject == s
                                        ? Colors.white
                                        : AppTheme.navy,
                                  ),
                                ),
                                selected: subject == s,
                                onSelected: (_) => setState(() => subject = s),
                              ),
                            ),
                        ],
                      ),
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
                          final banGhi = daLoc[viTri];
                          return _TheThuVienKhoaHoc(
                            key: ValueKey(banGhi.id),
                            course: banGhi,
                            service: service,
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
  );
}

class _TheThuVienKhoaHoc extends StatefulWidget {
  const _TheThuVienKhoaHoc({
    super.key,
    required this.course,
    required this.service,
    required this.records,
    required this.onTap,
  });
  final LessonDoc course;
  final LearningService service;
  final List<LessonDoc> records;
  final VoidCallback onTap;
  @override
  State<_TheThuVienKhoaHoc> createState() => _TrangThaiTheThuVienKhoaHoc();
}

class _TrangThaiTheThuVienKhoaHoc extends State<_TheThuVienKhoaHoc> {
  late final lessons = widget.service.lessons(widget.course.id);
  @override
  Widget build(BuildContext context) => LearningList(
    stream: lessons,
    builder: (allDocs) {
      final duLieu = widget.course.data();
      final releaseDate = CourseForm.formatReleaseDateTime(
        duLieu['publishedAt'],
      );
      final explicitCourseMode =
          duLieu['learningMode'] == 'study_only' ||
          duLieu['learningMode'] == 'study_exam';
      final cacBanGhi = LearningPolicy.sortLessons(allDocs)
          .where(
            (banGhi) => explicitCourseMode
                ? !CourseForm.hasExam(duLieu)
                : !LessonForm.hasExam(banGhi.data()),
          )
          .toList();
      if (cacBanGhi.isEmpty && allDocs.isNotEmpty) {
        return const SizedBox.shrink();
      }
      final tyLe = LearningPolicy.completion(
        cacBanGhi.map((d) => d.id),
        widget.records
            .where(
              (r) =>
                  r.data()['courseId'] == widget.course.id &&
                  r.data()['completed'] == true,
            )
            .map((r) => r.data()['lessonId'] as String),
      );
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CourseCover(
                  url: duLieu['coverUrl'] ?? '',
                  width: 86,
                  height: 100,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (duLieu['subject'] as String? ?? '').toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.red,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        duLieu['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navy,
                        ),
                      ),
                      if ((duLieu['instructor'] as String? ?? '').isNotEmpty)
                        Text(
                          'Giảng viên: ${duLieu['instructor']}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.blueGrey,
                          ),
                        ),
                      if (releaseDate.isNotEmpty)
                        Text(
                          'Phát hành: $releaseDate',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.blueGrey,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text(
                            cacBanGhi.isEmpty
                                ? 'Chưa có bài học'
                                : '${cacBanGhi.length} bài học',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.blueGrey,
                            ),
                          ),
                          Text(
                            cacBanGhi.isEmpty
                                ? 'Đang cập nhật nội dung'
                                : tyLe == 0
                                ? 'Chưa học'
                                : tyLe == 1
                                ? 'Đã hoàn thành'
                                : 'Đang học (${(tyLe * 100).round()}%)',
                            style: TextStyle(
                              fontSize: 11,
                              color: tyLe > 0
                                  ? Colors.green.shade700
                                  : Colors.blueGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: widget.onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    minimumSize: const Size(0, 38),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Vào học', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Danh sách bài học trong một khóa học để học viên tiếp tục học.
class UserLessonsScreen extends StatefulWidget {
  const UserLessonsScreen({
    super.key,
    required this.uid,
    required this.course,
    this.service,
  });
  final String uid;
  final LessonDoc course;
  final LearningService? service;
  @override
  State<UserLessonsScreen> createState() => _TrangThaiBaiHocHocVien();
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
        bottomNavigationBar: const LearnerNavigation(selectedIndex: 1),
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
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (CourseForm.formatReleaseDateTime(
                          duLieu['publishedAt'],
                        ).isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Phát hành: ${CourseForm.formatReleaseDateTime(duLieu['publishedAt'])}',
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
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => CourseChaptersScreen(
                          uid: widget.uid,
                          course: widget.course,
                          service: service,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('BẮT ĐẦU HỌC NGAY'),
                  ),
                ],
              ),
              CourseChapterList(
                uid: widget.uid,
                course: widget.course,
                service: service,
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
