// APP HỌC VIÊN: Trang tổng quan học viên: tiến độ và khóa học đang học.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'dart:async';

import '../../widgets/thong_ke_hoc_vien.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/anh_bia_khoa_hoc.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../models/bieu_mau_khoa_hoc.dart';
import '../../models/bieu_mau_bai_hoc.dart';
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
  late final profile = service.db
      .collection('users')
      .doc(widget.args.userId)
      .snapshots();
  late final learning = service.db
      .collection('users')
      .doc(widget.args.userId)
      .collection('learning')
      .snapshots();
  late final examAttempts = service.db
      .collection('exam_attempts')
      .where('userId', isEqualTo: widget.args.userId)
      .snapshots();
  String? _cachedCourseIds;
  Future<List<List<_DashboardLesson>>>? _cachedLessons;

  Future<List<List<_DashboardLesson>>> _lessonsFor(
    List<_DashboardCourse> courses,
  ) {
    final ids = courses.map((course) => course.id).join('|');
    if (_cachedCourseIds != ids || _cachedLessons == null) {
      _cachedCourseIds = ids;
      _cachedLessons = Future.wait(
        courses.map((course) async {
          final snapshot = await service.lessons(course.id).first;
          return LearningPolicy.sortLessons(snapshot.docs);
        }),
      );
    }
    return _cachedLessons!;
  }

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
      if (mode == 'study_exam') {
        if (courseExamId.isNotEmpty) {
          exerciseIds.add('${course.id}|$courseExamId');
        }
        continue;
      }

      final lessonExamIds = courseLessons
          .where((lesson) => LessonForm.hasExam(lesson.data()))
          .map((lesson) => (lesson.data()['examId'] ?? '').toString().trim())
          .where((examId) => examId.isNotEmpty)
          .toSet();
      if (lessonExamIds.isNotEmpty) {
        exerciseIds.addAll(
          lessonExamIds.map((examId) => '${course.id}|$examId'),
        );
      } else if (CourseForm.hasExam(courseData) && courseExamId.isNotEmpty) {
        exerciseIds.add('${course.id}|$courseExamId');
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
        _cachedCourseIds = null;
        _cachedLessons = null;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

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
                builder: (cacKhoaHoc) {
                  final khoaHocDangMo = cacKhoaHoc
                      .where(
                        (course) => LearningPolicy.canRead(course.data(), ''),
                      )
                      .toList();
                  return ListView(
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
                      FutureBuilder<List<List<_DashboardLesson>>>(
                        future: _lessonsFor(khoaHocDangMo),
                        builder: (context, lessonSnapshot) {
                          if (lessonSnapshot.hasError) {
                            return const Text('Chưa tải được tiến độ học tập.');
                          }
                          if (!lessonSnapshot.hasData) {
                            return const SizedBox(
                              height: 48,
                              child: Center(
                                child: SizedBox(
                                  width: 160,
                                  child: LinearProgressIndicator(),
                                ),
                              ),
                            );
                          }
                          return LearningList(
                            stream: learning,
                            builder: (cacMauTin) => LearningList(
                              stream: examAttempts,
                              builder: (cacLuotLamBai) {
                                final counts = _progressCounts(
                                  courses: khoaHocDangMo,
                                  lessons: lessonSnapshot.data!,
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
                          );
                        },
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
                      if (khoaHocDangMo.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Khóa học được phân cho bạn sẽ xuất hiện tại đây.',
                            ),
                          ),
                        ),
                      for (final khoaHoc in khoaHocDangMo.take(4))
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${khoaHoc.data()['subject'] ?? ''}${CourseForm.formatReleaseDateTime(khoaHoc.data()['publishedAt']).isEmpty ? '' : ' • Phát hành: ${CourseForm.formatReleaseDateTime(khoaHoc.data()['publishedAt'])}'}',
                            ),
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
                  );
                },
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
