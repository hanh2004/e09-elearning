// DỮ LIỆU: Tổng hợp kết quả thi để màn hình báo cáo lọc theo đề, người học và đơn vị.
// Giữ tên trường Firebase khi đổi cách hiển thị để đọc được dữ liệu đã lưu.

import 'ket_qua_bai_kiem_tra.dart';

class AdminReportRow {
  AdminReportRow({
    required this.userId,
    required this.examId,
    required this.name,
    required this.classId,
    required this.unit,
    this.subUnit = '',
    required this.examTitle,
  });
  final String userId, examId, name, classId, unit, subUnit, examTitle;
  int attempts = 0;
  double? score;
  bool? passed;
  DateTime? submittedAt;
  DateTime? bestAt;
}

class AdminReport {
  AdminReport({
    required this.rows,
    required this.studentCount,
    required this.examCount,
  });
  final List<AdminReportRow> rows;
  final int studentCount, examCount;
  int get attempts => rows.fold(0, (sum, r) => sum + r.attempts);
  int get participants => rows.map((r) => r.userId).toSet().length;
  int get passed => rows.where((r) => r.passed == true).length;
  int get failed => rows.where((r) => r.passed == false).length;
  int get ungraded => rows.where((r) => r.score == null).length;
  double? get passRate =>
      passed + failed == 0 ? null : passed * 100 / (passed + failed);
  double? get average {
    final scored = rows.where((r) => r.score != null).toList();
    return scored.isEmpty
        ? null
        : scored.fold<double>(0, (sum, r) => sum + r.score!) / scored.length;
  }

  List<int> get distribution {
    final buckets = List.filled(5, 0);
    for (final dong in rows) {
      if (dong.score != null) buckets[(dong.score! ~/ 2).clamp(0, 4)]++;
    }
    return buckets;
  }

  List<AdminReportRow> get ranking {
    final totNhat = <String, AdminReportRow>{};
    for (final dong in rows.where((r) => r.score != null)) {
      if (dong.score! > (totNhat[dong.userId]?.score ?? -1)) {
        totNhat[dong.userId] = dong;
      }
    }
    return totNhat.values.toList()..sort((a, b) {
      final byScore = b.score!.compareTo(a.score!);
      return byScore != 0 ? byScore : a.name.compareTo(b.name);
    });
  }

  static bool matchesUser(
    String maNguoiDung,
    Map<String, dynamic> nguoiDung, {
    String? classId,
    String? unit,
    String? subUnit,
    String search = '',
  }) =>
      (classId == null || (nguoiDung['classId'] ?? '') == classId) &&
      (unit == null || (nguoiDung['unit'] ?? '') == unit) &&
      (subUnit == null || (nguoiDung['subUnit'] ?? '') == subUnit) &&
      '$maNguoiDung ${nguoiDung['name'] ?? ''} ${nguoiDung['username'] ?? ''} ${nguoiDung['unit'] ?? ''} ${nguoiDung['subUnit'] ?? ''} ${nguoiDung['subUnit'] ?? ''}-${nguoiDung['unit'] ?? ''}'
          .toLowerCase()
          .contains(search.trim().toLowerCase());

  static AdminReport build({
    required Map<String, Map<String, dynamic>> users,
    required Map<String, Map<String, dynamic>> exams,
    required List<Map<String, dynamic>> attempts,
    String? classId,
    String? examId,
    String? unit,
    String? subUnit,
    String search = '',
  }) {
    bool matches(String maNguoiDung, Map<String, dynamic> nguoiDung) =>
        matchesUser(
          maNguoiDung,
          nguoiDung,
          classId: classId,
          unit: unit,
          subUnit: subUnit,
          search: search,
        );
    final groups = <String, Map<String, AdminReportRow>>{};
    for (final duLieu in attempts) {
      final maNguoiDung = duLieu['userId']?.toString() ?? '';
      final eid = duLieu['examId']?.toString() ?? '';
      if (maNguoiDung.isEmpty ||
          eid.isEmpty ||
          (examId != null && examId != eid)) {
        continue;
      }
      final nguoiDung = users[maNguoiDung] ?? <String, dynamic>{};
      if (!matches(maNguoiDung, nguoiDung)) continue;
      final soLuong = duLieu['attemptCount'] is num
          ? (duLieu['attemptCount'] as num).toInt()
          : duLieu['status'] == 'completed'
          ? 1
          : 0;
      if (soLuong <= 0) continue;
      final dong = (groups[maNguoiDung] ??= {}).putIfAbsent(
        eid,
        () => AdminReportRow(
          userId: maNguoiDung,
          examId: eid,
          name: (nguoiDung['name'] ?? nguoiDung['username'] ?? maNguoiDung)
              .toString(),
          classId: (nguoiDung['classId'] ?? '').toString(),
          unit: (nguoiDung['unit'] ?? '').toString(),
          subUnit: (nguoiDung['subUnit'] ?? '').toString(),
          examTitle: (exams[eid]?['title'] ?? duLieu['examTitle'] ?? eid)
              .toString(),
        ),
      );
      dong.attempts += soLuong;
      final latest = duLieu['reportLastAt'] as DateTime?;
      if (latest != null &&
          (dong.submittedAt == null || latest.isAfter(dong.submittedAt!))) {
        dong.submittedAt = latest;
      }
      final giaTri = duLieu['bestScore'] ?? duLieu['diemSo'] ?? duLieu['score'];
      if (giaTri is! num || !giaTri.isFinite || giaTri < 0 || giaTri > 10) {
        continue;
      }
      final bestAt = duLieu['reportBestAt'] as DateTime?;
      if (dong.score == null ||
          giaTri > dong.score! ||
          (giaTri == dong.score &&
              bestAt != null &&
              (dong.bestAt == null || bestAt.isAfter(dong.bestAt!)))) {
        dong.score = giaTri.toDouble();
        dong.passed = ExamOutcome.passed(duLieu);
        dong.bestAt = bestAt;
      }
    }
    final cacDong = groups.values.expand((g) => g.values).toList()
      ..sort((a, b) {
        final ten = a.name.compareTo(b.name);
        return ten != 0 ? ten : a.examTitle.compareTo(b.examTitle);
      });
    return AdminReport(
      rows: cacDong,
      studentCount: users.entries
          .where((e) => e.value['role'] == 'user' && matches(e.key, e.value))
          .length,
      examCount: examId == null
          ? exams.length
          : exams.containsKey(examId)
          ? 1
          : 0,
    );
  }
}
