// DỮ LIỆU: Cấu hình trường và quy tắc nhập bài học; không phụ thuộc màn hình hay Firebase.
// Giữ tên trường Firebase khi đổi cách hiển thị để đọc được dữ liệu đã lưu.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Cấu hình trường và quy tắc nhập bài học; không phụ thuộc màn hình hay Firebase.
class LessonForm {
  static const studyOnlyLabel = 'Chỉ học';
  static const studyExamLabel = 'Học xong kiểm tra ngay';
  static bool hasExam(Map<String, dynamic> duLieu) {
    if (duLieu['learningMode'] == 'study_only') return false;
    return duLieu['learningMode'] == 'study_exam' ||
        (duLieu['examId']?.toString().trim().isNotEmpty ?? false);
  }

  static String modeLabel(Map<String, dynamic> duLieu) =>
      hasExam(duLieu) ? studyExamLabel : studyOnlyLabel;
  static const defaultStudySeconds = 300;
  static const minStudySeconds = 1;
  static const maxStudySeconds = 86400;

  static const labels = {
    'title': 'Tên bài học',
    'order': 'Số thứ tự bài học',
    'learningMode': 'Loại bài học',
    'examId': 'Bài kiểm tra sau khi học',
    'minimumStudySeconds': 'Thời gian học tối thiểu từng bài (giây)',
    'content': 'Nội dung bài học',
    'importantNote': 'Lưu ý quan trọng',
  };

  static Map<String, String> initialValues(Map<String, dynamic> duLieu) => {
    'title': duLieu['title'] ?? '',
    'order': '${duLieu['order'] ?? 1}',
    'learningMode': modeLabel(duLieu),
    'examId': duLieu['examId'] ?? '',
    'minimumStudySeconds':
        '${(duLieu['minimumStudySeconds'] as num? ?? defaultStudySeconds).toInt()}',
    'content': duLieu['content'] ?? '',
    'importantNote': duLieu['importantNote'] ?? '',
  };

  static Map<String, dynamic> toFirestore(
    Map<String, String> cacGiaTri, {
    required Map<String, dynamic> previous,
    String? courseLearningMode,
    String? courseExamId,
  }) {
    final orderText = cacGiaTri['order'];
    final order = orderText == null
        ? int.tryParse('${previous['order'] ?? 1}') ?? 1
        : int.tryParse(orderText);
    final soGiay = int.tryParse(cacGiaTri['minimumStudySeconds'] ?? '');
    if (soGiay == null ||
        soGiay < minStudySeconds ||
        soGiay > maxStudySeconds) {
      throw ArgumentError(
        'Thời gian học phải từ $minStudySeconds đến $maxStudySeconds giây.',
      );
    }
    if (order == null || order < 0) {
      throw ArgumentError('Dữ liệu không hợp lệ');
    }
    final imageUrl = cacGiaTri['imageUrl'] ?? '';
    final inheritedCourseMode =
        courseLearningMode == 'study_only' ||
        courseLearningMode == 'study_exam';
    final withExam = inheritedCourseMode
        ? courseLearningMode == 'study_exam'
        : cacGiaTri['learningMode'] == studyExamLabel;
    final examId = inheritedCourseMode
        ? (courseExamId ?? '').trim()
        : (cacGiaTri['examId'] ?? '').trim();
    final canAddCourseExamLater =
        courseLearningMode == 'study_exam' && examId.isEmpty;
    if (withExam &&
        !canAddCourseExamLater &&
        (examId.isEmpty || examId.contains('/'))) {
      throw ArgumentError('Vui lòng chọn bài kiểm tra sau khi học.');
    }
    final type = previous['type'] ?? 'text';
    if (type == 'text' &&
        (cacGiaTri['content'] ?? '').isEmpty &&
        imageUrl.isEmpty) {
      throw ArgumentError('Thiếu nội dung');
    }
    return {
      'title': cacGiaTri['title'],
      'learningMode': withExam ? 'study_exam' : 'study_only',
      'examId': withExam ? examId : '',
      'chapter': FieldValue.delete(),
      'order': order,
      'minimumStudySeconds': soGiay,
      'content': cacGiaTri['content'],
      'contentFormat': 'rich_text_v1',
      'importantNote': cacGiaTri['importantNote'],
      'coverUrl': imageUrl,
      // Giữ loại và liên kết của bài cũ khi chỉ sửa nội dung.
      'type': type,
      'url': previous['url'] ?? '',
    };
  }
}
