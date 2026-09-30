// APP HỌC VIÊN: Trang học và kiểm tra theo khóa, điều hướng từ bài học sang bài thi.

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
  late final courses = service.courses(classId: '');
  late final Timer _refreshTimer;
  final _searchController = TextEditingController();

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
                userId: widget.uid,
                secureBackend: true,
                service: widget.examService ?? SecureExamService(),
              ),
            ),
          ),
        ),
      ],
    ),
    body: LearningList(
      stream: courses,
      builder: (cacBanGhi) {
        final tuKhoa = _searchController.text.toLowerCase();
        final khoaHocPhuHop = cacBanGhi.where((khoaHoc) {
          final duLieu = khoaHoc.data();
          return LearningPolicy.canRead(duLieu, '') &&
              duLieu['learningMode'] != 'study_only' &&
              '${duLieu['title'] ?? ''} ${duLieu['subject'] ?? ''}'
                  .toLowerCase()
                  .contains(tuKhoa);
        }).toList();
        return ListView(
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
            if (khoaHocPhuHop.isEmpty)
              const Center(child: Text('Không tìm thấy khóa học phù hợp.'))
            else
              for (final khoaHoc in khoaHocPhuHop)
                _KiemTraKhoaHoc(
                  key: ValueKey(khoaHoc.id),
                  uid: widget.uid,
                  course: khoaHoc,
                  service: service,
                  examService: widget.examService,
                ),
          ],
        );
      },
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
        final status = courseExam
            ? '${orderedLessons.length} bài học'
            : '${baiHocCoKiemTra.length} bài có kiểm tra';
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
              '${coBaiHoc ? status : 'Chưa có bài học để mở bài kiểm tra'}${releaseDate.isEmpty ? '' : ' • Phát hành: $releaseDate'}',
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
        final courseData = widget.course.data();
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
        final open = LearningPolicy.canRead(courseData, '');
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
                  : courseData['learningMode'] == 'study_exam' && allComplete
                  ? 'Đã học xong nội dung. Làm xong bài kiểm tra để hoàn thành khóa học.'
                  : 'Chọn bài học để tiếp tục học hoặc ôn tập.',
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < widget.lessons.length; index++)
              _lessonCard(
                context,
                widget.lessons[index],
                index,
                open: open,
                done: doneIds.contains(widget.lessons[index].id),
                finished: finishedIds.contains(widget.lessons[index].id),
                courseExam: courseData['learningMode'] == 'study_exam',
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

  Widget _lessonCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> lesson,
    int index, {
    required bool open,
    required bool done,
    required bool finished,
    required bool courseExam,
  }) {
    final data = lesson.data();
    final status = !open
        ? 'Khóa học chưa mở hoặc đã kết thúc'
        : finished
        ? 'Đã hoàn thành'
        : done
        ? courseExam
              ? 'Đã học xong nội dung'
              : LearningPolicy.requiresExam(widget.course.data(), data)
              ? 'Đã học xong • Chưa xong kiểm tra'
              : 'Đã học xong'
        : 'Bấm để học bài';
    final order = data['order'] ?? index + 1;
    return Card(
      child: ListTile(
        leading: CourseCover(
          url: data['coverUrl'] ?? '',
          width: 52,
          height: 56,
        ),
        title: Text(
          data['title'] ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('Bài $order • $status'),
        trailing: Icon(
          !open
              ? Icons.lock_outline
              : finished
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
                    lessonId: lesson.id,
                    lesson: data,
                    service: widget.service,
                    siblings: widget.lessons,
                    examService: widget.examService,
                    courseData: widget.course.data(),
                  ),
                ),
              ),
      ),
    );
  }
}
