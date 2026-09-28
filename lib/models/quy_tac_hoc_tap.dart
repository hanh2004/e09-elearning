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
    if (isNotLaunched(khoaHoc, now: now)) return false;
    final ketThuc = readDateTime(khoaHoc['endsAt']);
    return ketThuc != null && !(now ?? DateTime.now()).isBefore(ketThuc);
  }

  /// Khóa chưa xuất bản hoặc chưa đến lịch bắt đầu được xem là bản nháp.
  static bool isNotLaunched(Map<String, dynamic> khoaHoc, {DateTime? now}) {
    if (khoaHoc['published'] != true) return true;
    final phatHanhLuc = readDateTime(khoaHoc['publishedAt']);
    if (phatHanhLuc != null && (now ?? DateTime.now()).isBefore(phatHanhLuc)) {
      return true;
    }
    final batDau = readDateTime(khoaHoc['startsAt']);
    return batDau != null && (now ?? DateTime.now()).isBefore(batDau);
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

  /// Sort lessons locally so older records without an `order` field stay visible.
  static List<QueryDocumentSnapshot<Map<String, dynamic>>> sortLessons(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> lessons,
  ) {
    final result = lessons.toList();
    result.sort((first, second) {
      double lessonOrder(QueryDocumentSnapshot<Map<String, dynamic>> lesson) {
        final rawOrder = lesson.data()['order'];
        return rawOrder is num
            ? rawOrder.toDouble()
            : double.tryParse(rawOrder?.toString() ?? '') ?? double.infinity;
      }

      final firstOrder = lessonOrder(first);
      final secondOrder = lessonOrder(second);
      final byOrder = firstOrder.compareTo(secondOrder);
      return byOrder != 0 ? byOrder : first.id.compareTo(second.id);
    });
    return result;
  }

  /// Thời điểm mặc định cho các lịch mới, làm tròn lên phút kế tiếp.
  static DateTime nextFutureMinute({DateTime? now}) {
    final current = now ?? DateTime.now();
    return DateTime(
      current.year,
      current.month,
      current.day,
      current.hour,
      current.minute,
    ).add(const Duration(minutes: 1));
  }

  /// Đọc và xác nhận một thời điểm mới phải nằm sau thời điểm hiện tại.
  static DateTime requireFutureDateTime(
    dynamic value,
    String label, {
    DateTime? now,
  }) {
    final parsed = readDateTime(value);
    if (parsed == null) {
      throw ArgumentError('$label không hợp lệ.');
    }
    if (!parsed.isAfter(now ?? DateTime.now())) {
      throw ArgumentError('$label phải sau thời điểm hiện tại.');
    }
    return parsed;
  }

  static bool sameMinute(DateTime? first, DateTime? second) =>
      first != null &&
      second != null &&
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day &&
      first.hour == second.hour &&
      first.minute == second.minute;

  static String deploymentLabel(Map<String, dynamic> khoaHoc, {DateTime? now}) {
    if (isNotLaunched(khoaHoc, now: now)) return 'Chưa triển khai';
    if (hasEnded(khoaHoc, now: now)) return 'Đã triển khai';
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

/// Loại khóa nháp khỏi thống kê bài thi và lượt làm bài.
class LearningContentVisibility {
  LearningContentVisibility._({
    required this.notLaunchedCourseIds,
    required this.notLaunchedExamIds,
  });

  final Set<String> notLaunchedCourseIds;
  final Set<String> notLaunchedExamIds;

  factory LearningContentVisibility.fromDocuments({
    required Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> courses,
    required Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> exams,
    DateTime? now,
  }) {
    final notLaunchedCourses = courses
        .where(
          (course) => LearningPolicy.isNotLaunched(course.data(), now: now),
        )
        .toList();
    final notLaunchedCourseIds = notLaunchedCourses
        .map((course) => course.id)
        .toSet();
    final notLaunchedExamIds = <String>{
      for (final course in notLaunchedCourses)
        if ((course.data()['examId']?.toString().trim() ?? '').isNotEmpty)
          course.data()['examId'].toString().trim(),
      for (final exam in exams)
        if (notLaunchedCourseIds.contains(exam.data()['courseId']?.toString()))
          exam.id,
    };
    return LearningContentVisibility._(
      notLaunchedCourseIds: notLaunchedCourseIds,
      notLaunchedExamIds: notLaunchedExamIds,
    );
  }

  bool includesCourse(QueryDocumentSnapshot<Map<String, dynamic>> course) =>
      !notLaunchedCourseIds.contains(course.id);

  bool includesExam(QueryDocumentSnapshot<Map<String, dynamic>> exam) =>
      !notLaunchedExamIds.contains(exam.id) &&
      !notLaunchedCourseIds.contains(exam.data()['courseId']?.toString());

  bool includesAttempt(QueryDocumentSnapshot<Map<String, dynamic>> attempt) =>
      !notLaunchedCourseIds.contains(attempt.data()['courseId']?.toString()) &&
      !notLaunchedExamIds.contains(attempt.data()['examId']?.toString());
}
