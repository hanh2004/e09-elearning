class ExamAttemptSession {
  final String attemptId;
  final DateTime endsAt;
  final Map<int, int> selectedAnswers;
  final int currentQuestionIndex;

  const ExamAttemptSession({
    required this.attemptId,
    required this.endsAt,
    required this.selectedAnswers,
    required this.currentQuestionIndex,
  });
}
