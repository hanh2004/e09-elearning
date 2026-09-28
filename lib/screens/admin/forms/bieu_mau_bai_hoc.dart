// WEB ADMIN: Form tạo/sửa bài học. Đổi thời lượng mặc định và giới hạn trong LessonForm.
// Sửa cấu hình form trong showLessonEditor; nhãn và kiểm tra thời lượng nằm ở LessonForm.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../models/dinh_danh_tai_khoan.dart';
import '../../../models/bieu_mau_khoa_hoc.dart';
import '../../../models/bieu_mau_bai_hoc.dart';
import '../../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../../widgets/tien_ich_giao_dien_hoc_tap.dart';

/// Form tạo/sửa bài học. Đổi thời lượng mặc định và giới hạn trong LessonForm.
Future<bool> showLessonEditor(
  BuildContext context, {
  required LearningService service,
  required QueryDocumentSnapshot<Map<String, dynamic>> course,
  QueryDocumentSnapshot<Map<String, dynamic>>? lesson,
}) async {
  final taiKhoan = AccountSession.current;
  if (taiKhoan?.isRoot != true || LearningPolicy.hasEnded(course.data())) {
    return false;
  }
  final duLieu = lesson?.data() ?? <String, dynamic>{};
  final cacTruong = LessonForm.initialValues(duLieu);
  final courseMode = CourseForm.hasExam(course.data())
      ? 'study_exam'
      : 'study_only';
  final courseExamId = course.data()['examId']?.toString() ?? '';
  cacTruong.remove('learningMode');
  cacTruong.remove('examId');
  return editLearningRecord(
    context,
    title: lesson == null ? 'Thêm bài học' : 'Sửa bài học',
    fields: cacTruong,
    labels: LessonForm.labels,
    optional: {'content', 'importantNote'},
    richTextFields: {'content'},
    note: courseMode == 'study_exam'
        ? 'Bài học tự động theo loại khóa học Học để làm bài kiểm tra. Học viên hoàn thành toàn bộ bài trong khóa rồi mới được mở đề cuối khóa.'
        : 'Bài học tự động theo loại khóa học Học để biết. Bài học chỉ dùng để học nội dung và không mở đề kiểm tra.',
    imageFolder: 'lessons/${course.id}',
    initialImage:
        duLieu['coverUrl'] ??
        (duLieu['type'] == 'image' ? (duLieu['url'] ?? '') : ''),
    imageRequired: true,
    save: (cacGiaTri) async {
      final duLieuGui = LessonForm.toFirestore(
        cacGiaTri,
        previous: duLieu,
        courseLearningMode: courseMode,
        courseExamId: courseExamId,
      );
      await service.saveContent(
        taiKhoan!.id,
        lesson?.reference ?? course.reference.collection('lessons').doc(),
        duLieuGui,
      );
    },
  );
}
