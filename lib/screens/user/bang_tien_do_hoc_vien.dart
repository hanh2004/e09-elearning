// APP HỌC VIÊN: Trang tổng quan học viên: tiến độ và khóa học đang học.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'dart:async';

import '../../widgets/thong_ke_hoc_vien.dart';
import '../../widgets/danh_muc_khoa_hoc_hoc_vien.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/anh_bia_khoa_hoc.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../models/bieu_mau_khoa_hoc.dart';
import '../../models/tham_so_nguoi_dung.dart';
import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../widgets/tien_ich_giao_dien_hoc_tap.dart';
import 'cac_khoa_hoc.dart';
import 'tin_tuc_hoc_vien.dart';
import '../../widgets/khung_tin_tuc_trang_chu.dart';
import '../../services/nghiep_vu/dich_vu_tin_tuc.dart';

typedef _DashboardCourse = QueryDocumentSnapshot<Map<String, dynamic>>;
typedef _DashboardLesson = QueryDocumentSnapshot<Map<String, dynamic>>;

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
  late final Timer _refreshTimer;
  late final courses = service.courses(publishedOnly: true);
  late final learning = service.watchQuery(
    service.db
        .collection('users')
        .doc(widget.args.userId)
        .collection('learning'),
  );
  late final examAttempts = service.watchQuery(
    service.db
        .collection('exam_attempts')
        .where('userId', isEqualTo: widget.args.userId),
  );
  bool _isExamCourse(_DashboardCourse course, List<_DashboardLesson> lessons) =>
      LearningPolicy.isExamCourse(
        course.data(),
        lessons.map((lesson) => lesson.data()),
      );

  DateTime _publishedAt(_DashboardCourse course) =>
      LearningPolicy.readDateTime(course.data()['publishedAt']) ??
      DateTime.fromMillisecondsSinceEpoch(0);

  List<_DashboardCourse> _latestCourses(
    List<_DashboardCourse> courses,
    List<List<_DashboardLesson>> lessons, {
    required bool exams,
  }) {
    final matching = [
      for (var index = 0; index < courses.length; index++)
        if (_isExamCourse(courses[index], lessons[index]) == exams)
          courses[index],
    ]..sort((a, b) => _publishedAt(b).compareTo(_publishedAt(a)));
    return matching.take(2).toList();
  }

  Widget _courseSection(
    BuildContext context, {
    required String title,
    required List<_DashboardCourse> courses,
    required bool exams,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      if (courses.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Chưa có khóa học.'),
        )
      else
        for (final course in courses)
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CourseCover(
                url: course.data()['coverUrl'] ?? '',
                width: 56,
                height: 56,
              ),
              title: Text(
                course.data()['title'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                CourseForm.formatReleaseDateTime(course.data()['publishedAt']),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => exams
                      ? TestCourseDetailsScreen(
                          uid: widget.args.userId,
                          course: course,
                          service: service,
                        )
                      : UserLessonsScreen(
                          uid: widget.args.userId,
                          course: course,
                          service: service,
                        ),
                ),
              ),
            ),
          ),
      const SizedBox(height: 8),
    ],
  );

  ({int completedCourses, int completedExercises, int totalExercises})
  _progressCounts({
    required List<_DashboardCourse> courses,
    required List<List<_DashboardLesson>> lessons,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> records,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> attempts,
  }) {
    final recordByLesson = <String, Map<String, dynamic>>{};
    for (final record in records) {
      final data = record.data();
      final courseId = data['courseId']?.toString();
      final lessonId = data['lessonId']?.toString();
      if (courseId != null && lessonId != null) {
        recordByLesson['$courseId|$lessonId'] = data;
      }
    }

    var completedCourses = 0;
    final exerciseIds = <String>{};
    for (var index = 0; index < courses.length; index++) {
      final course = courses[index];
      final courseData = course.data();
      final courseLessons = lessons[index];
      if (courseLessons.isNotEmpty &&
          courseLessons.every((lesson) {
            final progress = recordByLesson['${course.id}|${lesson.id}'];
            return progress != null &&
                LearningPolicy.isLessonComplete(
                  progress,
                  courseData,
                  lesson.data(),
                );
          })) {
        completedCourses++;
      }

      final mode = courseData['learningMode'];
      if (mode == 'study_only') continue;
      final courseExamId = (courseData['examId'] ?? '').toString().trim();
      final lessonExamIds = courseLessons
          .where(
            (lesson) => LearningPolicy.requiresExam(courseData, lesson.data()),
          )
          .map(
            (lesson) =>
                (lesson.data()['examId'] ?? courseExamId).toString().trim(),
          )
          .where((examId) => examId.isNotEmpty)
          .toSet();
      if (CourseForm.hasExam(courseData) && courseExamId.isNotEmpty) {
        exerciseIds.add('${course.id}|$courseExamId');
      } else {
        exerciseIds.addAll(
          lessonExamIds.map((examId) => '${course.id}|$examId'),
        );
      }
    }

    final completedExerciseIds = <String>{};
    for (final record in records) {
      final data = record.data();
      final courseId = data['courseId']?.toString() ?? '';
      final examId = data['completedExamId']?.toString() ?? '';
      if (courseId.isNotEmpty &&
          examId.isNotEmpty &&
          (data['examCompleted'] == true || data['completed'] == true)) {
        completedExerciseIds.add('$courseId|$examId');
      }
    }
    for (final attempt in attempts) {
      final data = attempt.data();
      final courseId = data['courseId']?.toString() ?? '';
      final examId = data['examId']?.toString() ?? '';
      if (data['status'] == 'completed' &&
          courseId.isNotEmpty &&
          examId.isNotEmpty) {
        completedExerciseIds.add('$courseId|$examId');
      }
    }

    return (
      completedCourses: completedCourses,
      completedExercises: exerciseIds.intersection(completedExerciseIds).length,
      totalExercises: exerciseIds.length,
    );
  }

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  Widget _header() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: const BoxDecoration(color: AppTheme.red),
    child: Row(
      children: [
        Image.asset(AppTheme.appLogo, width: 48, height: 48),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hệ thống',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'HỌC TẬP SỐ E09',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Thông báo',
          onPressed: () => widget.onSelect(3),
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          _header(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: LearningList(
                  stream: courses,
                  errorTitle: 'Tải khóa học trong bảng tiến độ',
                  builder: (cacKhoaHoc) {
                    final khoaHocDangMo = cacKhoaHoc
                        .where(
                          (course) => LearningPolicy.canRead(course.data()),
                        )
                        .toList();
                    return ListView(
                      padding: EdgeInsets.all(
                        MediaQuery.sizeOf(context).width < 360 ? 16 : 20,
                      ),
                      children: [
                        const SizedBox(height: 16),
                        HomeNewsBanner(
                          service: NewsService(service.db),
                          onStudy: () => widget.onSelect(1),
                        ),
                        const SizedBox(height: 20),
                        UserNews(
                          service: service,
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
                        LearnerCourseCatalog(
                          courses: khoaHocDangMo,
                          service: service,
                          builder: (entries) {
                            final lessons = entries
                                .map((entry) => entry.lessons)
                                .toList();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                LearningList(
                                  stream: learning,
                                  errorTitle: 'Tải tiến độ khóa học',
                                  builder: (cacMauTin) => LearningList(
                                    stream: examAttempts,
                                    errorTitle: 'Tải kết quả kiểm tra',
                                    builder: (cacLuotLamBai) {
                                      final counts = _progressCounts(
                                        courses: khoaHocDangMo,
                                        lessons: lessons,
                                        records: cacMauTin,
                                        attempts: cacLuotLamBai,
                                      );
                                      return LearnerMetrics(
                                        children: [
                                          _thongKe(
                                            '${counts.completedCourses}/${khoaHocDangMo.length}',
                                            'Khóa học hoàn thành',
                                            Icons.menu_book_outlined,
                                          ),
                                          _thongKe(
                                            '${counts.completedExercises}/${counts.totalExercises}',
                                            'Bài tập đã làm',
                                            Icons.check_circle_outline,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _courseSection(
                                  context,
                                  title: 'Khóa học kiểm tra',
                                  courses: _latestCourses(
                                    khoaHocDangMo,
                                    lessons,
                                    exams: true,
                                  ),
                                  exams: true,
                                ),
                                _courseSection(
                                  context,
                                  title: 'Khóa học học tập',
                                  courses: _latestCourses(
                                    khoaHocDangMo,
                                    lessons,
                                    exams: false,
                                  ),
                                  exams: false,
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
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
