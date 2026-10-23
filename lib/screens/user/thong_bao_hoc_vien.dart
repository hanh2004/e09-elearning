// APP HỌC VIÊN: Danh sách thông báo và trạng thái đã đọc của học viên.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import '../../widgets/dau_trang_hoc_vien.dart';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../models/quy_tac_hoc_tap.dart';
import '../../models/quy_tac_thong_bao.dart';
import '../../services/ket_noi_api/dich_vu_bai_kiem_tra_bao_mat.dart';
import '../../services/nghiep_vu/dich_vu_hoc_tap.dart' show LearningService;
import '../../services/thong_bao_loi_ung_dung.dart';
import '../../widgets/thong_bao_loi.dart';
import '../../widgets/tien_ich_giao_dien_hoc_tap.dart';
import 'cac_khoa_hoc.dart';

/// Danh sách thông báo và trạng thái đã đọc của học viên.
class UserNotificationsScreen extends StatefulWidget {
  const UserNotificationsScreen({
    super.key,
    required this.uid,
    this.service,
    this.examService,
  });
  final String uid;
  final LearningService? service;
  final SecureExamService? examService;
  @override
  State<UserNotificationsScreen> createState() => _TrangThaiThongBaoHocVien();
}

class _TrangThaiThongBaoHocVien extends State<UserNotificationsScreen> {
  late final service = widget.service ?? LearningService();
  Stream<DocumentSnapshot<Map<String, dynamic>>> _profileStream() => service.db
      .collection('users')
      .doc(widget.uid)
      .snapshots(includeMetadataChanges: true);
  late final reads = service.notificationReads(widget.uid);
  bool unreadOnly = false;
  final pending = <String>{};
  Future<void> markRead(String ma) async {
    if (!pending.add(ma)) return;
    try {
      await service.markNotificationRead(widget.uid, ma);
    } catch (loi) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppErrorMessage.from(
                loi,
                feature: 'Đánh dấu thông báo đã đọc',
                fallbackAction:
                    'Kiểm tra kết nối và cấu hình máy chủ rồi thử lại.',
              ),
            ),
          ),
        );
      }
    } finally {
      pending.remove(ma);
    }
  }

  Future<void> openCourseFromNotification(
    Map<String, dynamic> notification,
  ) async {
    try {
      final notificationTitle = notification['title']?.toString() ?? '';
      var courseId = notification['courseId']?.toString().trim() ?? '';
      String? legacyCourseTitle;
      if (courseId.isEmpty && notificationTitle.startsWith('Khóa học mới: ')) {
        legacyCourseTitle = notificationTitle
            .substring('Khóa học mới: '.length)
            .trim();
      } else if (courseId.isEmpty &&
          notificationTitle.startsWith('Bài học mới: ')) {
        final match = RegExp(r'^Khóa học (.+?) có bài học mới(?:\.|$)')
            .firstMatch(notification['body']?.toString() ?? '');
        legacyCourseTitle = match?.group(1)?.trim();
      }

      Query<Map<String, dynamic>> query = service.db
          .collection('courses')
          .where('published', isEqualTo: true);
      if (courseId.isNotEmpty) {
        query = query.where(FieldPath.documentId, isEqualTo: courseId);
      } else if (legacyCourseTitle != null && legacyCourseTitle.isNotEmpty) {
        query = query.where('title', isEqualTo: legacyCourseTitle);
      } else {
        _showCourseOpenMessage('Thông báo này không gắn với khóa học.');
        return;
      }

      final result = await service
          .watchQuery(query.limit(1))
          .first
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (result.docs.isEmpty) {
        _showCourseOpenMessage('Khóa học không còn khả dụng.');
        return;
      }
      final course = result.docs.first;
      if (!LearningPolicy.canRead(course.data())) {
        _showCourseOpenMessage('Khóa học chưa được mở hoặc đã kết thúc.');
        return;
      }
      final lessonDocs =
          (await service
                  .lessons(course.id)
                  .first
                  .timeout(const Duration(seconds: 20)))
              .docs;
      if (!mounted) return;
      final isExamCourse = LearningPolicy.isExamCourse(
        course.data(),
        lessonDocs.map((lesson) => lesson.data()),
      );
      final destination = isExamCourse
          ? TestCourseDetailsScreen(
              uid: widget.uid,
              course: course,
              service: service,
              examService: widget.examService,
            )
          : UserLessonsScreen(
              uid: widget.uid,
              course: course,
              service: service,
              examService: widget.examService,
            );
      await Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => destination),
      );
    } catch (error) {
      if (mounted) {
        _showCourseOpenMessage(
          AppErrorMessage.from(
            error,
            feature: 'Mở khóa học từ thông báo',
            fallbackAction: 'Kiểm tra kết nối rồi thử lại.',
          ),
          onRetry: () => unawaited(openCourseFromNotification(notification)),
        );
      }
    }
  }

  void _showCourseOpenMessage(String message, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: onRetry == null
              ? null
              : SnackBarAction(label: 'Tải lại', onPressed: onRetry),
        ),
      );
  }

  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: LearnerHeader(title: const Text('Thông báo hệ thống')),
    body: ReloadableStreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      streamFactory: _profileStream,
      feature: 'Tải hồ sơ để nhận thông báo',
      isUsableData: (data) => data.exists || !data.metadata.isFromCache,
      builder: (context, duLieuNhan) {
        if (!duLieuNhan.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return LearningList(
          stream: service.notifications(
            widget.uid,
            duLieuNhan.data!.data()?['classId'] ?? '',
          ),
          errorTitle: 'Tải thông báo học viên',
          builder: (cacBanGhi) {
            final daSapXep = cacBanGhi.toList()
              ..sort((a, b) {
                final bDate =
                    LearningPolicy.readDateTime(b.data()['sendAt']) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final aDate =
                    LearningPolicy.readDateTime(a.data()['sendAt']) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                return bDate.compareTo(aDate);
              });
            if (daSapXep.isEmpty) {
              return const Center(child: Text('Bạn chưa có thông báo mới.'));
            }
            return LearningList(
              stream: reads,
              errorTitle: 'Tải trạng thái đã đọc',
              builder: (receipts) {
                final readIds = receipts.map((r) => r.id).toSet();
                final unread = daSapXep
                    .where((d) => !readIds.contains(d.id))
                    .toList();
                final visible = unreadOnly ? unread : daSapXep;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text('Tất cả (${daSapXep.length})'),
                          selected: !unreadOnly,
                          onSelected: (_) => setState(() => unreadOnly = false),
                        ),
                        ChoiceChip(
                          label: Text('Chưa đọc (${unread.length})'),
                          selected: unreadOnly,
                          onSelected: (_) => setState(() => unreadOnly = true),
                        ),
                      ],
                    ),
                    if (visible.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Bạn đã đọc tất cả thông báo.'),
                      ),
                    for (final banGhi in visible)
                      Card(
                        key: ValueKey('notification-${banGhi.id}'),
                        color: readIds.contains(banGhi.id)
                            ? Colors.white
                            : const Color(0xFFF0F4FC),
                        child: ListTile(
                          title: Text(
                            banGhi.data()['title'] ?? '',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: readIds.contains(banGhi.id)
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                ),
                          ),
                          subtitle: Text(
                            _formatNotificationDate(
                              LearningPolicy.readDateTime(
                                banGhi.data()['sendAt'],
                              ),
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            if (!readIds.contains(banGhi.id)) {
                              unawaited(markRead(banGhi.id));
                            }
                            unawaited(
                              _showNotificationDetails(
                                context,
                                banGhi.data(),
                                onOpenCourse: () => unawaited(
                                  openCourseFromNotification(banGhi.data()),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    ),
  );
}

Future<void> _showNotificationDetails(
  BuildContext context,
  Map<String, dynamic> data, {
  required VoidCallback onOpenCourse,
}) {
  final sender = (data['senderName'] ?? '').toString().trim();
  final purpose = (data['purpose'] ?? '').toString().trim();
  final sentAt = LearningPolicy.readDateTime(data['sendAt']);
  final senderLabel = sender.isNotEmpty
      ? sender
      : (data['updatedBy'] ?? '').toString().trim().isNotEmpty
      ? 'Quản trị viên'
      : 'Hệ thống';
  final purposeLabel = purpose.isNotEmpty
      ? purpose
      : defaultNotificationPurpose(data['title']?.toString() ?? '');
  final title = data['title']?.toString() ?? '';
  final isCourseNotification =
      (data['courseId']?.toString().trim().isNotEmpty ?? false) ||
      title.startsWith('Khóa học mới: ') ||
      title.startsWith('Bài học mới: ');

  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x990E1830),
    builder: (dialogContext) {
      final screenHeight = MediaQuery.sizeOf(dialogContext).height;
      final body = data['body']?.toString().trim() ?? '';
      final destination = purposeLabel.toLowerCase().contains('kiểm tra')
          ? 'Kiểm tra'
          : 'Học tập';
      final contentText = _courseReleaseMessage(
        title,
        body,
        destination: destination,
      );
      final contentLabel = _notificationBodyLabel(contentText);
      final displayTitle = title.startsWith('Khóa học mới: ')
          ? title.substring('Khóa học mới: '.length).trim()
          : title;
      final purposeIcon = purposeLabel.toLowerCase().contains('kiểm tra')
          ? Icons.assignment_outlined
          : Icons.menu_book_outlined;

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        backgroundColor: Colors.transparent,
        elevation: 16,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 540,
            maxHeight: screenHeight * .9,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppTheme.learnerFrameBorder, width: 1.25),
            boxShadow: const [
              BoxShadow(
                color: Color(0x330B1A2E),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              fit: StackFit.loose,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    AppTheme.learnerLightBackground,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
                Positioned.fill(
                  child: ColoredBox(color: Colors.white.withValues(alpha: .66)),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: screenHeight * .78,
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'THÔNG BÁO',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      color: AppTheme.navy,
                                      fontSize: 25,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: .3,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  const Icon(
                                    Icons.lightbulb_outline_rounded,
                                    color: Color(0xFF66839A),
                                    size: 29,
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 17),
                              child: Divider(
                                color: Color(0xFF9A907D),
                                thickness: 1.2,
                              ),
                            ),
                            _notificationMetadataLine(
                              label: 'Người gửi:',
                              value: senderLabel,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.access_time_rounded,
                                    color: AppTheme.navy,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: _notificationMetadataLine(
                                    label: 'Ngày:',
                                    value: _formatNotificationDate(sentAt),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 9,
                              runSpacing: 7,
                              children: [
                                const Text(
                                  'Chủ đề:',
                                  style: TextStyle(
                                    color: AppTheme.navy,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDDEEF3),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        purposeIcon,
                                        size: 19,
                                        color: const Color(0xFF45687B),
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        purposeLabel,
                                        style: const TextStyle(
                                          color: Color(0xFF263E50),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9E9E3),
                                borderRadius: BorderRadius.circular(21),
                                border: Border.all(
                                  color: AppTheme.learnerFrameBorder,
                                  width: 1.25,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (displayTitle.isNotEmpty)
                                    SelectableText(
                                      displayTitle,
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 18,
                                        height: 1.45,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  if (displayTitle.isNotEmpty &&
                                      contentText.isNotEmpty)
                                    const SizedBox(height: 13),
                                  if (contentText.isNotEmpty)
                                    SelectableText.rich(
                                      TextSpan(
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 16,
                                          height: 1.55,
                                        ),
                                        children: [
                                          if (contentLabel != null) ...[
                                            TextSpan(
                                              text: contentLabel,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            TextSpan(
                                              text: contentText.substring(
                                                contentLabel.length,
                                              ),
                                            ),
                                          ] else
                                            TextSpan(text: contentText),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isCourseNotification) ...[
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                onOpenCourse();
                              },
                              icon: const Icon(
                                Icons.menu_book_outlined,
                                size: 22,
                              ),
                              label: const Text(
                                'HỌC NGAY',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF707070),
                            ),
                            onPressed: () => Navigator.pop(dialogContext),
                            iconAlignment: IconAlignment.end,
                            label: const Text(
                              'ĐÓNG',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            icon: const Icon(Icons.close_rounded, size: 21),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _notificationMetadataLine({
  required String label,
  required String value,
}) => Text.rich(
  TextSpan(
    style: const TextStyle(color: Colors.black87, fontSize: 16, height: 1.4),
    children: [
      TextSpan(
        text: '$label ',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      TextSpan(text: value),
    ],
  ),
);

String _courseReleaseMessage(
  String title,
  String body, {
  required String destination,
}) {
  if (!title.startsWith('Khóa học mới: ')) return body;

  final releaseMatch = RegExp(
    r'(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})(?::\d{2}(?:\.\d+)?)?',
  ).firstMatch(body);
  if (releaseMatch != null) {
    final dateParts = releaseMatch.group(1)!.split('-');
    final day = int.parse(dateParts[2]);
    final month = int.parse(dateParts[1]);
    final year = dateParts[0];
    final clock = releaseMatch.group(2)!;
    return 'Thời gian phát hành: Khóa học sẽ được mở vào lúc $clock ngày $day tháng $month năm $year. Quý học viên vui lòng truy cập mục \'$destination\' để bắt đầu.';
  }
  if (body.startsWith('Khóa học đã được triển khai')) {
    return 'Trạng thái: Khóa học đã được triển khai. Quý học viên vui lòng truy cập mục \'$destination\' để bắt đầu.';
  }
  return body;
}

String? _notificationBodyLabel(String content) {
  for (final label in const ['Thời gian phát hành:', 'Trạng thái:']) {
    if (content.startsWith(label)) return label;
  }
  return null;
}

String _formatNotificationDate(DateTime? date) {
  if (date == null) return 'Chưa có ngày gửi';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year}, lúc $hour:$minute';
}
