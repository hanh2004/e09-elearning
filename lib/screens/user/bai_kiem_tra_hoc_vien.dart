import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../services/ket_noi_api/dich_vu_bai_kiem_tra_bao_mat.dart';
import '../../models/bieu_mau_khoa_hoc.dart';
import '../../models/bieu_mau_bai_hoc.dart';
import '../../widgets/anh_bia_khoa_hoc.dart';
import '../../widgets/dau_trang_hoc_vien.dart';
import '../../widgets/tien_ich_giao_dien_hoc_tap.dart';
import 'doc_bai_hoc.dart';
import 'lam_bai_kiem_tra_bao_mat.dart';

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
  late final courses = service.courses(classId: '');
  late final Timer _refreshTimer;

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
    appBar: LearnerHeader(
      title: const Text('Kiểm tra'),
      actions: [
        IconButton(
          tooltip: 'Lịch sử kiểm tra',
          icon: const Icon(Icons.history),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => SecureExamHistoryScreen(
                service: widget.examService ?? SecureExamService(),
              ),
            ),
          ),
        ),
      ],
    ),
    body: LearningList(
      stream: courses,
      builder: (cacBanGhi) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Học trước, kiểm tra sau',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mở nội dung và học đủ thời gian. Câu hỏi kiểm tra chỉ mở sau khi hoàn thành phần học.',
          ),
          const SizedBox(height: 16),
          for (final khoaHoc in cacBanGhi)
            if (LearningPolicy.canRead(khoaHoc.data(), ''))
              _KiemTraKhoaHoc(
                key: ValueKey(khoaHoc.id),
                uid: widget.uid,
                course: khoaHoc,
                service: service,
                examService: widget.examService,
              ),
        ],
      ),
    ),
  );
}

class _KiemTraKhoaHoc extends StatefulWidget {
  const _KiemTraKhoaHoc({
    super.key,
    required this.uid,
    required this.course,
    required this.service,
    this.examService,
  });
  final String uid;
  final QueryDocumentSnapshot<Map<String, dynamic>> course;
  final LearningService service;
  final SecureExamService? examService;
  @override
  State<_KiemTraKhoaHoc> createState() => _TrangThaiKiemTraKhoaHoc();
}

