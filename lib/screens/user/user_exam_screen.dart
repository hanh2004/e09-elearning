// APP HỌC VIÊN: Màn hình làm bài thi trên ứng dụng học viên.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import '../../widgets/learner_header.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/cau_hoi_model.dart';
import '../../models/cau_tra_loi_model.dart';
import '../../models/exam_arguments.dart';
import '../../services/du_lieu/firestore_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/option_item.dart';
import 'user_result_screen.dart';
import '../../models/exam_result_arguments.dart';

/// Màn hình làm bài thi trên ứng dụng học viên.
class UserExamScreen extends StatefulWidget {
  final ExamArguments args;

  const UserExamScreen({super.key, required this.args});

  @override
  State<UserExamScreen> createState() => _TrangThaiBaiThiHocVien();
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

class _TrangThaiBaiThiHocVien extends State<UserExamScreen>
    with WidgetsBindingObserver {
  final FirestoreService _dichVuFirestore = FirestoreService();

  List<CauHoiModel> _dsCauHoi = [];
  bool _dangTai = true;
  bool _dangNop = false;
  String? _loiTaiDuLieu;
  int _viTriCauHoiHienTai = 0;
  String? _maLuot;
  final Map<int, int> _dapAnDaChon = {};

  Timer? _boDemGio;
  DateTime? _thoiDiemKetThuc;
  late int _soGiayConLai;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _soGiayConLai = widget.args.thoiGianLamBaiPhut * 60;
    _khoiTaoDuLieuThi();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_luuTienDo());
    _boDemGio?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_luuTienDo());
    } else if (state == AppLifecycleState.resumed) {
      _capNhatThoiGianConLai();
    }
  }

  void _batDauDemGio() {
    _boDemGio?.cancel();
    _capNhatThoiGianConLai();
    if (_soGiayConLai <= 0) {
      unawaited(_xuLyTuDongNopBai());
      return;
    }
    _boDemGio = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      _capNhatThoiGianConLai();
      if (_soGiayConLai <= 0) {
        _boDemGio?.cancel();
        unawaited(_xuLyTuDongNopBai());
      }
    });
  }

  void _capNhatThoiGianConLai() {
    if (_thoiDiemKetThuc == null) return;
    final soGiay = _thoiDiemKetThuc!.difference(DateTime.now()).inSeconds;
    if (mounted) {
      setState(() => _soGiayConLai = soGiay > 0 ? soGiay : 0);
    } else {
      _soGiayConLai = soGiay > 0 ? soGiay : 0;
    }
  }

  Future<void> _luuTienDo() async {
    final attemptId = _maLuot;
    if (attemptId == null || _dangNop) return;
    try {
      await _dichVuFirestore.saveAttemptProgress(
        attemptId: attemptId,
        selectedAnswers: Map<int, int>.from(_dapAnDaChon),
        currentQuestionIndex: _viTriCauHoiHienTai,
      );
    } catch (_) {
      // Firestore tự xếp hàng khi mất mạng và đồng bộ lại khi có mạng.
    }
  }

  void _denCauHoi(int viTri) {
    setState(() => _viTriCauHoiHienTai = viTri);
    unawaited(_luuTienDo());
  }

  void _chonDapAn(int optionIndex) {
    if (_dangTai || _dangNop || _maLuot == null || _soGiayConLai <= 0) {
      return;
    }
    setState(() {
      _dapAnDaChon[_viTriCauHoiHienTai] = optionIndex;
    });
    unawaited(_luuTienDo());
  }

  String get _thoiGianHienThi {
    int soPhut = _soGiayConLai ~/ 60;
    int soGiay = _soGiayConLai % 60;
    return '${soPhut.toString().padLeft(2, '0')}:${soGiay.toString().padLeft(2, '0')}';
  }

  Future<void> _khoiTaoDuLieuThi() async {
    try {
      final loadedQuestions = widget.args.questions.isNotEmpty
          ? widget.args.questions
          : await _dichVuFirestore.getQuestionsForExam(
              widget.args.maBaiKiemTra,
            );
      final cacCauHoi = loadedQuestions
          .where((cauHoi) => cauHoi.isValidForExam)
          .toList();

      if (cacCauHoi.length != loadedQuestions.length) {
        throw StateError(
          'Đề có câu hỏi chưa hợp lệ hoặc chưa hỗ trợ. Vui lòng liên hệ giáo viên để kiểm tra đề.',
        );
      }

      if (!mounted) return;
      setState(() {
        _dsCauHoi = cacCauHoi;
        _dangTai = cacCauHoi.isNotEmpty;
      });

      if (cacCauHoi.isEmpty) return;

      try {
        var phien = await _dichVuFirestore.getOrCreateAttempt(
          courseId: widget.args.courseId,
          lessonId: widget.args.lessonId,
          userId: widget.args.maNguoiDung,
          examId: widget.args.maBaiKiemTra,
          durationMinutes: widget.args.thoiGianLamBaiPhut,
          maxAttempts: widget.args.soLuotLamToiDa,
        );
        if (!phien.endsAt.isAfter(DateTime.now())) {
          final expiredResult = _chamDapAn(cacCauHoi, phien.selectedAnswers);
          await _dichVuFirestore.submitExam(
            maLuot: phien.attemptId,
            diemSo: expiredResult.score,
            dsCauTraLoi: expiredResult.answers,
            examTitle: widget.args.tenBaiKiemTra,
            correctAnswers: expiredResult.correctAnswers,
            totalQuestions: cacCauHoi.length,
          );
          phien = await _dichVuFirestore.getOrCreateAttempt(
            courseId: widget.args.courseId,
            lessonId: widget.args.lessonId,
            userId: widget.args.maNguoiDung,
            examId: widget.args.maBaiKiemTra,
            durationMinutes: widget.args.thoiGianLamBaiPhut,
            maxAttempts: widget.args.soLuotLamToiDa,
          );
        }
        _maLuot = phien.attemptId;
        _thoiDiemKetThuc = phien.endsAt;
        for (final dapAn in phien.selectedAnswers.entries) {
          _dapAnDaChon.putIfAbsent(dapAn.key, () => dapAn.value);
        }
        if (phien.currentQuestionIndex >= 0 &&
            phien.currentQuestionIndex < cacCauHoi.length) {
          _viTriCauHoiHienTai = phien.currentQuestionIndex;
        }
        if (mounted) {
          setState(() {
            _loiTaiDuLieu = null;
            _dangTai = false;
          });
          await _luuTienDo();
          _batDauDemGio();
        }
      } catch (loi) {
        if (!mounted) return;
        final errorText = _thongBaoLoiDeDoc(loi);
        setState(() {
          _loiTaiDuLieu = errorText;
          _dangTai = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorText)));
      }
    } catch (e) {
      if (mounted) {
        final errorText = _thongBaoLoiDeDoc(e);
        setState(() {
          _dangTai = false;
          _loiTaiDuLieu = errorText;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorText)));
      }
    }
  }

  String _thongBaoLoiDeDoc(Object loi) {
    if (loi is StateError) return loi.message.toString();
    if (loi.toString().contains('permission-denied')) {
      return 'Không có quyền đọc câu hỏi hoặc lượt làm bài trên Firestore.';
    }
    return 'Không thể tải bài thi: $loi';
  }

  void _thuChuanBiLuotThiLai() {
    setState(() {
      _loiTaiDuLieu = null;
      _dangTai = false;
    });
    unawaited(_khoiTaoDuLieuThi());
  }

  Future<void> _xuLyTuDongNopBai() async {
    if (_dangNop) return;

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
    if (_maLuot == null || _dangNop) return;

    _boDemGio?.cancel();
    if (mounted) {
      setState(() => _dangNop = true);
    }

    final ketQua = _chamDapAn(_dsCauHoi, _dapAnDaChon);

    try {
      await _dichVuFirestore.submitExam(
        maLuot: _maLuot!,
        diemSo: ketQua.score,
        dsCauTraLoi: ketQua.answers,
        examTitle: widget.args.tenBaiKiemTra,
        correctAnswers: ketQua.correctAnswers,
        totalQuestions: _dsCauHoi.length,
      );

      if (mounted) {
        final elapsed = widget.args.thoiGianLamBaiPhut * 60 - _soGiayConLai;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => UserResultScreen(
              args: ExamResultArguments(
                diemSo: ketQua.score,
                tongSoCau: _dsCauHoi.length,
                soCauDung: ketQua.correctAnswers,
                thoiGianLamBai:
                    '${(elapsed ~/ 60).toString().padLeft(2, '0')}:${(elapsed % 60).toString().padLeft(2, '0')}',
              ),
            ),
          ),
        );
      }
    } catch (loi) {
      if (!mounted) return;
      setState(() => _dangNop = false);
      if (_soGiayConLai > 0) _batDauDemGio();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể nộp bài. Vui lòng thử lại: $loi'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  ({int correctAnswers, double score, List<CauTraLoiModel> answers}) _chamDapAn(
    List<CauHoiModel> cacCauHoi,
    Map<int, int> selectedAnswers,
  ) {
    var correctAnswers = 0;
    final cacDapAn = <CauTraLoiModel>[];

    for (var viTri = 0; viTri < cacCauHoi.length; viTri++) {
      final cauHoi = cacCauHoi[viTri];
      final selectedIndex = selectedAnswers[viTri];
      final hasValidSelection =
          selectedIndex != null &&
          selectedIndex >= 0 &&
          selectedIndex < cauHoi.dsLuaChon.length;
      final selectedOption = hasValidSelection
          ? cauHoi.dsLuaChon[selectedIndex]
          : null;
      final isCorrect = selectedOption?.dapAnDung == true;
      if (isCorrect) correctAnswers++;

      cacDapAn.add(
        CauTraLoiModel(
          maCauTraLoi: '',
          maCauHoi: cauHoi.maCauHoi,
          maLuaChon: selectedOption?.maLuaChon,
          noiDungTraLoi: null,
          traLoiDung: isCorrect,
          diemDatDuoc: isCorrect && cacCauHoi.isNotEmpty
              ? 10.0 / cacCauHoi.length
              : 0,
        ),
      );
    }

    return (
      correctAnswers: correctAnswers,
      score: cacCauHoi.isEmpty ? 0 : correctAnswers / cacCauHoi.length * 10,
      answers: cacDapAn,
    );
  }

  void _moHopThoaiNopBai() {
    final answeredCount = _dapAnDaChon.length;
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
    if (_dangTai) {
      return Scaffold(
        appBar: LearnerHeader(
          backgroundColor: ExamColors.primary,
          title: const Text('Đang tải bài thi...'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_dsCauHoi.isEmpty) {
      return Scaffold(
        appBar: LearnerHeader(
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
                  _loiTaiDuLieu == null
                      ? Icons.quiz_outlined
                      : Icons.error_outline,
                  size: 48,
                  color: _loiTaiDuLieu == null ? Colors.grey : Colors.red,
                ),
                const SizedBox(height: 12),
                Text(
                  _loiTaiDuLieu == null
                      ? 'Bài thi chưa có câu hỏi nào.'
                      : _loiTaiDuLieu!,
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

    final currentQuestion = _dsCauHoi[_viTriCauHoiHienTai];

    return Scaffold(
      backgroundColor: ExamColors.scaffoldBackground,
      appBar: LearnerHeader(
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
              color: _soGiayConLai < 300
                  ? ExamColors.timerUrgent
                  : ExamColors.timerNormal,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  _thoiGianHienThi,
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
      body: _dangNop
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
                    color: _loiTaiDuLieu == null
                        ? Colors.blue[50]
                        : Colors.red[50],
                    child: Row(
                      children: [
                        if (_loiTaiDuLieu == null)
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
                            _loiTaiDuLieu ?? 'Đang chuẩn bị lượt làm bài...',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        if (_loiTaiDuLieu != null)
                          TextButton(
                            onPressed: _thuChuanBiLuotThiLai,
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
                      itemBuilder: (context, viTri) {
                        final isSelected = viTri == _viTriCauHoiHienTai;
                        final isAnswered = _dapAnDaChon.containsKey(viTri);

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
                            _denCauHoi(viTri);
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
                              '${viTri + 1}',
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
                              'Câu ${_viTriCauHoiHienTai + 1}: ${currentQuestion.noiDung}',
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
                              _dapAnDaChon[_viTriCauHoiHienTai] == optIndex;

                          return OptionItem(
                            indexLabel: String.fromCharCode(65 + optIndex),
                            text: currentQuestion.dsLuaChon[optIndex].noiDung,
                            isSelected: isSelectedOption,
                            onTap: () {
                              _chonDapAn(optIndex);
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
                  child: _dungNutDieuHuong(),
                ),
              ],
            ),
    );
  }

  Widget _dungNutDieuHuong() {
    Widget previousButton() => OutlinedButton.icon(
      onPressed: _viTriCauHoiHienTai > 0
          ? () => _denCauHoi(_viTriCauHoiHienTai - 1)
          : null,
      icon: const Icon(Icons.arrow_back),
      label: const Text('Câu trước'),
    );

    Widget submitButton() => CustomButton(
      text: _maLuot == null ? 'Đang chuẩn bị...' : 'Nộp bài',
      onPressed: _maLuot == null ? null : _moHopThoaiNopBai,
      backgroundColor: ExamColors.submitButton,
    );

    Widget nextButton() => ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: ExamColors.primary,
        foregroundColor: Colors.white,
      ),
      onPressed: _viTriCauHoiHienTai < _dsCauHoi.length - 1
          ? () => _denCauHoi(_viTriCauHoiHienTai + 1)
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
