// APP HỌC VIÊN: Trình đọc nội dung bài học và bộ đếm thời gian tối thiểu trước khi hoàn thành.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../models/bieu_mau_khoa_hoc.dart';
import '../../services/ket_noi_api/dich_vu_bai_kiem_tra_bao_mat.dart';
import 'lam_bai_kiem_tra_bao_mat.dart';
import '../../widgets/dau_trang_hoc_vien.dart';
import '../../widgets/anh_bia_khoa_hoc.dart';
import '../../widgets/hien_thi_noi_dung_bai_hoc.dart';
import '../../widgets/thong_bao_loi.dart';

/// Trình đọc nội dung bài học và bộ đếm thời gian tối thiểu trước khi hoàn thành.
class LessonReaderScreen extends StatefulWidget {
  const LessonReaderScreen({
    super.key,
    required this.uid,
    required this.courseId,
    required this.lessonId,
    required this.lesson,
    required this.service,
    this.siblings = const [],
    this.examService,
    this.courseData,
  });
  final String uid, courseId, lessonId;
  final Map<String, dynamic> lesson;
  final LearningService service;
  final SecureExamService? examService;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> siblings;

  /// Dữ liệu khóa cha dành cho khóa học và kiểm tra ở cấp khóa.
  final Map<String, dynamic>? courseData;
  @override
  State<LessonReaderScreen> createState() => _TrangThaiDocBaiHoc();
}