class _TrangThaiKiemTraKhoaHoc extends State<_KiemTraKhoaHoc> {
  late final lessons = widget.service.lessons(widget.course.id);
  @override
  Widget build(BuildContext context) {
    final duLieu = widget.course.data();
    if (duLieu['learningMode'] == 'study_only') {
      return const SizedBox.shrink();
    }
    return LearningList(
      stream: lessons,
      builder: (cacBanGhi) {
        final courseExam = duLieu['learningMode'] == 'study_exam';
        final orderedLessons = LearningPolicy.sortLessons(cacBanGhi);
        final baiHocCoKiemTra = courseExam
            ? orderedLessons
            : orderedLessons
                  .where((baiHoc) => LessonForm.hasExam(baiHoc.data()))
                  .toList();
        final configuredExam =
            courseExam ||
            CourseForm.hasExam(duLieu) ||
            baiHocCoKiemTra.isNotEmpty;
        if (!configuredExam) return const SizedBox.shrink();
        final releaseDate = CourseForm.formatReleaseDateTime(
          duLieu['publishedAt'],
        );
        final coBaiHoc = baiHocCoKiemTra.isNotEmpty;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CourseCover(
              url: duLieu['coverUrl'] ?? '',
              width: 68,
              height: 64,
            ),
            title: Text(
              duLieu['title'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${coBaiHoc ? '${baiHocCoKiemTra.length} bài học • Học hết bài để mở bài kiểm tra' : 'Chưa có bài học để mở bài kiểm tra'}${releaseDate.isEmpty ? '' : ' • Phát hành: $releaseDate'}',
            ),
            trailing: Icon(coBaiHoc ? Icons.chevron_right : Icons.lock_outline),
            onTap: !coBaiHoc
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => _ChiTietKiemTraKhoaHoc(
                        uid: widget.uid,
                        course: widget.course,
                        lessons: baiHocCoKiemTra,
                        service: widget.service,
                        examService: widget.examService,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _ChiTietKiemTraKhoaHoc extends StatefulWidget {
  const _ChiTietKiemTraKhoaHoc({
    required this.uid,
    required this.course,
    required this.lessons,
    required this.service,
    this.examService,
  });
  final String uid;
  final QueryDocumentSnapshot<Map<String, dynamic>> course;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> lessons;
  final LearningService service;
  final SecureExamService? examService;

  @override
  State<_ChiTietKiemTraKhoaHoc> createState() =>
      _TrangThaiChiTietKiemTraKhoaHoc();
}

class _TrangThaiChiTietKiemTraKhoaHoc extends State<_ChiTietKiemTraKhoaHoc> {
  late final progress = widget.service.progress(widget.uid, widget.course.id);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: LearnerHeader(title: Text(widget.course.data()['title'] ?? '')),
    body: LearningList(
      stream: progress,
      builder: (cacMauTin) {
        final doneIds = cacMauTin
            .where((mauTin) => LearningPolicy.hasCompletedStudy(mauTin.data()))
            .map((mauTin) => mauTin.data()['lessonId']?.toString())
            .whereType<String>()
            .toSet();
        final allComplete = widget.lessons.every(
          (baiHoc) => doneIds.contains(baiHoc.id),
        );
        final finishedIds = cacMauTin
            .where((mauTin) {
              final cacBaiHoc = widget.lessons.where(
                (baiHoc) => baiHoc.id == mauTin.data()['lessonId'],
              );
              return cacBaiHoc.isNotEmpty &&
                  LearningPolicy.isLessonComplete(
                    mauTin.data(),
                    widget.course.data(),
                    cacBaiHoc.first.data(),
                  );
            })
            .map((mauTin) => mauTin.data()['lessonId'])
            .toSet();
        final examComplete = widget.lessons.every(
          (baiHoc) => finishedIds.contains(baiHoc.id),
        );
        final open = LearningPolicy.canRead(widget.course.data(), '');
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Các bài học trong khóa',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              examComplete
                  ? 'Bạn đã hoàn thành khóa học và bài kiểm tra.'
                  : allComplete
                  ? 'Đã học xong nội dung. Làm xong bài kiểm tra để hoàn thành khóa học.'
                  : 'Học hết ${widget.lessons.length} bài để mở bài kiểm tra.',
            ),
            const SizedBox(height: 12),
            for (final baiHoc in widget.lessons)
              Card(
                child: ListTile(
                  leading: CourseCover(
                    url: baiHoc.data()['coverUrl'] ?? '',
                    width: 52,
                    height: 56,
                  ),
                  title: Text(
                    baiHoc.data()['title'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    !open
                        ? 'Khóa học chưa mở hoặc đã kết thúc'
                        : finishedIds.contains(baiHoc.id)
                        ? 'Đã hoàn thành'
                        : doneIds.contains(baiHoc.id)
                        ? 'Đã học xong • Chưa xong kiểm tra'
                        : 'Bấm để học bài',
                  ),
                  trailing: Icon(
                    !open
                        ? Icons.lock_outline
                        : doneIds.contains(baiHoc.id)
                        ? Icons.check_circle_outline
                        : Icons.chevron_right,
                  ),
                  onTap: !open
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => LessonReaderScreen(
                              uid: widget.uid,
                              courseId: widget.course.id,
                              lessonId: baiHoc.id,
                              lesson: baiHoc.data(),
                              service: widget.service,
                              examService: widget.examService,
                              courseData: widget.course.data(),
                            ),
                          ),
                        ),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: !open || !allComplete
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => LessonReaderScreen(
                          uid: widget.uid,
                          courseId: widget.course.id,
                          lessonId: widget.lessons.last.id,
                          lesson: widget.lessons.last.data(),
                          service: widget.service,
                          examService: widget.examService,
                          courseData: widget.course.data(),
                          autoOpenExam: true,
                        ),
                      ),
                    ),
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Làm bài kiểm tra'),
            ),
          ],
        );
      },
    ),
  );
}
