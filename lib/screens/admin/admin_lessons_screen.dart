// WEB ADMIN: Danh sách bài học thuộc một chuyên đề để quản lý tổng chỉnh sửa.
// Form: forms/lesson_editor.dart; dữ liệu nhập: ../../models/lesson_form.dart.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../models/account_identity.dart';
import '../../models/course_form.dart';
import '../../models/lesson_form.dart';
import '../../services/nghiep_vu/learning_service.dart';
import '../../services/du_lieu/firestore_service.dart';
import '../../models/question_bank_arguments.dart';
import '../../widgets/admin_ui.dart';
import '../../widgets/course_cover.dart';
import '../../widgets/learning_widgets.dart';
import 'admin_course_report_screen.dart';
import 'admin_responsive_shell.dart';
import 'forms/lesson_editor.dart';
import 'admin_question_bank_screen.dart';

/// Danh sách bài học thuộc một chuyên đề để quản lý tổng chỉnh sửa.
class AdminLessonsScreen extends StatefulWidget {
  const AdminLessonsScreen({super.key, required this.course, this.service});
  final LearningService? service;
  final QueryDocumentSnapshot<Map<String, dynamic>> course;
  @override
  State<AdminLessonsScreen> createState() => _TrangThaiBaiHocQuanTri();
}

class _TrangThaiBaiHocQuanTri extends State<AdminLessonsScreen> {
  late final service = widget.service ?? LearningService();
  late final stream = service.lessons(widget.course.id);
  late bool published = widget.course.data()['published'] == true;
  late String linkedExamId = (widget.course.data()['examId'] ?? '').toString();
  bool busy = false;
  late final Timer refreshTimer;

  bool get hasExamCourse => CourseForm.hasExam(widget.course.data());
  @override
  void initState() {
    super.initState();
    refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    refreshTimer.cancel();
    super.dispose();
  }

