// WEB ADMIN: Quản lý bài học của khóa học đang chọn: thêm, sửa và xóa.
// Form: forms/bieu_mau_bai_hoc.dart; cấu trúc dữ liệu: ../../models/bieu_mau_bai_hoc.dart.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../models/dinh_danh_tai_khoan.dart';
import '../../models/bieu_mau_khoa_hoc.dart';
import '../../models/bieu_mau_bai_hoc.dart';
import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../services/du_lieu/dich_vu_firestore.dart';
import '../../services/thong_bao_loi_ung_dung.dart';
import '../../models/tham_so_ngan_hang_cau_hoi.dart';
import '../../widgets/giao_dien_quan_tri.dart';
import '../../widgets/anh_bia_khoa_hoc.dart';
import '../../widgets/tien_ich_giao_dien_hoc_tap.dart';
import 'bao_cao_khoa_hoc.dart';
import 'khung_giao_dien_quan_tri.dart';
import 'forms/bieu_mau_bai_hoc.dart';
import 'ngan_hang_cau_hoi.dart';

/// Danh sách bài học thuộc một khóa học để quản lý tổng chỉnh sửa.
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

  void _showOperationError(
    Object error, {
    required String feature,
    required String fallbackAction,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppErrorMessage.from(
            error,
            feature: feature,
            fallbackAction: fallbackAction,
          ),
        ),
      ),
    );
  }

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
    if (AccountSession.current?.isRoot != true || busy) return;
    if (LearningPolicy.hasEnded(widget.course.data())) return;
    setState(() => busy = true);
    try {
      DateTime? thoiDiemPhatHanh;
      if (!published) {
        final hienHanh = (await widget.course.reference.get()).data() ?? {};
        final cacBaiHoc = await widget.course.reference
            .collection('lessons')
            .get();
        if (cacBaiHoc.docs.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Hãy thêm ít nhất một bài học trước khi triển khai khóa học.',
                ),
              ),
            );
          }
          return;
        }
        if (!await _ensureExamQuestions(hienHanh)) return;
        final scheduled = LearningPolicy.isScheduled(hienHanh);
        final startsAt = LearningPolicy.readDateTime(hienHanh['startsAt']);
        final endsAt = LearningPolicy.readDateTime(hienHanh['endsAt']);
        if (scheduled) {
          try {
            LearningPolicy.requireFutureDateTime(startsAt, 'Thời gian bắt đầu');
            LearningPolicy.requireFutureDateTime(endsAt, 'Thời gian kết thúc');
          } on ArgumentError catch (error) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(error.message.toString())));
            }
            return;
          }
        }
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
                  'Hãy thêm thời gian triển khai, ảnh bìa cho khóa học và từng bài học trước khi triển khai.',
                ),
              ),
            );
          }
          return;
        }
        thoiDiemPhatHanh = await _chonThoiDiemTrienKhai();
        if (!mounted || thoiDiemPhatHanh == null) return;
        LearningPolicy.requireFutureDateTime(
          thoiDiemPhatHanh,
          'Thời gian phát hành',
        );
      }
      await service.saveContent(
        AccountSession.current!.id,
        widget.course.reference,
        {
          'published': !published,
          if (thoiDiemPhatHanh != null)
            'publishedAt': Timestamp.fromDate(thoiDiemPhatHanh),
          'audience': 'all',
        },
      );
      if (mounted) setState(() => published = !published);
    } catch (loi) {
      _showOperationError(
        loi,
        feature: 'Đổi trạng thái triển khai khóa học',
        fallbackAction:
            'Kiểm tra quyền quản trị và kết nối máy chủ rồi thử lại.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<DateTime?> _chonThoiDiemTrienKhai() {
    DateTime? thoiDiem = LearningPolicy.nextFutureMinute();
    String? loi;
    return showDialog<DateTime>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Chọn thời gian triển khai'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Khóa học sẽ được phát hành cho học viên tại thời điểm này.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  'Ngày giờ: ${CourseForm.formatReleaseDateTime(thoiDiem)}',
                ),
                onPressed: () async {
                  final picked = await pickLearningDateTime(
                    context,
                    initialDateTime: thoiDiem,
                    futureOnly: true,
                  );
                  if (picked != null) {
                    setDialogState(() {
                      thoiDiem = picked;
                      loi = null;
                    });
                  }
                },
              ),
              if (loi != null)
                Text(loi!, style: const TextStyle(color: Colors.red)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final selected = LearningPolicy.requireFutureDateTime(
                    thoiDiem,
                    'Thời gian phát hành',
                  );
                  Navigator.pop(dialogContext, selected);
                } on ArgumentError catch (error) {
                  setDialogState(() => loi = error.message.toString());
                }
              },
              child: const Text('Xác nhận triển khai'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _ensureExamQuestions(Map<String, dynamic> courseData) async {
    if (!CourseForm.hasExam(courseData)) return true;
    final savedExamId = (courseData['examId'] ?? '').toString().trim();
    final examId = savedExamId.isEmpty ? linkedExamId.trim() : savedExamId;
    final needsExam = examId.isEmpty;
    var hasQuestions = false;
    if (!needsExam) {
      try {
        final questions = await FirestoreService(firestore: service.db)
            .getQuestionsForExam(examId);
        hasQuestions = questions.any((question) => question.isValidForExam);
      } catch (loi) {
        if (mounted) setState(() => busy = false);
        _showOperationError(
          loi,
          feature: 'Kiểm tra câu hỏi trước khi triển khai khóa học',
          fallbackAction:
              'Kiểm tra quyền truy cập, kết nối và cấu hình máy chủ rồi thử lại.',
        );
        return false;
      }
    }
    if (!needsExam && hasQuestions) return true;
    if (!mounted) return false;

    // Mở khóa giao diện để nút trong hộp thoại có thể bắt đầu thao tác kế tiếp.
    setState(() => busy = false);
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chưa thể triển khai khóa học'),
        content: Text(
          needsExam
              ? 'Khóa học có kiểm tra nhưng chưa có bài kiểm tra. Hãy tạo bài kiểm tra và thêm câu hỏi trước khi triển khai.'
              : 'Bài kiểm tra chưa có câu hỏi hợp lệ. Hãy thêm câu hỏi trước khi triển khai.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(needsExam ? 'Tạo bài kiểm tra' : 'Thêm câu hỏi ngay'),
          ),
        ],
      ),
    );
    if (shouldContinue == true && mounted) {
      if (needsExam) {
        await addExam(openQuestions: true);
      } else {
        await openExam();
      }
    }
    return false;
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
          'endsAt': FieldValue.serverTimestamp(),
          'audience': 'all',
        },
      );
      if (mounted) Navigator.pop(context);
    } catch (loi) {
      _showOperationError(
        loi,
        feature: 'Kết thúc khóa học',
        fallbackAction:
            'Kiểm tra quyền quản trị, trạng thái khóa học và máy chủ rồi thử lại.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit([
    QueryDocumentSnapshot<Map<String, dynamic>>? banGhi,
  ]) async {
    final saved = await showLessonEditor(
      context,
      service: service,
      course: widget.course,
      lesson: banGhi,
    );
    if (!saved ||
        banGhi != null ||
        !hasExamCourse ||
        AccountSession.current?.isRoot != true ||
        !mounted) {
      return;
    }
    await _offerExamQuestions();
  }

  Future<void> _offerExamQuestions() async {
    final examId = linkedExamId.trim();
    var hasQuestions = false;
    if (examId.isNotEmpty) {
      try {
        final questions = await FirestoreService(firestore: service.db)
            .getQuestionsForExam(examId);
        hasQuestions = questions.any((question) => question.isValidForExam);
      } catch (_) {
        // Still offer the question manager if the count cannot be loaded.
      }
    }
    if (!mounted || hasQuestions) return;
    final createExam = examId.isEmpty;
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đã lưu bài học'),
        content: Text(
          createExam
              ? 'Khóa học có kiểm tra nhưng chưa có bài kiểm tra. Hãy tạo bài kiểm tra và thêm câu hỏi để học viên có thể làm bài.'
              : 'Bài kiểm tra của khóa học chưa có câu hỏi. Hãy thêm câu hỏi để học viên có thể làm bài.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(createExam ? 'Tạo bài kiểm tra' : 'Thêm câu hỏi'),
          ),
        ],
      ),
    );
    if (shouldContinue != true || !mounted) return;
    if (createExam) {
      await addExam(openQuestions: true);
    } else {
      await openExam();
    }
  }

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
          'Xóa vĩnh viễn bài học "$tieuDe", tiến độ và đề thi/lượt thi liên quan (nếu có)? Không thể hoàn tác.',
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
          const SnackBar(content: Text('Đã xóa bài học và dữ liệu liên quan.')),
        );
      }
    } catch (loi) {
      debugPrint('Xóa bài học ${banGhi.id} thất bại: $loi');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              service.deletionErrorMessage(loi, itemName: 'bài học'),
            ),
          ),
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

  Future<void> addExam({bool openQuestions = false}) async {
    if (AccountSession.current?.isRoot != true ||
        !hasExamCourse ||
        linkedExamId.isNotEmpty ||
        LearningPolicy.hasEnded(widget.course.data()) ||
        busy) {
      return;
    }
    setState(() => busy = true);
    try {
      final examTitle = 'Bài kiểm tra: ${widget.course.data()['title'] ?? ''}';
      final examId = await FirestoreService(firestore: service.db).addExam(
        title: examTitle,
        durationMinutes: 45,
        maxAttempts: 1,
        courseId: widget.course.id,
      );
      await service.db.doc('exams/$examId').set({
        'shuffleQuestions': false,
        'shuffleAnswers': false,
        'showSolutions': false,
      }, SetOptions(merge: true));
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
      if (mounted) {
        setState(() {
          linkedExamId = examId;
          busy = false;
        });
        if (openQuestions) {
          await openExam();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã thêm bài kiểm tra vào khóa học.')),
          );
        }
      }
    } catch (loi) {
      if (mounted) setState(() => busy = false);
      _showOperationError(
        loi,
        feature: 'Thêm bài kiểm tra vào khóa học',
        fallbackAction:
            'Kiểm tra cấu hình bài kiểm tra, quyền quản trị và máy chủ rồi thử lại.',
      );
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
                        ? () => addExam(openQuestions: true)
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
              errorTitle: 'Tải bài học và bài kiểm tra',
              builder: (cacBanGhi) {
                final courseData = widget.course.data();
                final courseModeLabel = CourseForm.modeLabel(courseData);
                return Column(
                  children: [
                    Expanded(
                      child: cacBanGhi.isEmpty
                          ? Center(
                              child: Text(
                                'Thêm bài học trước khi triển khai khóa học.',
                              ),
                            )
                          : _CacNhomBaiHoc(
                              docs: LearningPolicy.sortLessons(cacBanGhi),
                              courseModeLabel: courseModeLabel,
                              canEdit: AccountSession.current?.isRoot == true,
                              canDelete: AccountSession.current?.isRoot == true,
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
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final String? courseModeLabel;
  final bool canEdit;
  final bool canDelete;
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        for (var index = 0; index < docs.length; index++)
          _lessonTile(context, docs[index], index),
      ],
    );
  }

  Widget _lessonTile(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> banGhi,
    int index,
  ) {
    final data = banGhi.data();
    return Card(
      child: ListTile(
        leading: CourseCover(
          url:
              data['coverUrl'] ??
              (data['type'] == 'image' ? data['url'] ?? '' : ''),
          width: 72,
          height: 64,
        ),
        title: Text('${data['order'] ?? index + 1}. ${data['title']}'),
        subtitle: Text(
          '${courseModeLabel ?? LessonForm.modeLabel(data)} • ${(data['minimumStudySeconds'] as num? ?? LessonForm.defaultStudySeconds).toInt()} giây/bài',
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
                  if (canDelete)
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
    );
  }
}
