import 'exam_outcome.dart';

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
    for (final row in rows) {
      if (row.score != null) buckets[(row.score! ~/ 2).clamp(0, 4)]++;
    }
    return buckets;
  }

  List<AdminReportRow> get ranking {
    final best = <String, AdminReportRow>{};
    for (final row in rows.where((r) => r.score != null)) {
      if (row.score! > (best[row.userId]?.score ?? -1)) best[row.userId] = row;
    }
    return best.values.toList()..sort((a, b) {
      final byScore = b.score!.compareTo(a.score!);
      return byScore != 0 ? byScore : a.name.compareTo(b.name);
    });
  }

  static AdminReport build({
    required Map<String, Map<String, dynamic>> users,
    required Map<String, Map<String, dynamic>> exams,
    required List<Map<String, dynamic>> attempts,
    String? classId,
    String? examId,
    String? unit,
    String search = '',
  }) {
    final query = search.trim().toLowerCase();
    bool matches(String uid, Map<String, dynamic> user) =>
        (classId == null || (user['classId'] ?? '') == classId) &&
        (unit == null || (user['unit'] ?? '') == unit) &&
        '$uid ${user['name'] ?? ''} ${user['username'] ?? ''} ${user['unit'] ?? ''} ${user['subUnit'] ?? ''} ${user['subUnit'] ?? ''}-${user['unit'] ?? ''}'
            .toLowerCase()
            .contains(query);
    final groups = <String, Map<String, AdminReportRow>>{};
    for (final data in attempts) {
      final uid = data['userId']?.toString() ?? '';
      final eid = data['examId']?.toString() ?? '';
      if (uid.isEmpty || eid.isEmpty || (examId != null && examId != eid)) {
        continue;
      }
      final user = users[uid] ?? <String, dynamic>{};
      if (!matches(uid, user)) continue;
      final count = data['attemptCount'] is num
          ? (data['attemptCount'] as num).toInt()
          : data['status'] == 'completed'
          ? 1
          : 0;
      if (count <= 0) continue;
      final row = (groups[uid] ??= {}).putIfAbsent(
        eid,
        () => AdminReportRow(
          userId: uid,
          examId: eid,
          name: (user['name'] ?? user['username'] ?? uid).toString(),
          classId: (user['classId'] ?? '').toString(),
          unit: (user['unit'] ?? '').toString(),
          subUnit: (user['subUnit'] ?? '').toString(),
          examTitle: (exams[eid]?['title'] ?? data['examTitle'] ?? eid)
              .toString(),
        ),
      );
      row.attempts += count;
      final latest = data['reportLastAt'] as DateTime?;
      if (latest != null &&
          (row.submittedAt == null || latest.isAfter(row.submittedAt!))) {
        row.submittedAt = latest;
      }
      final value = data['bestScore'] ?? data['diemSo'] ?? data['score'];
      if (value is! num || !value.isFinite || value < 0 || value > 10) continue;
      final bestAt = data['reportBestAt'] as DateTime?;
      if (row.score == null ||
          value > row.score! ||
          (value == row.score &&
              bestAt != null &&
              (row.bestAt == null || bestAt.isAfter(row.bestAt!)))) {
        row.score = value.toDouble();
        row.passed = ExamOutcome.passed(data);
        row.bestAt = bestAt;
      }
    }
    final rows = groups.values.expand((g) => g.values).toList()
      ..sort((a, b) {
        final name = a.name.compareTo(b.name);
        return name != 0 ? name : a.examTitle.compareTo(b.examTitle);
      });
    return AdminReport(
      rows: rows,
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
