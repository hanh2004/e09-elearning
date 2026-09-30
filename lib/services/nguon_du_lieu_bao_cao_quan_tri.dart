import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/quy_tac_hoc_tap.dart';
import 'du_lieu/dich_vu_firestore.dart';

/// Bộ dữ liệu báo cáo đã áp dụng chung quy tắc ẩn nội dung chưa phát hành.
class AdminReportData {
  AdminReportData._({
    required this.usersSnapshot,
    required this.coursesSnapshot,
    required this.visibleCourses,
    required this.visibleExams,
    required this.visibleAttempts,
  });

  factory AdminReportData.fromSnapshots({
    required QuerySnapshot<Map<String, dynamic>> users,
    required QuerySnapshot<Map<String, dynamic>> courses,
    required QuerySnapshot<Map<String, dynamic>> exams,
    required QuerySnapshot<Map<String, dynamic>> attempts,
  }) {
    final visibility = LearningContentVisibility.fromDocuments(
      courses: courses.docs,
      exams: exams.docs,
    );
    return AdminReportData._(
      usersSnapshot: users,
      coursesSnapshot: courses,
      visibleCourses: courses.docs.where(visibility.includesCourse).toList(),
      visibleExams: exams.docs.where(visibility.includesExam).toList(),
      visibleAttempts: attempts.docs.where(visibility.includesAttempt).toList(),
    );
  }

  final QuerySnapshot<Map<String, dynamic>> usersSnapshot;
  final QuerySnapshot<Map<String, dynamic>> coursesSnapshot;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> visibleCourses;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> visibleExams;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> visibleAttempts;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get users =>
      usersSnapshot.docs;

  /// Tiến độ bài học chỉ cần tải lại khi danh sách học viên hoặc khóa học đổi.
  bool hasSameLearningInputs(AdminReportData other) =>
      identical(usersSnapshot, other.usersSnapshot) &&
      identical(coursesSnapshot, other.coursesSnapshot);
}

/// Mở một bộ luồng chung để các tab báo cáo dùng cùng snapshot và bộ lọc quyền.
class AdminReportDataSource {
  AdminReportDataSource({FirestoreService? service})
    : service = service ?? FirestoreService();

  final FirestoreService service;

  Stream<AdminReportData> watch() =>
      Stream<AdminReportData>.multi((controller) {
        QuerySnapshot<Map<String, dynamic>>? users;
        QuerySnapshot<Map<String, dynamic>>? courses;
        QuerySnapshot<Map<String, dynamic>>? exams;
        QuerySnapshot<Map<String, dynamic>>? attempts;
        final subscriptions = <StreamSubscription<dynamic>>[];

        void publishWhenReady() {
          if (users == null ||
              courses == null ||
              exams == null ||
              attempts == null) {
            return;
          }
          controller.add(
            AdminReportData.fromSnapshots(
              users: users!,
              courses: courses!,
              exams: exams!,
              attempts: attempts!,
            ),
          );
        }

        void bind<T>(
          Stream<T> stream,
          void Function(T value) update,
        ) => subscriptions.add(
          stream.listen((value) {
            update(value);
            publishWhenReady();
          }, onError: controller.addError),
        );

        bind(service.getUsersStream(), (value) => users = value);
        bind(service.db.collection('courses').snapshots(), (value) => courses = value);
        bind(service.getExamsStream(), (value) => exams = value);
        bind(service.getExamAttemptsStream(), (value) => attempts = value);

        controller.onCancel = () async {
          await Future.wait(
            subscriptions.map((subscription) => subscription.cancel()),
          );
        };
      });
}
