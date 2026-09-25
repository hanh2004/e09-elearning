import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/nghiep_vu/learning_service.dart';
import '../../services/ket_noi_api/secure_exam_service.dart';
import '../../models/course_form.dart';
import '../../widgets/course_cover.dart';
import '../../widgets/learner_header.dart';
import '../../widgets/learning_widgets.dart';
import 'lesson_reader_screen.dart';
import 'secure_exam_screen.dart';

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
          if (cacBanGhi
              .where(
                (khoaHoc) =>
                    CourseForm.hasExam(khoaHoc.data()) &&
                    !LearningPolicy.hasEnded(khoaHoc.data()),
              )
              .isEmpty)
            const Text('Chưa có nội dung kiểm tra.'),
          for (final khoaHoc in cacBanGhi)
            if (CourseForm.hasExam(khoaHoc.data()) &&
                !LearningPolicy.hasEnded(khoaHoc.data()))
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
  Widget build(BuildContext context) => LearningList(
    stream: lessons,
    builder: (cacBanGhi) {
      if (cacBanGhi.isEmpty) return const SizedBox.shrink();
      final duLieu = widget.course.data();
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CourseCover(
            url: duLieu['coverUrl'] ?? '',
            width: 68,
            height: 64,
          ),
          title: Text(duLieu['title'] ?? ''),
          subtitle: Text(
            '${cacBanGhi.length} bài học • Học hết bài để mở bài kiểm tra',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => _ChiTietKiemTraKhoaHoc(
                uid: widget.uid,
                course: widget.course,
                lessons: cacBanGhi,
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
                  title: Text(baiHoc.data()['title'] ?? ''),
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
