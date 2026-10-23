// APP HỌC VIÊN: Luồng học trước rồi mới mở bài kiểm tra theo khóa; có lối vào lịch sử thi.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../services/ket_noi_api/dich_vu_bai_kiem_tra_bao_mat.dart';
import '../../models/bieu_mau_khoa_hoc.dart';
import '../../widgets/dau_trang_hoc_vien.dart';
import '../../widgets/danh_muc_khoa_hoc_hoc_vien.dart';
import '../../widgets/the_khoa_hoc_hoc_vien.dart';
import '../../widgets/tien_ich_giao_dien_hoc_tap.dart';
import 'cac_khoa_hoc.dart';
import 'lich_su_bai_kiem_tra.dart';

/// Mục Kiểm tra luôn mở nội dung học trước khi cấp câu hỏi kiểm tra.
class UserLearningTestsScreen extends StatefulWidget {
  const UserLearningTestsScreen({
    super.key,
    required this.uid,
    this.service,
    this.examService,
  });
  final String uid;
  final LearningService? service;
  final SecureExamService? examService;

  @override
  State<UserLearningTestsScreen> createState() => _TrangThaiHocVaKiemTra();
}

class _TrangThaiHocVaKiemTra extends State<UserLearningTestsScreen> {
  late final service = widget.service ?? LearningService();
  late final courses = service.courses(publishedOnly: true);
  late final examAttempts = service.watchQuery(
    service.db
        .collection('exam_attempts')
        .where('userId', isEqualTo: widget.uid),
  );
  late final Timer _refreshTimer;
  final _searchController = TextEditingController();
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: LearnerHeader(
      title: const Text('Kiểm tra'),
      actions: [
        IconButton(
          tooltip: 'Lịch sử kiểm tra',
          icon: const Icon(Icons.history),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ExamHistoryScreen(
                service: widget.examService ?? SecureExamService(),
              ),
            ),
          ),
        ),
      ],
    ),
    body: LearningList(
      stream: courses,
      errorTitle: 'Tải khóa học có bài kiểm tra',
      builder: (cacBanGhi) => LearnerCourseCatalog(
        courses: cacBanGhi
            .where((course) => LearningPolicy.canRead(course.data()))
            .toList(),
        service: service,
        builder: (entries) => LearningList(
          stream: examAttempts,
          errorTitle: 'Tải trạng thái bài kiểm tra',
          builder: (cacLuotThi) {
            final examEntries = entries
                .where((entry) => entry.hasExam)
                .toList();
            final tuKhoa = _searchController.text.toLowerCase();
            final subjects =
                examEntries
                    .map(
                      (entry) =>
                          (entry.course.data()['subject'] as String? ?? '')
                              .trim(),
                    )
                    .where((value) => value.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();
            final khoaHocPhuHop = examEntries.where((entry) {
              final duLieu = entry.course.data();
              return (subject == null ||
                      (duLieu['subject'] as String? ?? '').trim() == subject) &&
                  '${duLieu['title'] ?? ''} ${duLieu['subject'] ?? ''}'
                      .toLowerCase()
                      .contains(tuKhoa);
            }).toList();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm khóa học, môn học…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Xóa nội dung tìm kiếm',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(_searchController.clear),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                LearnerSubjectFilter(
                  subjects: subjects,
                  selected: subject,
                  onSelected: (value) => setState(() => subject = value),
                ),
                const SizedBox(height: 8),
                if (khoaHocPhuHop.isEmpty)
                  const Center(child: Text('Không tìm thấy khóa học phù hợp.'))
                else
                  for (final entry in khoaHocPhuHop)
                    _KiemTraKhoaHoc(
                      key: ValueKey(entry.course.id),
                      uid: widget.uid,
                      course: entry.course,
                      lessons: entry.lessons,
                      service: service,
                      examService: widget.examService,
                      attempts: cacLuotThi,
                    ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _KiemTraKhoaHoc extends StatefulWidget {
  const _KiemTraKhoaHoc({
    super.key,
    required this.uid,
    required this.course,
    required this.lessons,
    required this.service,
    required this.attempts,
    this.examService,
  });
  final String uid;
  final QueryDocumentSnapshot<Map<String, dynamic>> course;
  final List<LessonDoc> lessons;
  final LearningService service;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> attempts;
  final SecureExamService? examService;
  @override
  State<_KiemTraKhoaHoc> createState() => _TrangThaiKiemTraKhoaHoc();
}

class _TrangThaiKiemTraKhoaHoc extends State<_KiemTraKhoaHoc> {
  late final progress = widget.service.progress(widget.uid, widget.course.id);

  bool _daHoanThanhBaiThi(
    String examId,
    String lessonId, {
    required bool examCuaKhoa,
  }) {
    if (examId.isEmpty) return false;
    return widget.attempts.any((attempt) {
      final data = attempt.data();
      final courseId = data['courseId']?.toString() ?? '';
      final attemptLessonId = data['lessonId']?.toString() ?? '';
      return data['status'] == 'completed' &&
          data['examId'] == examId &&
          (courseId.isEmpty || courseId == widget.course.id) &&
          (examCuaKhoa ||
              attemptLessonId.isEmpty ||
              attemptLessonId == lessonId);
    });
  }

  bool _daHoanThanhBaiHoc(
    LessonDoc lesson,
    Map<String, dynamic> courseData,
    Map<String, Map<String, dynamic>> progressByLesson,
    bool examCuaKhoa,
  ) {
    final lessonData = lesson.data();
    final lessonProgress =
        progressByLesson[lesson.id] ?? const <String, dynamic>{};
    if (LearningPolicy.isLessonComplete(
      lessonProgress,
      courseData,
      lessonData,
    )) {
      return true;
    }
    if (!LearningPolicy.hasCompletedStudy(lessonProgress) ||
        !LearningPolicy.requiresExam(courseData, lessonData)) {
      return false;
    }
    final examId = examCuaKhoa
        ? (courseData['examId'] ?? '').toString().trim()
        : (lessonData['examId'] ?? courseData['examId'] ?? '')
              .toString()
              .trim();
    return _daHoanThanhBaiThi(examId, lesson.id, examCuaKhoa: examCuaKhoa);
  }

  @override
  Widget build(BuildContext context) {
    final duLieu = widget.course.data();
    final courseExam = CourseForm.hasExam(duLieu);
    final orderedLessons = widget.lessons;
    final coBaiHoc = orderedLessons.isNotEmpty;
    return LearningList(
      stream: progress,
      errorTitle: 'Tải tiến độ học và kiểm tra',
      builder: (progressDocs) {
        final progressByLesson = <String, Map<String, dynamic>>{
          for (final record in progressDocs)
            if ((record.data()['lessonId']?.toString() ?? '').isNotEmpty)
              record.data()['lessonId'].toString(): record.data(),
        };
        final daHoanThanh =
            orderedLessons.isNotEmpty &&
            orderedLessons.every(
              (lesson) => _daHoanThanhBaiHoc(
                lesson,
                duLieu,
                progressByLesson,
                courseExam,
              ),
            );
        return LearnerCourseCard(
          courseData: duLieu,
          lessonCount: orderedLessons.length,
          status: daHoanThanh ? 'Đã hoàn thành' : 'Chưa hoàn thành',
          statusColor: daHoanThanh ? Colors.green.shade700 : Colors.blueGrey,
          subjectMaxLines: 1,
          onTap: !coBaiHoc
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => TestCourseDetailsScreen(
                      uid: widget.uid,
                      course: widget.course,
                      service: widget.service,
                      examService: widget.examService,
                    ),
                  ),
                ),
          trailing: Icon(
            daHoanThanh
                ? Icons.check_circle_outline
                : coBaiHoc
                ? Icons.chevron_right
                : Icons.lock_outline,
            color: daHoanThanh ? Colors.green : null,
          ),
        );
      },
    );
  }
}