class _TrangThaiDocBaiHoc extends State<LessonReaderScreen>
    with WidgetsBindingObserver {
  Timer? timer;
  int elapsed = 0;
  bool ready = false, completed = false, saving = false, active = true;
  String? error;
  bool startingExam = false;
  String? examError;
  bool courseComplete = false;
  bool get isStudyOnlyCourse => !hasExam;
  bool get hasExam =>
      LearningPolicy.requiresExam(widget.courseData ?? const {}, widget.lesson);
  bool get isCourseExam => CourseForm.hasExam(widget.courseData ?? const {});
  String get examId {
    final courseExam = widget.courseData?['examId']?.toString().trim() ?? '';
    if (courseExam.isNotEmpty) return courseExam;
    return widget.lesson['examId']?.toString().trim() ?? '';
  }

  bool get examAllowed => !isCourseExam || courseComplete;
  final ScrollController _oNhapNoiDung = ScrollController();
  bool reachedEnd = false;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _progressStream() => widget
      .service
      .db
      .doc('users/${widget.uid}/learning/${widget.courseId}_${widget.lessonId}')
      .snapshots(includeMetadataChanges: true);

  void _capNhatDaDocHet() {
    if (!_oNhapNoiDung.hasClients) return;
    final position = _oNhapNoiDung.position;
    final atEnd = position.maxScrollExtent <= position.pixels + 24;
    if (atEnd != reachedEnd && mounted) {
      setState(() => reachedEnd = atEnd);
      if (atEnd &&
          (isStudyOnlyCourse || isCourseExam) &&
          elapsed >= requiredSeconds &&
          !completed &&
          !saving) {
        unawaited(finish());
      }
    }
  }

  Future<void> openExam() async {
    final lastLessonIndex = widget.siblings.indexWhere(
      (lesson) => lesson.id == widget.lessonId,
    );
    if (!hasExam ||
        !completed ||
        startingExam ||
        !examAllowed ||
        (isCourseExam &&
            (lastLessonIndex != widget.siblings.length - 1 || !reachedEnd))) {
      return;
    }
    setState(() {
      startingExam = true;
      examError = null;
    });
    try {
      if (examId.isEmpty) {
        throw StateError(
          'Bài học chưa được gắn bài kiểm tra. Vui lòng liên hệ quản trị.',
        );
      }
      final dichVu = widget.examService ?? SecureExamService();
      final lanThi = await dichVu.call('examStart', {
        'examId': examId,
        'courseId': widget.courseId,
        'lessonId': widget.lessonId,
      });
      final page = lanThi['status'] == 'completed'
          ? SecureExamResultScreen(result: lanThi)
          : SecureExamScreen(run: lanThi, service: dichVu);
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => page),
      );
    } catch (loi) {
      if (mounted) {
        setState(
          () => examError = loi is StateError
              ? loi.message
              : SecureExamService.error(loi),
        );
      }
    } finally {
      if (mounted) setState(() => startingExam = false);
    }
  }

  int get requiredSeconds =>
      (widget.lesson['minimumStudySeconds'] as num? ?? 300).toInt().clamp(
        1,
        86400,
      );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _oNhapNoiDung.addListener(_capNhatDaDocHet);
    active =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) => _capNhatDaDocHet());
    start();
  }

  Future<void> start() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final daXong = await widget.service.startLesson(
        widget.uid,
        widget.courseId,
        widget.lessonId,
      );
      if (!mounted) return;
      await _capNhatHoanThanhKhoa();
      if (!mounted) return;
      setState(() {
        completed = daXong;
        ready = true;
        saving = false;
        elapsed = 0;
      });
      // Giữ luồng kiểm tra theo bài cho dữ liệu cũ. Khóa kiểm tra theo khóa
      // chỉ hiện nút làm bài sau khi học xong tất cả bài học.
      if (hasExam &&
          !isCourseExam &&
          active &&
          ModalRoute.of(context)?.isCurrent == true) {
        await openExam();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _capNhatDaDocHet());
      timer?.cancel();
      if (daXong) {
        return;
      }
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted ||
            !active ||
            saving ||
            error != null ||
            ModalRoute.of(context)?.isCurrent != true) {
          return;
        }
        setState(() {
          if (elapsed < requiredSeconds) elapsed++;
        });
        if (elapsed >= requiredSeconds &&
            reachedEnd &&
            (isStudyOnlyCourse || isCourseExam)) {
          unawaited(finish());
        }
      });
    } catch (loi) {
      if (mounted) {
        setState(() {
          saving = false;
          error = loi is StateError
              ? loi.message
              : 'Chưa bắt đầu được bộ đếm. Kiểm tra kết nối rồi thử lại.';
        });
      }
    }
  }

  Future<void> finish() async {
    if (completed && !saving) {
      setState(() {
        saving = true;
        error = null;
      });
      try {
        await _capNhatHoanThanhKhoa();
      } catch (_) {
        if (mounted) {
          setState(
            () => error = 'Chưa kiểm tra được tiến độ khóa học. Hãy thử lại.',
          );
        }
      } finally {
        if (mounted) setState(() => saving = false);
      }
      return;
    }
    if (saving || completed || elapsed < requiredSeconds || !reachedEnd) {
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.service.completeLesson(
        widget.uid,
        widget.courseId,
        widget.lessonId,
      );
      if (!mounted) return;
      timer?.cancel();
      setState(() {
        completed = true;
        saving = false;
      });
      await _capNhatHoanThanhKhoa();
      if (!mounted) return;
      if (hasExam && !isCourseExam && examAllowed) {
        await openExam();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Chưa lưu được kết quả học. Hãy kết nối mạng và thử lưu lại.';
        });
      }
    }
  }

  Future<void> _capNhatHoanThanhKhoa() async {
    if (!isStudyOnlyCourse && !isCourseExam) {
      if (mounted && courseComplete != true) {
        setState(() => courseComplete = true);
      }
      return;
    }
    final complete = await widget.service
        .isCourseComplete(
          widget.uid,
          widget.courseId,
          studyOnly:
              isCourseExam ||
              widget.courseData?['learningMode'] == 'study_only',
        )
        .timeout(const Duration(seconds: 20));
    if (mounted) setState(() => courseComplete = complete);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    final leftApp =
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;
    if (leftApp && !completed && !saving && elapsed > 0 && mounted) {
      setState(() => elapsed = 0);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    _oNhapNoiDung.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conLai = (requiredSeconds - elapsed).clamp(0, requiredSeconds);
    final duongDanUrl = widget.lesson['url'] as String? ?? '';
    final viTri = widget.siblings.indexWhere((d) => d.id == widget.lessonId);
    final isLastLesson = viTri >= 0 && viTri == widget.siblings.length - 1;
    final showExamButton =
        hasExam &&
        completed &&
        (examAllowed || examError != null) &&
        (!isCourseExam || (isLastLesson && reachedEnd));
    final showStudyOnlyCompleteButton =
        isStudyOnlyCourse &&
        completed &&
        courseComplete &&
        isLastLesson &&
        reachedEnd;
    void navigate(int offset) {
      final tiepTheo = widget.siblings[viTri + offset];
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => LessonReaderScreen(
            uid: widget.uid,
            courseId: widget.courseId,
            lessonId: tiepTheo.id,
            lesson: tiepTheo.data(),
            service: widget.service,
            siblings: widget.siblings,
            examService: widget.examService,
            courseData: widget.courseData,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: LearnerHeader(title: Text(widget.lesson['title'] ?? 'Bài học')),
      body: ListView(
        controller: _oNhapNoiDung,
        padding: const EdgeInsets.all(20),
        children: [
          if (viTri >= 0)
            Text(
              'Tiến trình bài học: ${viTri + 1}/${widget.siblings.length}',
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          const SizedBox(height: 12),
          CourseCover(
            url:
                widget.lesson['coverUrl'] ??
                (widget.lesson['type'] == 'image' ? duongDanUrl : ''),
            width: double.infinity,
            height: 180,
          ),
          const SizedBox(height: 16),
          Text(
            widget.lesson['title'] ?? '',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (hasExam)
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                !isCourseExam
                    ? 'Học xong bài này sẽ mở bài kiểm tra riêng. Làm xong kiểm tra mới hoàn thành bài; kết quả vào Lịch sử kiểm tra khi khóa học kết thúc.'
                    : 'Học xong toàn bộ bài trong khóa sẽ mở bài kiểm tra riêng. Làm xong kiểm tra mới hoàn thành khóa; kết quả vào Lịch sử kiểm tra khi khóa học kết thúc.',
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReloadableStreamBuilder<
                    DocumentSnapshot<Map<String, dynamic>>
                  >(
                    streamFactory: _progressStream,
                    feature: 'Tải trạng thái hoàn thành bài học',
                    isUsableData: (data) =>
                        data.exists || !data.metadata.isFromCache,
                    builder: (context, snapshot) {
                      final examCompleted = LearningPolicy.isLessonComplete(
                        snapshot.data?.data() ?? {},
                        widget.courseData ?? {},
                        widget.lesson,
                      );
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  completed
                                      ? 'Đã học'
                                      : 'Thời gian còn lại: ${conLai ~/ 60}:${(conLai % 60).toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: completed
                                        ? Colors.green.shade700
                                        : null,
                                  ),
                                ),
                              ),
                              Tooltip(
                                triggerMode: TooltipTriggerMode.tap,
                                message: completed
                                    ? hasExam && !examCompleted
                                          ? 'Đã học xong nội dung. Bạn cần làm xong bài kiểm tra để hoàn thành bài học.'
                                          : 'Bài học đã được ghi nhận hoàn thành. Bạn có thể tiếp tục ôn tập.'
                                    : 'Bài này cần học tối thiểu $requiredSeconds giây. Nếu rời ứng dụng, khóa điện thoại hoặc thoát bài trước khi hoàn thành, thời gian học sẽ bắt đầu lại từ đầu.',
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.info_outline, size: 18),
                                ),
                              ),
                            ],
                          ),
                          LinearProgressIndicator(
                            value: completed ? 1 : elapsed / requiredSeconds,
                          ),
                        ],
                      );
                    },
                  ),
                  if (saving)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Đang đồng bộ…'),
                    ),
                  if (error != null) ...[
                    Text(error!, style: const TextStyle(color: Colors.red)),
                    TextButton(
                      onPressed: saving
                          ? null
                          : ready
                          ? finish
                          : start,
                      child: Text(ready ? 'Thử lưu lại' : 'Thử lại'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          LessonContentRenderer(content: widget.lesson['content'] ?? ''),
          if ((widget.lesson['importantNote'] as String? ?? '').isNotEmpty)
            Card(
              color: const Color(0xFFFFF3C9),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LƯU Ý QUAN TRỌNG',
                      style: TextStyle(
                        color: Color(0xFF9A7000),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(widget.lesson['importantNote']),
                  ],
                ),
              ),
            ),
          if (widget.lesson['type'] == 'image' && duongDanUrl.isNotEmpty)
            Image.network(
              duongDanUrl,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (_, _, _) => const Text('Không tải được hình ảnh.'),
            ),
          if (duongDanUrl.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Tài liệu ${widget.lesson['type']}'),
            SelectableText(duongDanUrl),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: duongDanUrl));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã sao chép liên kết tài liệu.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Sao chép liên kết để mở tài liệu'),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showExamButton) ...[
                if (examError != null) ...[
                  Text(examError!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: startingExam ? null : openExam,
                      icon: const Icon(Icons.assignment_outlined),
                      label: const Text('Làm bài kiểm tra'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (examError == null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: startingExam ? null : openExam,
                      icon: const Icon(Icons.assignment_outlined),
                      label: Text(
                        startingExam
                            ? 'Đang mở bài kiểm tra…'
                            : isCourseExam
                            ? 'Kiểm tra và hoàn thành'
                            : 'Làm bài kiểm tra',
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
              if (hasExam && completed && !examAllowed && examError == null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Bạn đã học xong bài này. Hãy hoàn thành các bài còn lại trong khóa để mở bài kiểm tra.',
                    textAlign: TextAlign.center,
                  ),
                ),
              if (isCourseExam &&
                  completed &&
                  isLastLesson &&
                  examAllowed &&
                  !reachedEnd)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Kéo xuống cuối bài học để mở bài kiểm tra.',
                    textAlign: TextAlign.center,
                  ),
                ),
              if (isStudyOnlyCourse &&
                  completed &&
                  isLastLesson &&
                  !courseComplete)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Hãy học xong các bài còn lại trong khóa để hoàn thành.',
                    textAlign: TextAlign.center,
                  ),
                ),
              if (isStudyOnlyCourse &&
                  completed &&
                  isLastLesson &&
                  courseComplete &&
                  !reachedEnd)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Kéo xuống cuối bài học để hoàn thành khóa học.',
                    textAlign: TextAlign.center,
                  ),
                ),
              if (showStudyOnlyCompleteButton)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Hoàn thành khóa học'),
                  ),
                ),
              if (!completed && hasExam && !isCourseExam)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        saving || elapsed < requiredSeconds || !reachedEnd
                        ? null
                        : finish,
                    icon: const Icon(Icons.assignment_turned_in_outlined),
                    label: Text(
                      saving
                          ? 'Đang lưu…'
                          : elapsed < requiredSeconds
                          ? 'Cần học thêm ${conLai ~/ 60}:${(conLai % 60).toString().padLeft(2, '0')}'
                          : 'Học xong và làm bài kiểm tra',
                    ),
                  ),
                ),
              if ((isStudyOnlyCourse || isCourseExam) &&
                  !completed &&
                  elapsed >= requiredSeconds &&
                  !reachedEnd)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    isLastLesson
                        ? isCourseExam
                              ? 'Kéo xuống cuối bài để tự động hoàn thành và mở bài kiểm tra.'
                              : 'Kéo xuống cuối bài để hoàn thành khóa học.'
                        : 'Kéo xuống cuối bài để tự động hoàn thành và mở bài tiếp theo.',
                    textAlign: TextAlign.center,
                  ),
                ),
              if (widget.siblings.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: !startingExam && viTri > 0
                            ? () => navigate(-1)
                            : null,
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Bài trước'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            !startingExam &&
                                completed &&
                                reachedEnd &&
                                viTri >= 0 &&
                                viTri < widget.siblings.length - 1
                            ? () => navigate(1)
                            : null,
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('Bài tiếp theo'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