  Future<void> publish() async {
    if (AccountSession.current?.isRoot != true) return;
    if (LearningPolicy.hasEnded(widget.course.data())) return;
    setState(() => busy = true);
    try {
      if (!published) {
        final hienHanh = (await widget.course.reference.get()).data() ?? {};
        final scheduled = LearningPolicy.isScheduled(hienHanh);
        final startsAt = LearningPolicy.readDateTime(hienHanh['startsAt']);
        final endsAt = LearningPolicy.readDateTime(hienHanh['endsAt']);
        final cacBaiHoc = await widget.course.reference
            .collection('lessons')
            .get();
        if ((scheduled &&
                (startsAt == null ||
                    endsAt == null ||
                    !endsAt.isAfter(startsAt))) ||
            (hienHanh['coverUrl'] as String? ?? '').isEmpty ||
            cacBaiHoc.docs.any(
              (d) =>
                  (d.data()['coverUrl'] as String? ??
                          (d.data()['type'] == 'image'
                              ? d.data()['url'] as String?
                              : null) ??
                          '')
                      .isEmpty,
            )) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Hãy thêm thời gian triển khai, ảnh bìa cho chuyên đề và từng bài học trước khi triển khai.',
                ),
              ),
            );
          }
          return;
        }
      }
      await service.saveContent(
        AccountSession.current!.id,
        widget.course.reference,
        {'published': !published, 'audience': 'all'},
      );
      if (mounted) setState(() => published = !published);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không đổi được trạng thái khóa học.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> endManually() async {
    if (AccountSession.current?.isRoot != true || !published || busy) return;
    if (!LearningPolicy.isManual(widget.course.data())) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kết thúc khóa học'),
        content: const Text(
          'Sau khi kết thúc, khóa học sẽ bị khóa và học viên không thể ghi thêm tiến độ. Bạn vẫn xem được báo cáo tổng hợp theo đơn vị.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kết thúc'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => busy = true);
    try {
      await service.saveContent(
        AccountSession.current!.id,
        widget.course.reference,
        {
          'published': true,
          'deploymentMode': 'manual',
          'endsAt': Timestamp.now(),
          'audience': 'all',
        },
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không kết thúc được khóa học.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit([QueryDocumentSnapshot<Map<String, dynamic>>? banGhi]) =>
      showLessonEditor(
        context,
        service: service,
        course: widget.course,
        lesson: banGhi,
      );

  Future<void> deleteLesson(
    QueryDocumentSnapshot<Map<String, dynamic>> banGhi,
  ) async {
    if (AccountSession.current?.isRoot != true || busy) return;
    final tieuDe = (banGhi.data()['title'] ?? 'Bài học').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bài học'),
        content: Text(
          'Xóa vĩnh viễn bài học "$tieuDe" và tiến độ học liên quan? Không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await service.deleteLesson(widget.course.id, banGhi.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa bài học và tiến độ liên quan.')),
        );
      }
    } catch (loi) {
      debugPrint('Xóa bài học ${banGhi.id} thất bại: $loi');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không xóa được bài học.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openExam() async {
    if (linkedExamId.trim().isEmpty) return;
    final baiThi = await service.db.doc('exams/$linkedExamId').get();
    if (!mounted || !baiThi.exists) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminQuestionBankScreen(
          args: QuestionBankArguments(
            examId: linkedExamId,
            examTitle: baiThi.data()?['title'] ?? 'Bài kiểm tra',
          ),
          service: FirestoreService(firestore: service.db),
        ),
      ),
    );
  }

  Future<void> addExam() async {
    if (AccountSession.current?.isRoot != true ||
        !hasExamCourse ||
        linkedExamId.isNotEmpty ||
        LearningPolicy.hasEnded(widget.course.data()) ||
        busy) {
      return;
    }
    final tieuDe = TextEditingController();
    final thoiLuong = TextEditingController(text: '45');
    final maxAttempts = TextEditingController(text: '1');
    var unlimited = false;
    final cacGiaTri = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Thêm bài kiểm tra vào khóa học'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tieuDe,
                  decoration: const InputDecoration(
                    labelText: 'Tên bài kiểm tra',
                  ),
                ),
                TextField(
                  controller: thoiLuong,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Thời gian làm bài (phút)',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Không giới hạn lượt làm'),
                  value: unlimited,
                  onChanged: (giaTri) => update(() => unlimited = giaTri),
                ),
                if (!unlimited)
                  TextField(
                    controller: maxAttempts,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Số lượt làm tối đa',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final soPhut = int.tryParse(thoiLuong.text.trim());
                final cacLuotThi = int.tryParse(maxAttempts.text.trim());
                if (tieuDe.text.trim().isEmpty ||
                    soPhut == null ||
                    soPhut < 1 ||
                    soPhut > 1440 ||
                    (!unlimited && (cacLuotThi == null || cacLuotThi < 1))) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Vui lòng nhập thông tin bài kiểm tra hợp lệ.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, {
                  'title': tieuDe.text.trim(),
                  'minutes': soPhut,
                  'maxAttempts': unlimited ? null : cacLuotThi,
                });
              },
              child: const Text('Tạo'),
            ),
          ],
        ),
      ),
    );
    if (cacGiaTri == null || !mounted) return;
    setState(() => busy = true);
    try {
      final examId = await FirestoreService(firestore: service.db).addExam(
        title: cacGiaTri['title'] as String,
        durationMinutes: cacGiaTri['minutes'] as int,
        isOpen: true,
        maxAttempts: cacGiaTri['maxAttempts'] as int?,
        courseId: widget.course.id,
      );
      await service.saveContent(
        AccountSession.current!.id,
        widget.course.reference,
        {
          'learningMode': 'study_exam',
          'examId': examId,
          'published': published,
          'audience': 'all',
        },
      );
      await service.db.doc('exams/$examId').set({
        'courseId': widget.course.id,
        'courseEndsAt': widget.course.data()['endsAt'],
      }, SetOptions(merge: true));
      if (mounted) {
        setState(() {
          linkedExamId = examId;
          busy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm bài kiểm tra vào khóa học.')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thêm được bài kiểm tra.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      LearningPolicy.hasEnded(widget.course.data())
      ? AdminCourseReportScreen(course: widget.course, service: service)
      : AdminResponsiveShell(
          selectedIndex: 0,
          activeExtra: CourseForm.hasExam(widget.course.data())
              ? 'Khóa học có kiểm tra'
              : 'Khóa học không kiểm tra',
          onSelected: (viTri) => pushAdminPrimary(context, viTri),
          child: Scaffold(
            appBar: AdminUi.appBar(
              widget.course.data()['title'] ?? 'Bài học',
              actions: [
                if (AccountSession.current?.isRoot == true && hasExamCourse)
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : linkedExamId.isEmpty
                        ? addExam
                        : openExam,
                    style: TextButton.styleFrom(foregroundColor: AppTheme.navy),
                    icon: Icon(
                      linkedExamId.isEmpty
                          ? Icons.add_task
                          : Icons.quiz_outlined,
                    ),
                    label: Text(
                      linkedExamId.isEmpty
                          ? 'Thêm bài kiểm tra'
                          : 'Quản lý bài kiểm tra',
                    ),
                  ),
                if (AccountSession.current?.isRoot == true)
                  if (published &&
                      LearningPolicy.isManual(widget.course.data()))
                    TextButton(
                      onPressed: busy ? null : endManually,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.navy,
                      ),
                      child: const Text('Kết thúc khóa học'),
                    ),
                if (AccountSession.current?.isRoot == true)
                  TextButton(
                    onPressed: busy ? null : publish,
                    style: TextButton.styleFrom(foregroundColor: AppTheme.navy),
                    child: Text(published ? 'Ngừng triển khai' : 'Triển khai'),
                  ),
              ],
            ),
            floatingActionButton: AccountSession.current?.isRoot != true
                ? null
                : FloatingActionButton.extended(
                    onPressed: edit,
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm bài học'),
                  ),
            body: LearningList(
              stream: stream,
              builder: (cacBanGhi) {
                final courseData = widget.course.data();
                final courseModeLabel = CourseForm.modeLabel(courseData);
                return Column(
                  children: [
                    Expanded(
                      child: cacBanGhi.isEmpty
                          ? Center(
                              child: Text(
                                'Thêm bài học trước khi xuất bản chuyên đề.',
                              ),
                            )
                          : _CacNhomBaiHoc(
                              docs: cacBanGhi,
                              courseModeLabel: courseModeLabel,
                              canEdit: AccountSession.current?.isRoot == true,
                              onEdit: edit,
                              onDelete: deleteLesson,
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
}

class _CacNhomBaiHoc extends StatelessWidget {
  const _CacNhomBaiHoc({
    required this.docs,
    this.courseModeLabel,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final String? courseModeLabel;
  final bool canEdit;
  final Future<void> Function(
    QueryDocumentSnapshot<Map<String, dynamic>> banGhi,
  )
  onEdit;
  final Future<void> Function(
    QueryDocumentSnapshot<Map<String, dynamic>> banGhi,
  )
  onDelete;

  @override
  Widget build(BuildContext context) {
    final chapters =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final banGhi in docs) {
      final chapter = (banGhi.data()['chapter'] as String? ?? '').trim();
      (chapters[chapter.isEmpty ? 'Chương học' : chapter] ??= []).add(banGhi);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        for (final capDuLieu in chapters.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(
              capDuLieu.key,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF12275A),
              ),
            ),
          ),
          for (final banGhi in capDuLieu.value)
            Card(
              child: ListTile(
                leading: CourseCover(
                  url:
                      banGhi.data()['coverUrl'] ??
                      (banGhi.data()['type'] == 'image'
                          ? banGhi.data()['url'] ?? ''
                          : ''),
                  width: 72,
                  height: 64,
                ),
                title: Text(
                  '${banGhi.data()['order']}. ${banGhi.data()['title']}',
                ),
                subtitle: Text(
                  '${courseModeLabel ?? LessonForm.modeLabel(banGhi.data())} • ${(banGhi.data()['minimumStudySeconds'] as num? ?? LessonForm.defaultStudySeconds).toInt()} giây/bài',
                ),
                trailing: canEdit
                    ? Wrap(
                        spacing: 2,
                        children: [
                          IconButton(
                            tooltip: 'Sửa bài học',
                            icon: const Icon(Icons.edit),
                            onPressed: () => onEdit(banGhi),
                          ),
                          IconButton(
                            tooltip: 'Xóa bài học',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => onDelete(banGhi),
                          ),
                        ],
                      )
                    : null,
                onTap: canEdit ? () => onEdit(banGhi) : null,
              ),
            ),
        ],
      ],
    );
  }
}
