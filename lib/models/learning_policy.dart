// DỮ LIỆU: Các hàm chính sách dùng chung cho danh sách, trang chi tiết và kiểm thử.
// Giữ tên trường Firebase khi đổi cách hiển thị để đọc được dữ liệu đã lưu.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Các hàm chính sách dùng chung cho danh sách, trang chi tiết và kiểm thử.
class LearningPolicy {
  static bool requiresExam(
    Map<String, dynamic> khoaHoc,
    Map<String, dynamic> baiHoc,
  ) {
    if (khoaHoc['learningMode'] == 'study_only') return false;
    return khoaHoc['learningMode'] == 'study_exam' ||
        (khoaHoc['examId']?.toString().trim().isNotEmpty ?? false) ||
        baiHoc['learningMode'] == 'study_exam';
  }

  // Old records used completed for the reading stage as well.
  static bool hasCompletedStudy(Map<String, dynamic> mauTin) =>
      mauTin['studyCompleted'] == true || mauTin['completed'] == true;

  static bool isLessonComplete(
    Map<String, dynamic> mauTin,
    Map<String, dynamic> khoaHoc,
    Map<String, dynamic> baiHoc,
  ) {
    if (mauTin['completed'] != true) return false;
    if (!requiresExam(khoaHoc, baiHoc)) return true;
    final examId = (khoaHoc['examId'] ?? '').toString().trim();
    return mauTin['examCompleted'] == true &&
        mauTin['completedExamId'] ==
            (examId.isEmpty ? baiHoc['examId'] : examId);
  }

  /// Dữ liệu cũ chưa có deploymentMode: có ngày thì dùng lịch tự động.
  static bool isScheduled(Map<String, dynamic> khoaHoc) =>
      khoaHoc['deploymentMode'] == 'scheduled' ||
      (khoaHoc['deploymentMode'] == null &&
          (khoaHoc['startsAt'] != null || khoaHoc['endsAt'] != null));

  static bool isManual(Map<String, dynamic> khoaHoc) =>
      khoaHoc['deploymentMode'] == 'manual' ||
      (khoaHoc['deploymentMode'] == null &&
          khoaHoc['startsAt'] == null &&
          khoaHoc['endsAt'] == null);

  static bool hasEnded(Map<String, dynamic> khoaHoc, {DateTime? now}) {
    final ketThuc = readDateTime(khoaHoc['endsAt']);
    return ketThuc != null && !(now ?? DateTime.now()).isBefore(ketThuc);
  }

  static String classIdFromAudience(String? audience) =>
      audience != null && audience.startsWith('class:')
      ? audience.substring(6)
      : '';

  static DateTime? readDateTime(dynamic giaTri) {
    if (giaTri is Timestamp) return giaTri.toDate();
    if (giaTri is DateTime) return giaTri;
    if (giaTri is String && giaTri.trim().isNotEmpty) {
      return DateTime.tryParse(giaTri.trim().replaceFirst(' ', 'T'));
    }
    return null;
  }

  static String deploymentLabel(Map<String, dynamic> khoaHoc, {DateTime? now}) {
    if (hasEnded(khoaHoc, now: now)) return 'Đã triển khai';
    if (khoaHoc['published'] != true) return 'Chưa triển khai';
    final hienHanh = now ?? DateTime.now();
    final startsAt = readDateTime(khoaHoc['startsAt']);
    final endsAt = readDateTime(khoaHoc['endsAt']);
    if (startsAt != null && hienHanh.isBefore(startsAt)) {
      return 'Chưa triển khai';
    }
    if (endsAt != null && hienHanh.isAfter(endsAt)) return 'Đã triển khai';
    return 'Đang triển khai';
  }

  static bool canRead(
    Map<String, dynamic> khoaHoc,
    String classId, {
    DateTime? now,
  }) => deploymentLabel(khoaHoc, now: now) == 'Đang triển khai';

  static double completion(
    Iterable<String> cacBaiHoc,
    Iterable<String> daHoanThanh,
  ) {
    final cacMa = cacBaiHoc.toSet();
    return cacMa.isEmpty
        ? 0
        : cacMa.intersection(daHoanThanh.toSet()).length / cacMa.length;
  }

  static String? validateUrl(String giaTri) {
    if (giaTri.isEmpty) return null;
    final uri = Uri.tryParse(giaTri);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? null
        : 'Liên kết phải bắt đầu bằng https://';
  }
}
