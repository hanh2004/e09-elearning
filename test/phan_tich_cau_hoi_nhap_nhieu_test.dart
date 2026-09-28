import 'package:e09_elearning/services/nghiep_vu/phan_tich_cau_hoi_nhap_nhieu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BoPhanTichCauHoi', () {
    test('returns an empty result for blank input', () {
      final result = BoPhanTichCauHoi.parse('  \n  ');

      expect(result.questions, isEmpty);
      expect(result.errors, isEmpty);
    });

    test('parses tab-separated rows with an optional header', () {
      final result = BoPhanTichCauHoi.parse(
        'Question\tA\tB\tC\tD\tAnswer\tExplanation\n'
        'Thủ đô Việt Nam?\tHà Nội\tHuế\tĐà Nẵng\tCần Thơ\tA\tĐáp án đúng',
      );

      expect(result.errors, isEmpty);
      expect(result.questions, hasLength(1));
      expect(result.questions.single.toMap(), {
        'questionText': 'Thủ đô Việt Nam?',
        'options': ['Hà Nội', 'Huế', 'Đà Nẵng', 'Cần Thơ'],
        'correctAnswerIndex': 0,
        'explanation': 'Đáp án đúng',
      });
    });

    test('parses multiline blocks and numbered correct answers', () {
      final result = BoPhanTichCauHoi.parse('''
Câu hỏi: 2 + 2 bằng bao nhiêu?
A. 3
B. 4
C. 5
D. 6
Đáp án: 2
Giải thích: Phép cộng cơ bản.
Dòng giải thích thứ hai.
''');

      expect(result.errors, isEmpty);
      expect(result.questions.single.correctAnswerIndex, 1);
      expect(
        result.questions.single.explanation,
        'Phép cộng cơ bản.\nDòng giải thích thứ hai.',
      );
    });

    test('reports missing options and invalid correct answers', () {
      final result = BoPhanTichCauHoi.parse('''
Câu hỏi: Câu chưa đủ dữ liệu
A. Một
C. Ba
D. Bốn
Đáp án: Z
''');

      expect(result.questions, isEmpty);
      expect(result.errors, contains('Câu 1 thiếu đáp án B.'));
      expect(
        result.errors,
        contains('Câu 1 cần ghi đáp án đúng A, B, C hoặc D.'),
      );
    });
  });
}
