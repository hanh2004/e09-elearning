import 'package:flutter_test/flutter_test.dart';
import 'package:e09_elearning/models/tham_so_ngan_hang_cau_hoi.dart';
import 'package:e09_elearning/models/tham_so_nguoi_dung.dart';
import 'package:e09_elearning/models/mo_hinh_cau_hoi.dart';

void main() {
  test('screen arguments keep navigation data', () {
    const user = UserArguments(userId: 'user-1', userName: 'An');
    const questionBank = QuestionBankArguments(
      examId: 'exam-1',
      examTitle: 'Giữa kỳ',
    );

    expect(user.email, isEmpty);
    expect(questionBank.examTitle, 'Giữa kỳ');
  });

  group('CauHoiModel', () {
    test('reads question created by the admin screen', () {
      final question = CauHoiModel.fromMap({
        'questionText': '2 + 2 = ?',
        'options': ['2', '3', '4', '5'],
        'correctAnswerIndex': 2,
      }, 'question-1');

      expect(question.noiDung, '2 + 2 = ?');
      expect(question.dsLuaChon, hasLength(4));
      expect(question.dsLuaChon[2].dapAnDung, isTrue);
    });

    test('reads legacy string answers', () {
      final question = CauHoiModel.fromMap({
        'content': 'Thủ đô Việt Nam?',
        'answers': ['Đà Nẵng', 'Hà Nội'],
        'correctAnswer': 'Hà Nội',
      }, 'question-2');

      expect(question.noiDung, 'Thủ đô Việt Nam?');
      expect(question.dsLuaChon[1].dapAnDung, isTrue);
    });
  });
}
