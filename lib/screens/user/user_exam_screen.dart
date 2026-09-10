import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/cau_hoi_model.dart';
import '../../models/cau_tra_loi_model.dart';
import '../../models/exam_arguments.dart';
import '../../services/firestore_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/option_item.dart';
import 'user_result_screen.dart';
import '../../models/exam_result_arguments.dart';

class UserExamScreen extends StatefulWidget {
  final ExamArguments args;

  const UserExamScreen({super.key, required this.args});

  @override
  State<UserExamScreen> createState() => _UserExamScreenState();
}

class ExamColors {
  static const Color primary = Color(0xFFB51F24);
  static const Color scaffoldBackground = Color(0xFFF5F5F5);

  // Nút số thứ tự câu hỏi
  static Color numberBtnDefault = Colors.grey[300]!;
  static const Color numberBtnActive = Color(0xFFB51F24);
  static const Color numberBtnAnswered = Colors.green;

  // Trạng thái đồng hồ
  static Color timerUrgent = Colors.red.withAlpha(200);
  static Color timerNormal = Colors.white.withAlpha(40);

  // Khác
  static const Color submitButton = Colors.green;
  static const Color warningMessage = Colors.orange;
  static const Color textDark = Colors.black87;
}

class _UserExamScreenState extends State<UserExamScreen>
    with WidgetsBindingObserver {
  final FirestoreService _firestoreService = FirestoreService();

  List<CauHoiModel> _dsCauHoi = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;
  int _currentQuestionIndex = 0;
  String? _maLuot;
  final Map<int, int> _selectedAnswers = {};

  Timer? _timer;
  DateTime? _endsAt;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remainingSeconds = widget.args.thoiGianLamBaiPhut * 60;
    _initExamData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_saveProgress());
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_saveProgress());
    } else if (state == AppLifecycleState.resumed) {
      _updateRemainingTime();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _updateRemainingTime();
    if (_remainingSeconds <= 0) {
      unawaited(_xuLyTuDongNopBai());
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      _updateRemainingTime();
      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        unawaited(_xuLyTuDongNopBai());
      }
    });
  }

  void _updateRemainingTime() {
    if (_endsAt == null) return;
    final seconds = _endsAt!.difference(DateTime.now()).inSeconds;
    if (mounted) {
      setState(() => _remainingSeconds = seconds > 0 ? seconds : 0);
    } else {
      _remainingSeconds = seconds > 0 ? seconds : 0;
    }
  }

  Future<void> _saveProgress() async {
    final attemptId = _maLuot;
    if (attemptId == null || _isSubmitting) return;
    try {
      await _firestoreService.saveAttemptProgress(
        attemptId: attemptId,
        selectedAnswers: Map<int, int>.from(_selectedAnswers),
        currentQuestionIndex: _currentQuestionIndex,
      );
    } catch (_) {
      // Firestore tự xếp hàng ghi offline và đồng bộ lại khi có mạng.
    }
  }

  void _goToQuestion(int index) {
    setState(() => _currentQuestionIndex = index);
    unawaited(_saveProgress());
  }

  void _selectAnswer(int optionIndex) {
    if (_isLoading ||
        _isSubmitting ||
        _maLuot == null ||
        _remainingSeconds <= 0) {
      return;
    }
    setState(() {
      _selectedAnswers[_currentQuestionIndex] = optionIndex;
    });
    unawaited(_saveProgress());
  }

  String get _formattedTime {
    int minutes = _remainingSeconds ~/ 60;
    int seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _initExamData() async {
    try {
      final loadedQuestions = widget.args.questions.isNotEmpty
          ? widget.args.questions
          : await _firestoreService.getQuestionsForExam(
              widget.args.maBaiKiemTra,
            );
      final questions = loadedQuestions
          .where((question) => question.isValidForExam)
          .toList();

      if (questions.length != loadedQuestions.length) {
        throw StateError(
          'Đề có câu hỏi chưa hợp lệ hoặc chưa hỗ trợ. Vui lòng liên hệ giáo viên để kiểm tra đề.',
        );
      }

      if (!mounted) return;
      setState(() {
        _dsCauHoi = questions;
        _isLoading = questions.isNotEmpty;
      });

      if (questions.isEmpty) return;

      try {
        var session = await _firestoreService.getOrCreateAttempt(
          userId: widget.args.maNguoiDung,
          examId: widget.args.maBaiKiemTra,
          durationMinutes: widget.args.thoiGianLamBaiPhut,
          maxAttempts: widget.args.soLuotLamToiDa,
        );
        if (!session.endsAt.isAfter(DateTime.now())) {
          final expiredResult = _gradeAnswers(
            questions,
            session.selectedAnswers,
          );
          await _firestoreService.submitExam(
            maLuot: session.attemptId,
            diemSo: expiredResult.score,
            dsCauTraLoi: expiredResult.answers,
            examTitle: widget.args.tenBaiKiemTra,
            correctAnswers: expiredResult.correctAnswers,
            totalQuestions: questions.length,
          );
          session = await _firestoreService.getOrCreateAttempt(
            userId: widget.args.maNguoiDung,
            examId: widget.args.maBaiKiemTra,
            durationMinutes: widget.args.thoiGianLamBaiPhut,
            maxAttempts: widget.args.soLuotLamToiDa,
          );
        }
        _maLuot = session.attemptId;
        _endsAt = session.endsAt;
        for (final answer in session.selectedAnswers.entries) {
          _selectedAnswers.putIfAbsent(answer.key, () => answer.value);
        }
        if (session.currentQuestionIndex >= 0 &&
            session.currentQuestionIndex < questions.length) {
          _currentQuestionIndex = session.currentQuestionIndex;
        }
        if (mounted) {
          setState(() {
            _loadError = null;
            _isLoading = false;
          });
          await _saveProgress();
          _startTimer();
        }
      } catch (error) {
        if (!mounted) return;
        final errorText = _readableError(error);
        setState(() {
          _loadError = errorText;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorText)));
      }
    } catch (e) {
      if (mounted) {
        final errorText = _readableError(e);
        setState(() {
          _isLoading = false;
          _loadError = errorText;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorText)));
      }
    }
  }

  String _readableError(Object error) {
    if (error is StateError) return error.message.toString();
    if (error.toString().contains('permission-denied')) {
      return 'Không có quyền đọc câu hỏi hoặc lượt làm bài trên Firestore.';
    }
    return 'Không thể tải bài thi: $error';
  }

  void _retryPrepareAttempt() {
    setState(() {
      _loadError = null;
      _isLoading = false;
    });
    unawaited(_initExamData());
  }

  Future<void> _xuLyTuDongNopBai() async {
    if (_isSubmitting) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hết thời gian làm bài! Hệ thống đang tự động nộp bài...',
          ),
          backgroundColor: ExamColors.warningMessage,
          duration: Duration(seconds: 3),
        ),
      );
    }
    await _xuLyNopBai();
  }

  Future<void> _xuLyNopBai() async {
    if (_maLuot == null || _isSubmitting) return;

    _timer?.cancel();
    if (mounted) {
      setState(() => _isSubmitting = true);
    }

    final result = _gradeAnswers(_dsCauHoi, _selectedAnswers);

    try {
      await _firestoreService.submitExam(
        maLuot: _maLuot!,
        diemSo: result.score,
        dsCauTraLoi: result.answers,
        examTitle: widget.args.tenBaiKiemTra,
        correctAnswers: result.correctAnswers,
        totalQuestions: _dsCauHoi.length,
      );

      if (mounted) {
        final elapsed = widget.args.thoiGianLamBaiPhut * 60 - _remainingSeconds;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => UserResultScreen(
              args: ExamResultArguments(
                diemSo: result.score,
                tongSoCau: _dsCauHoi.length,
                soCauDung: result.correctAnswers,
                thoiGianLamBai:
                    '${(elapsed ~/ 60).toString().padLeft(2, '0')}:${(elapsed % 60).toString().padLeft(2, '0')}',
              ),
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (_remainingSeconds > 0) _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể nộp bài. Vui lòng thử lại: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  ({int correctAnswers, double score, List<CauTraLoiModel> answers})
  _gradeAnswers(List<CauHoiModel> questions, Map<int, int> selectedAnswers) {
    var correctAnswers = 0;
    final answers = <CauTraLoiModel>[];

    for (var index = 0; index < questions.length; index++) {
      final question = questions[index];
      final selectedIndex = selectedAnswers[index];
      final hasValidSelection =
          selectedIndex != null &&
          selectedIndex >= 0 &&
          selectedIndex < question.dsLuaChon.length;
      final selectedOption = hasValidSelection
          ? question.dsLuaChon[selectedIndex]
          : null;
      final isCorrect = selectedOption?.dapAnDung == true;
      if (isCorrect) correctAnswers++;

      answers.add(
        CauTraLoiModel(
          maCauTraLoi: '',
          maCauHoi: question.maCauHoi,
          maLuaChon: selectedOption?.maLuaChon,
          noiDungTraLoi: null,
          traLoiDung: isCorrect,
          diemDatDuoc: isCorrect && questions.isNotEmpty
              ? 10.0 / questions.length
              : 0,
        ),
      );
    }

    return (
      correctAnswers: correctAnswers,
      score: questions.isEmpty ? 0 : correctAnswers / questions.length * 10,
      answers: answers,
    );
  }

  void _showSubmitDialog() {
    final answeredCount = _selectedAnswers.length;
    final totalCount = _dsCauHoi.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận nộp bài'),
        content: Text(
          'Bạn đã hoàn thành $answeredCount/$totalCount câu hỏi.\nBạn có chắc chắn muốn nộp bài thi ngay bây giờ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tiếp tục làm'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ExamColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _xuLyNopBai();
            },
            child: const Text('Nộp bài ngay'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: ExamColors.primary,
          title: const Text('Đang tải bài thi...'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_dsCauHoi.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: ExamColors.primary,
          title: const Text('Thông báo'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _loadError == null
                      ? Icons.quiz_outlined
                      : Icons.error_outline,
                  size: 48,
                  color: _loadError == null ? Colors.grey : Colors.red,
                ),
                const SizedBox(height: 12),
                Text(
                  _loadError == null
                      ? 'Bài thi chưa có câu hỏi nào.'
                      : _loadError!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Exam ID: ${widget.args.maBaiKiemTra}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentQuestion = _dsCauHoi[_currentQuestionIndex];

    return Scaffold(
      backgroundColor: ExamColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: ExamColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Bài kiểm tra',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _remainingSeconds < 300
                  ? ExamColors.timerUrgent
                  : ExamColors.timerNormal,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  _formattedTime,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isSubmitting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang nộp bài... Vui lòng chờ!'),
                ],
              ),
            )
          : Column(
              children: [
                if (_maLuot == null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: _loadError == null
                        ? Colors.blue[50]
                        : Colors.red[50],
                    child: Row(
                      children: [
                        if (_loadError == null)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 18,
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _loadError ?? 'Đang chuẩn bị lượt làm bài...',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        if (_loadError != null)
                          TextButton(
                            onPressed: _retryPrepareAttempt,
                            child: const Text('Thử lại'),
                          ),
                      ],
                    ),
                  ),
                // Thanh danh sách câu hỏi nằm ngang
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _dsCauHoi.length,
                      itemBuilder: (context, index) {
                        final isSelected = index == _currentQuestionIndex;
                        final isAnswered = _selectedAnswers.containsKey(index);

                        Color borderBgColor = ExamColors.numberBtnDefault;
                        Color textColor = ExamColors.textDark;

                        if (isSelected) {
                          borderBgColor = ExamColors.numberBtnActive;
                          textColor = Colors.white;
                        } else if (isAnswered) {
                          borderBgColor = ExamColors.numberBtnAnswered;
                          textColor = Colors.white;
                        }

                        return GestureDetector(
                          onTap: () {
                            _goToQuestion(index);
                          },
                          child: Container(
                            width: 40,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: borderBgColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Nội dung câu hỏi & các lựa chọn
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Câu ${_currentQuestionIndex + 1}: ${currentQuestion.noiDung}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ...List.generate(currentQuestion.dsLuaChon.length, (
                          optIndex,
                        ) {
                          final isSelectedOption =
                              _selectedAnswers[_currentQuestionIndex] ==
                              optIndex;

                          return OptionItem(
                            indexLabel: String.fromCharCode(65 + optIndex),
                            text: currentQuestion.dsLuaChon[optIndex].noiDung,
                            isSelected: isSelectedOption,
                            onTap: () {
                              _selectAnswer(optIndex);
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                // Thanh điều hướng đáy màn hình
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: _buildNavigationActions(),
                ),
              ],
            ),
    );
  }

  Widget _buildNavigationActions() {
    Widget previousButton() => OutlinedButton.icon(
      onPressed: _currentQuestionIndex > 0
          ? () => _goToQuestion(_currentQuestionIndex - 1)
          : null,
      icon: const Icon(Icons.arrow_back),
      label: const Text('Câu trước'),
    );

    Widget submitButton() => CustomButton(
      text: _maLuot == null ? 'Đang chuẩn bị...' : 'Nộp bài',
      onPressed: _maLuot == null ? null : _showSubmitDialog,
      backgroundColor: ExamColors.submitButton,
    );

    Widget nextButton() => ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: ExamColors.primary,
        foregroundColor: Colors.white,
      ),
      onPressed: _currentQuestionIndex < _dsCauHoi.length - 1
          ? () => _goToQuestion(_currentQuestionIndex + 1)
          : null,
      label: const Text('Câu sau'),
      icon: const Icon(Icons.arrow_forward),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: previousButton()),
                  const SizedBox(width: 12),
                  Expanded(child: nextButton()),
                ],
              ),
              const SizedBox(height: 10),
              submitButton(),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: previousButton()),
            const SizedBox(width: 12),
            Expanded(child: submitButton()),
            const SizedBox(width: 12),
            Expanded(child: nextButton()),
          ],
        );
      },
    );
  }
}
