// Màn hình kết quả và xem lại đáp án của bài kiểm tra bảo mật.
// Đây là phần riêng của lam_bai_kiem_tra_bao_mat.dart.
part of 'lam_bai_kiem_tra_bao_mat.dart';

/// Kết quả và đáp án đúng tách riêng khỏi luồng làm bài.
class SecureExamResultScreen extends StatelessWidget {
  const SecureExamResultScreen({super.key, required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final passed = result['passed'] == true;
    final score = ((result['score'] as num?) ?? 0).clamp(0, 10);
    final review = (result['review'] as List? ?? const []).whereType<Map>().map(
      (item) => Map<String, dynamic>.from(item),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: LearnerHeader(title: const Text('Kết quả bài thi')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          LearnerCard(
            accentColor: passed ? Colors.green : AppTheme.red,
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Text(
                  passed ? 'Chúc mừng bạn!' : 'Tiếp tục cố gắng!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  result['title']?.toString() ?? 'Bài thi',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: score / 10,
                          strokeWidth: 9,
                          backgroundColor: const Color(0xFFE7F0E7),
                          color: passed ? Colors.green : AppTheme.red,
                        ),
                      ),
                      Text(
                        '$score/10',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '${result['correctAnswers'] ?? 0}/${result['totalQuestions'] ?? 0} câu đúng • ${passed ? 'Đạt' : 'Chưa đạt'}',
                ),
              ],
            ),
          ),
          if (result['expired'] == true)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F3F8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Đã hết giờ. Kết quả tính từ các đáp án được máy chủ lưu trước hạn.',
                style: TextStyle(color: AppTheme.navy),
              ),
            ),
          for (final question in review)
            _QuestionReviewCard(question: question),
        ],
      ),
    );
  }
}

class _QuestionReviewCard extends StatelessWidget {
  const _QuestionReviewCard({required this.question});

  final Map<String, dynamic> question;

  @override
  Widget build(BuildContext context) {
    final options = question['options'];
    final index = question['correctIndex'];
    final answer =
        options is List && index is int && index >= 0 && index < options.length
        ? options[index].toString()
        : 'Không có dữ liệu';
    return LearnerCard(
      accentColor: AppTheme.gold,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question['title']?.toString() ?? ''),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Đáp án đúng: ',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text: answer,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          Text(question['explanation']?.toString() ?? ''),
        ],
      ),
    );
  }
}
