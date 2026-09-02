import 'package:flutter_test/flutter_test.dart';
import 'package:e09_elearning/models/exam_arguments.dart';
import 'package:e09_elearning/models/exam_history_arguments.dart';
import 'package:e09_elearning/models/exam_result_arguments.dart';
import 'package:e09_elearning/models/question_bank_arguments.dart';
import 'package:e09_elearning/models/user_arguments.dart';
import 'package:e09_elearning/models/cau_hoi_model.dart';

void main() {
  group('ExamArguments', () {
    test('uses sensible defaults', () {
      const args = ExamArguments(
        maBaiKiemTra: 'exam-1',
        dsMaCauHoi: ['question-1'],
        maNguoiDung: 'user-1',
      );

      expect(args.thoiGianLamBaiPhut, 45);
      expect(args.tenBaiKiemTra, 'Bài kiểm tra');
      expect(args.soLuotLamToiDa, isNull);
    });

    test('keeps values passed from an exam document', () {
      const args = ExamArguments(
        maBaiKiemTra: 'exam-2',
        dsMaCauHoi: ['question-1', 'question-2'],
        maNguoiDung: 'user-2',
        thoiGianLamBaiPhut: 60,
        tenBaiKiemTra: 'Kiểm tra cuối kỳ',
        soLuotLamToiDa: 3,
      );

      expect(args.dsMaCauHoi, hasLength(2));
      expect(args.thoiGianLamBaiPhut, 60);
      expect(args.tenBaiKiemTra, 'Kiểm tra cuối kỳ');
      expect(args.soLuotLamToiDa, 3);
    });
  });

  test('screen arguments keep navigation data', () {
    const user = UserArguments(userId: 'user-1', userName: 'An');
    const history = ExamHistoryArguments(maNguoiDung: 'user-1');
    const result = ExamResultArguments(
      diemSo: 8,
      tongSoCau: 10,
      soCauDung: 8,
      thoiGianLamBai: '12:30',
    );
    const questionBank = QuestionBankArguments(
      examId: 'exam-1',
      examTitle: 'Giữa kỳ',
    );

    expect(user.email, isEmpty);
    expect(history.maNguoiDung, user.userId);
    expect(result.soCauDung, 8);
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
