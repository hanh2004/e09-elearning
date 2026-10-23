// DỮ LIỆU: Tính báo cáo hoàn thành khóa học theo học viên và đơn vị.
// Giữ tên trường Firebase khi đổi cách hiển thị để đọc được dữ liệu đã lưu.

import 'quy_tac_hoc_tap.dart';

class CourseCompletionRow {
  const CourseCompletionRow({
    required this.id,
    required this.name,
    required this.unit,
    required this.subUnit,
    required this.completed,
    required this.total,
    required this.started,
  });
  final String id, name, unit, subUnit;
  final int completed, total;
  final bool started;
  bool get done => total > 0 && completed == total;
  String get status => done
      ? 'Đã hoàn thành'
      : started
      ? 'Học chưa xong'
      : 'Chưa học';
}

class CourseCompletionReport {
  const CourseCompletionReport(this.rows);
  final List<CourseCompletionRow> rows;
  int get completed => rows.where((r) => r.done).length;
  int get incomplete => rows.length - completed;

  static CourseCompletionReport build({
    required Map<String, Map<String, dynamic>> users,
    required Set<String> lessonIds,
    required Map<String, List<Map<String, dynamic>>> progress,
    required String courseId,
    required DateTime endsAt,
    Map<String, dynamic> course = const {},
    Map<String, Map<String, dynamic>> lessons = const {},
    String? ownerId,
  }) {
    final courseEnd = LearningPolicy.readDateTime(course['endsAt']);
    final cutoff = courseEnd != null && courseEnd.isBefore(endsAt)
        ? courseEnd
        : endsAt;
    final cacDong = <CourseCompletionRow>[];
    for (final capDuLieu in users.entries) {
      final nguoiDung = capDuLieu.value;
      if (nguoiDung['role'] != 'user' || nguoiDung['status'] == 'deleted') {
        continue;
      }
      if (ownerId != null && nguoiDung['createdBy'] != ownerId) continue;
      final created = LearningPolicy.readDateTime(nguoiDung['createdAt']);
      if (created != null && !created.isBefore(cutoff)) continue;
      final cacMauTin = (progress[capDuLieu.key] ?? []).where(
        (p) => p['courseId'] == courseId && lessonIds.contains(p['lessonId']),
      );
      final daHoanThanh = cacMauTin
          .where((p) {
            final at = LearningPolicy.readDateTime(p['completedAt']);
            return LearningPolicy.isLessonComplete(
                  p,
                  course,
                  lessons[p['lessonId']] ?? {},
                ) &&
                at != null &&
                (at.isBefore(cutoff) ||
                    (p['examCompleted'] == true &&
                        at.isAtSameMomentAs(cutoff)));
          })
          .map((p) => p['lessonId'])
          .toSet()
          .length;
      final chuSoHuu = users[nguoiDung['createdBy']];
      final donVi = (chuSoHuu?['unit'] ?? nguoiDung['unit'] ?? '')
          .toString()
          .trim();
      cacDong.add(
        CourseCompletionRow(
          id: capDuLieu.key,
          name: (nguoiDung['name'] ?? nguoiDung['username'] ?? capDuLieu.key)
              .toString(),
          unit: donVi.isEmpty ? 'Chưa phân đơn vị' : donVi,
          subUnit: (nguoiDung['subUnit'] ?? '').toString(),
          completed: daHoanThanh,
          total: lessonIds.length,
          started:
              cacMauTin.any((p) {
                final at = LearningPolicy.readDateTime(p['startedAt']);
                return at != null && at.isBefore(cutoff);
              }) ||
              daHoanThanh > 0,
        ),
      );
    }
    cacDong.sort((a, b) => a.name.compareTo(b.name));
    return CourseCompletionReport(cacDong);
  }
}
