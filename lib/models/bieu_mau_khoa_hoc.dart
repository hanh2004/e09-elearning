// DỮ LIỆU: Dữ liệu form khóa học: đổi nhãn tại labels, giữ nguyên mã trường bên trái.
// Giữ tên trường Firebase khi đổi cách hiển thị để đọc được dữ liệu đã lưu.

import 'package:cloud_firestore/cloud_firestore.dart';

import 'quy_tac_hoc_tap.dart';

/// Dữ liệu form khóa học: đổi nhãn tại labels, giữ nguyên mã trường bên trái.
/// Không đọc/ghi Firebase ở đây; toFirestore chỉ kiểm tra và chuyển dữ liệu.
class CourseForm {
  static const manualLabel = 'Mở/đóng thủ công';
  static const scheduledLabel = 'Tự động theo thời gian';
  static const studyOnlyLabel = 'Học để biết';
  static const studyExamLabel = 'Học để làm bài kiểm tra';

  static bool hasExam(Map<String, dynamic> duLieu) {
    if (duLieu['learningMode'] == 'study_exam') return true;
    if (duLieu['learningMode'] == 'study_only') return false;
    final examId = duLieu['examId'];
    return examId is String && examId.trim().isNotEmpty;
  }

  static String modeLabel(Map<String, dynamic> duLieu) =>
      hasExam(duLieu) ? studyExamLabel : studyOnlyLabel;

  static const labels = {
    'title': 'Tên khóa học',
    'subject': 'Môn học',
    'description': 'Mô tả',
    'instructor': 'Giảng viên',
    'objectives': 'Mục tiêu học tập (mỗi dòng một mục)',
    'learningMode': 'Loại khóa học',
    'examId': 'Bài kiểm tra cuối khóa',
    'deploymentMode': 'Cách triển khai',
    'startsAt': 'Thời gian bắt đầu (YYYY-MM-DD HH:mm)',
    'endsAt': 'Thời gian kết thúc (YYYY-MM-DD HH:mm)',
  };

  static Map<String, String> initialValues(Map<String, dynamic> duLieu) => {
    'title': duLieu['title'] ?? '',
    'subject': duLieu['subject'] ?? '',
    'description': duLieu['description'] ?? '',
    'instructor': duLieu['instructor'] ?? '',
    'objectives': duLieu['objectives'] ?? '',
    'learningMode': modeLabel(duLieu),
    'examId': duLieu['examId'] ?? '',
    'deploymentMode': LearningPolicy.isScheduled(duLieu)
        ? scheduledLabel
        : manualLabel,
    'startsAt': formatDateTime(duLieu['startsAt']),
    'endsAt': formatDateTime(duLieu['endsAt']),
  };

  static String formatDateTime(dynamic giaTri) {
    final ngay = LearningPolicy.readDateTime(giaTri);
    if (ngay == null) return '';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${ngay.year}-${two(ngay.month)}-${two(ngay.day)} '
        '${two(ngay.hour)}:${two(ngay.minute)}';
  }

  static String formatReleaseDateTime(dynamic giaTri) {
    final ngay = LearningPolicy.readDateTime(giaTri);
    if (ngay == null) return '';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(ngay.day)}/${two(ngay.month)}/${ngay.year} '
        '${two(ngay.hour)}:${two(ngay.minute)}';
  }

  static DateTime _ngayGioBatBuoc(String? giaTri, String nhan) {
    final parsed = LearningPolicy.readDateTime(giaTri);
    if (parsed == null) {
      throw ArgumentError('$nhan phải theo dạng YYYY-MM-DD HH:mm.');
    }
    return parsed;
  }

  static Map<String, dynamic> toFirestore(
    Map<String, String> cacGiaTri, {
    required bool published,
    bool allowPendingExam = false,
    Map<String, dynamic>? previousCourse,
  }) {
    final withExam = cacGiaTri['learningMode'] == studyExamLabel;
    final examId = (cacGiaTri['examId'] ?? '').trim();
    if (withExam &&
        !allowPendingExam &&
        (examId.isEmpty || examId.contains('/'))) {
      throw ArgumentError('Vui lòng chọn bài kiểm tra cuối khóa.');
    }
    final scheduled = cacGiaTri['deploymentMode'] == scheduledLabel;
    DateTime? batDau;
    DateTime? ketThuc;
    if (scheduled) {
      final parsedStart = _ngayGioBatBuoc(
        cacGiaTri['startsAt'],
        'Thời gian bắt đầu',
      );
      final parsedEnd = _ngayGioBatBuoc(
        cacGiaTri['endsAt'],
        'Thời gian kết thúc',
      );
      final previousStart = LearningPolicy.readDateTime(
        previousCourse?['startsAt'],
      );
      final previousEnd = LearningPolicy.readDateTime(
        previousCourse?['endsAt'],
      );
      final unchangedStart = LearningPolicy.sameMinute(
        previousStart,
        parsedStart,
      );
      final unchangedEnd = LearningPolicy.sameMinute(previousEnd, parsedEnd);
      batDau = unchangedStart ? previousStart! : parsedStart;
      ketThuc = unchangedEnd ? previousEnd! : parsedEnd;
      if (previousCourse == null || !unchangedStart) {
        LearningPolicy.requireFutureDateTime(batDau, 'Thời gian bắt đầu');
      }
      if (previousCourse == null || !unchangedEnd) {
        LearningPolicy.requireFutureDateTime(ketThuc, 'Thời gian kết thúc');
      }
      if (!ketThuc.isAfter(batDau)) {
        throw ArgumentError('Thời gian kết thúc phải sau thời gian bắt đầu.');
      }
    }
    return {
      'title': cacGiaTri['title'],
      'subject': cacGiaTri['subject'],
      'description': cacGiaTri['description'],
      'instructor': cacGiaTri['instructor'],
      'objectives': cacGiaTri['objectives'],
      'learningMode': withExam ? 'study_exam' : 'study_only',
      'examId': withExam ? examId : '',
      'coverUrl': cacGiaTri['imageUrl'],
      'deploymentMode': scheduled ? 'scheduled' : 'manual',
      'audience': 'all',
      // Phải ghi null để xóa lịch cũ khi chuyển sang mở/đóng thủ công.
      'startsAt': batDau == null ? null : Timestamp.fromDate(batDau),
      'endsAt': ketThuc == null ? null : Timestamp.fromDate(ketThuc),
      'published': published,
    };
  }
}
