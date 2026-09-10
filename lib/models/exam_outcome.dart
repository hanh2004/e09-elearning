class ExamOutcome {
  static double score(Map<String, dynamic> value) =>
      ((value['bestScore'] ?? value['diemSo'] ?? value['score']) as num?)
          ?.toDouble() ??
      0;

  // Old records predate configurable pass scores and used 5/10.
  static bool passed(Map<String, dynamic> value) => value['passed'] is bool
      ? value['passed'] as bool
      : score(value) >= ((value['passScore'] as num?)?.toDouble() ?? 5);
}
