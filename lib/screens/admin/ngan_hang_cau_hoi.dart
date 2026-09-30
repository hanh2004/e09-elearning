// WEB ADMIN: Ngân hàng câu hỏi của một đề: xem, thêm, sửa và xóa câu hỏi.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'khung_giao_dien_quan_tri.dart';
import '../../widgets/giao_dien_quan_tri.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/du_lieu/dich_vu_firestore.dart';
import '../../models/tham_so_ngan_hang_cau_hoi.dart';
import '../../models/dinh_danh_tai_khoan.dart';
import '../../services/nghiep_vu/phan_tich_cau_hoi_nhap_nhieu.dart';

/// Ngân hàng câu hỏi của một đề: xem, thêm, sửa và xóa câu hỏi.
class AdminQuestionBankScreen extends StatefulWidget {
  final QuestionBankArguments args;

  const AdminQuestionBankScreen({super.key, required this.args, this.service});
  final FirestoreService? service;

  @override
  State<AdminQuestionBankScreen> createState() =>
      _TrangThaiNganHangCauHoiQuanTri();
}

class _TrangThaiNganHangCauHoiQuanTri extends State<AdminQuestionBankScreen> {
  late final FirestoreService _dichVuFirestore =
      widget.service ?? FirestoreService();
  final Color primaryColor = const Color(0xFFB51F24);
  late final TextEditingController _examTitleController = TextEditingController(
    text: widget.args.examTitle,
  );
  final TextEditingController _durationController = TextEditingController(
    text: '45',
  );
  final TextEditingController _maxAttemptsController = TextEditingController(
    text: '1',
  );
  String _examTitle = '';
  bool _examPolicyLoaded = false;
  bool _savingExamPolicy = false;
  bool _unlimitedAttempts = false;
  bool _shuffleQuestions = false;
  bool _shuffleAnswers = false;
  bool _showSolutions = false;
  bool _courseLinked = false;
  String? _courseAccessSummary;
  String? _examPolicyError;

  @override
  void initState() {
    super.initState();
    _examTitle = widget.args.examTitle;
    _loadExamPolicy();
  }

  @override
  void dispose() {
    _examTitleController.dispose();
    _durationController.dispose();
    _maxAttemptsController.dispose();
    super.dispose();
  }

  Future<void> _loadExamPolicy() async {
    try {
      final snapshot = await _dichVuFirestore.db
          .doc('exams/${widget.args.examId}')
          .get();
      final exam = snapshot.data();
      if (exam == null) throw StateError('Không tìm thấy bài kiểm tra.');
      final courseId = (exam['courseId'] ?? '').toString().trim();
      Map<String, dynamic>? course;
      if (courseId.isNotEmpty) {
        course = (await _dichVuFirestore.db.doc('courses/$courseId').get())
            .data();
      }
      if (!mounted) return;
      setState(() {
        _examTitle = (exam['title'] ?? widget.args.examTitle).toString();
        _examTitleController.text = _examTitle;
        _durationController.text =
            '${(exam['durationMinutes'] as num?)?.toInt() ?? int.tryParse('${exam['duration'] ?? ''}'.split(' ').first) ?? 45}';
        final maxAttempts = (exam['maxAttempts'] as num?)?.toInt();
        _unlimitedAttempts = maxAttempts == null;
        _maxAttemptsController.text = '${maxAttempts ?? 1}';
        _shuffleQuestions = exam['shuffleQuestions'] == true;
        _shuffleAnswers = exam['shuffleAnswers'] == true;
        _showSolutions = exam['showSolutions'] == true;
        _courseLinked = courseId.isNotEmpty;
        _courseAccessSummary = course == null
            ? null
            : '${course['title'] ?? 'Khóa học'} · '
                  '${course['published'] == true ? 'Đang triển khai' : 'Đang đóng'}';
        _examPolicyLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _examPolicyError = 'Không tải được cài đặt bài kiểm tra.';
        _examPolicyLoaded = true;
      });
    }
  }

  Future<void> _saveExamPolicy() async {
    if (AccountSession.current?.isRoot != true || _savingExamPolicy) return;
    final title = _examTitleController.text.trim();
    final durationMinutes = int.tryParse(_durationController.text.trim());
    final maxAttempts = int.tryParse(_maxAttemptsController.text.trim());
    if (title.isEmpty ||
        durationMinutes == null ||
        durationMinutes < 1 ||
        durationMinutes > 1440 ||
        (!_unlimitedAttempts && (maxAttempts == null || maxAttempts < 1))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nhập tên, thời gian và số lượt làm hợp lệ.'),
        ),
      );
      return;
    }
    setState(() => _savingExamPolicy = true);
    try {
      await _dichVuFirestore.updateExamPolicy(widget.args.examId, {
        'title': title,
        'duration': '$durationMinutes phút',
        'durationMinutes': durationMinutes,
        'maxAttempts': _unlimitedAttempts ? null : maxAttempts,
        'shuffleQuestions': _shuffleQuestions,
        'shuffleAnswers': _shuffleAnswers,
        'showSolutions': _showSolutions,
      });
      if (!mounted) return;
      setState(() {
        _examTitle = title;
        _examPolicyError = null;
        _savingExamPolicy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu yêu cầu và cách làm bài.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingExamPolicy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không lưu được cài đặt bài kiểm tra.')),
      );
    }
  }

  Future<void> _moHopThoaiThemCauHoi({
    String? questionId,
    Map<String, dynamic>? question,
  }) async {
    if (AccountSession.current?.isRoot != true) return;
    final questionController = TextEditingController(
      text: question?['questionText'] ?? '',
    );
    final explanationController = TextEditingController(
      text: question?['explanation'] ?? '',
    );
    final existing = List<String>.from(
      question?['options'] ?? ['', '', '', ''],
    );
    final optionControllers = existing
        .map((s) => TextEditingController(text: s))
        .toList();
    int selectedCorrectIndex = question?['correctAnswerIndex'] ?? 0;
    bool busy = false;

    final dialogRoute = DialogRoute<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Text(
              questionId == null ? 'Thêm câu hỏi mới' : 'Chỉnh sửa câu hỏi',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: questionController,
                    decoration: const InputDecoration(
                      labelText: 'Nội dung câu hỏi',
                    ),
                    maxLines: 2,
                  ),
                  TextField(
                    controller: explanationController,
                    decoration: const InputDecoration(
                      labelText: 'Lời giải (tùy chọn)',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(optionControllers.length, (viTri) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Chọn đáp án đúng',
                            onPressed: () => setModalState(
                              () => selectedCorrectIndex = viTri,
                            ),
                            icon: Icon(
                              selectedCorrectIndex == viTri
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: selectedCorrectIndex == viTri
                                  ? primaryColor
                                  : Colors.grey,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: optionControllers[viTri],
                              decoration: InputDecoration(
                                labelText:
                                    'Đáp án ${String.fromCharCode(65 + viTri)}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                onPressed: () async {
                  if (busy) return;
                  final cacLuaChon = optionControllers
                      .map((e) => e.text.trim())
                      .toList();
                  if (questionController.text.isNotEmpty &&
                      cacLuaChon.every((e) => e.isNotEmpty)) {
                    setModalState(() => busy = true);
                    try {
                      await _dichVuFirestore.addQuestion(
                        widget.args.examId,
                        questionText: questionController.text.trim(),
                        options: cacLuaChon,
                        correctAnswerIndex: selectedCorrectIndex,
                        explanation: explanationController.text,
                        questionId: questionId,
                      );
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    } catch (_) {
                      if (context.mounted) {
                        setModalState(() => busy = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Không lưu được câu hỏi. Vui lòng thử lại.',
                            ),
                          ),
                        );
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Vui lòng điền đầy đủ câu hỏi và 4 đáp án!',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Lưu', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
    await Navigator.of(context).push(dialogRoute);
    await dialogRoute.completed;
    questionController.dispose();
    explanationController.dispose();
    for (final boDieuKhien in optionControllers) {
      boDieuKhien.dispose();
    }
  }

  Future<void> _moHopThoaiNhapNhieuCauHoi() async {
    if (AccountSession.current?.isRoot != true) return;
    final controller = TextEditingController();
    var parsed = const KetQuaPhanTichCauHoi.empty();
    var busy = false;
    final route = DialogRoute<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Nhập nhiều câu hỏi'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Dán theo mẫu dưới đây. Ngăn cách các câu bằng dòng trống hoặc dòng ---; đáp án đúng ghi A, B, C hoặc D.',
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const SelectableText(
                      'Câu hỏi: Nội dung câu hỏi\n'
                      'A. Đáp án thứ nhất\n'
                      'B. Đáp án thứ hai\n'
                      'C. Đáp án thứ ba\n'
                      'D. Đáp án thứ tư\n'
                      'Đáp án: B\n'
                      'Giải thích: Không bắt buộc\n'
                      '---\n'
                      'Câu hỏi: Câu tiếp theo...\n'
                      'A. ...',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cũng có thể dán trực tiếp từ Excel/Sheets theo cột: Câu hỏi | A | B | C | D | Đáp án đúng | Giải thích (không bắt buộc).',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    enabled: !busy,
                    minLines: 8,
                    maxLines: 14,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'Danh sách câu hỏi',
                      hintText: 'Dán nội dung câu hỏi vào đây',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (text) => setDialogState(
                      () => parsed = BoPhanTichCauHoi.parse(text),
                    ),
                  ),
                  if (controller.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      parsed.errors.isEmpty
                          ? 'Đã nhận ${parsed.questions.length} câu hỏi.'
                          : '${parsed.questions.length} câu hợp lệ, ${parsed.errors.length} lỗi cần sửa:',
                      style: TextStyle(
                        color: parsed.errors.isEmpty
                            ? Colors.green.shade800
                            : Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    for (final error in parsed.errors.take(5))
                      Text(
                        '• $error',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    if (parsed.errors.length > 5)
                      Text('Còn ${parsed.errors.length - 5} lỗi khác.'),
                    if (parsed.questions.length > 499 && parsed.errors.isEmpty)
                      Text(
                        'Mỗi lần nhập tối đa 499 câu hỏi.',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton.icon(
              onPressed:
                  busy ||
                      parsed.questions.isEmpty ||
                      parsed.errors.isNotEmpty ||
                      parsed.questions.length > 499
                  ? null
                  : () async {
                      setDialogState(() => busy = true);
                      try {
                        await _dichVuFirestore.addQuestions(
                          widget.args.examId,
                          parsed.questions
                              .map((question) => question.toMap())
                              .toList(),
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, parsed.questions.length);
                        }
                      } catch (_) {
                        if (mounted && dialogContext.mounted) {
                          setDialogState(() => busy = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Không lưu được danh sách câu hỏi. Vui lòng thử lại.',
                              ),
                            ),
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(
                busy ? 'Đang lưu…' : 'Lưu ${parsed.questions.length} câu hỏi',
              ),
            ),
          ],
        ),
      ),
    );
    final count = await Navigator.of(context).push<int>(route);
    await route.completed;
    controller.dispose();
    if (count != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thêm $count câu hỏi vào ngân hàng.')),
      );
    }
  }

  Widget _readOnlyExamSetting(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _examPolicyPanel() {
    if (AccountSession.current?.isRoot != true) {
      return Card(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Yêu cầu bài kiểm tra',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              if (!_examPolicyLoaded && _examPolicyError == null) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ] else if (_examPolicyError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _examPolicyError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ] else ...[
                const SizedBox(height: 8),
                _readOnlyExamSetting('Tên bài kiểm tra', _examTitle),
                _readOnlyExamSetting(
                  'Thời gian làm bài',
                  '${_durationController.text} phút',
                ),
                _readOnlyExamSetting(
                  'Số lượt làm',
                  _unlimitedAttempts
                      ? 'Không giới hạn'
                      : '${_maxAttemptsController.text} lượt',
                ),
                _readOnlyExamSetting(
                  'Trộn thứ tự câu hỏi',
                  _shuffleQuestions ? 'Có' : 'Không',
                ),
                _readOnlyExamSetting(
                  'Trộn thứ tự đáp án',
                  _shuffleAnswers ? 'Có' : 'Không',
                ),
                _readOnlyExamSetting(
                  'Hiển thị đáp án và lời giải',
                  _showSolutions ? 'Có' : 'Không',
                ),
              ],
            ],
          ),
        ),
      );
    }

    final canEdit =
        _examPolicyLoaded && _examPolicyError == null && !_savingExamPolicy;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Yêu cầu bài kiểm tra',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton.icon(
                  onPressed: canEdit ? _saveExamPolicy : null,
                  icon: _savingExamPolicy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_savingExamPolicy ? 'Đang lưu…' : 'Lưu cài đặt'),
                ),
              ],
            ),
            if (_examPolicyError != null) ...[
              const SizedBox(height: 8),
              Text(
                _examPolicyError!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            if (_courseLinked) ...[
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_outlined),
                title: const Text('Quyền làm bài theo khóa học'),
                subtitle: Text(
                  '${_courseAccessSummary ?? 'Đề được quản lý trong khóa học liên kết.'}. Mở và kết thúc khóa học sẽ tự kiểm soát quyền vào làm bài.',
                ),
              ),
            ],
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 700
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: width,
                      child: TextField(
                        controller: _examTitleController,
                        enabled: canEdit,
                        decoration: const InputDecoration(
                          labelText: 'Tên bài kiểm tra',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: TextField(
                        controller: _durationController,
                        enabled: canEdit,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Thời gian làm bài (phút)',
                        ),
                      ),
                    ),
                    if (!_unlimitedAttempts)
                      SizedBox(
                        width: width,
                        child: TextField(
                          controller: _maxAttemptsController,
                          enabled: canEdit,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Số lượt làm tối đa',
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Không giới hạn lượt làm'),
              value: _unlimitedAttempts,
              onChanged: canEdit
                  ? (value) => setState(() => _unlimitedAttempts = value)
                  : null,
            ),
            const Divider(height: 1),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Trộn thứ tự câu hỏi'),
              value: _shuffleQuestions,
              onChanged: canEdit
                  ? (value) => setState(() => _shuffleQuestions = value)
                  : null,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Trộn thứ tự đáp án'),
              value: _shuffleAnswers,
              onChanged: canEdit
                  ? (value) => setState(() => _shuffleAnswers = value)
                  : null,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hiển thị đáp án và lời giải sau khi nộp'),
              subtitle: const Text(
                'Tắt mục này thì học viên chỉ xem điểm và số câu đúng.',
              ),
              value: _showSolutions,
              onChanged: canEdit
                  ? (value) => setState(() => _showSolutions = value)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionCard(
    QueryDocumentSnapshot<Map<String, dynamic>> questionDocument,
    int index,
  ) {
    final question = questionDocument.data();
    final options = List<String>.from(question['options'] ?? []);
    final correctIndex = question['correctAnswerIndex'] ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Câu ${index + 1}: ${question['questionText']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (AccountSession.current?.isRoot == true)
                  IconButton(
                    tooltip: 'Sửa câu hỏi',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _moHopThoaiThemCauHoi(
                      questionId: questionDocument.id,
                      question: question,
                    ),
                  ),
                if (AccountSession.current?.isRoot == true)
                  IconButton(
                    tooltip: 'Xóa câu hỏi',
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _dichVuFirestore.deleteQuestion(
                      widget.args.examId,
                      questionDocument.id,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(options.length, (optionIndex) {
              final isCorrect = optionIndex == correctIndex;
              return Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 10,
                ),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: isCorrect ? Colors.green[50] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isCorrect ? Colors.green : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${String.fromCharCode(65 + optionIndex)}. ',
                      style: TextStyle(
                        color: isCorrect ? Colors.green[800] : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        options[optionIndex],
                        style: TextStyle(
                          color: isCorrect ? Colors.green[800] : Colors.black87,
                          fontWeight: isCorrect
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isCorrect)
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 18,
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminResponsiveShell(
      selectedIndex: 1,
      onSelected: (viTri) => pushAdminPrimary(context, viTri),
      child: Scaffold(
        appBar: AdminUi.appBar(
          'Câu hỏi: $_examTitle',
          actions: [
            if (AccountSession.current?.isRoot == true)
              TextButton.icon(
                onPressed: _moHopThoaiNhapNhieuCauHoi,
                icon: const Icon(Icons.playlist_add_rounded),
                label: const Text('Nhập nhiều câu hỏi'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _dichVuFirestore.getQuestionsStream(widget.args.examId),
          builder: (context, snapshot) {
            final questions = snapshot.data?.docs ?? const [];
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _examPolicyPanel()),
                if (snapshot.hasError)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text('Có lỗi xảy ra khi tải câu hỏi.'),
                    ),
                  )
                else if (snapshot.connectionState == ConnectionState.waiting)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: AdminLoading(),
                  )
                else if (questions.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          AccountSession.current?.isRoot == true
                              ? 'Chưa có câu hỏi nào. Bấm + để thêm câu hỏi hoặc chọn “Nhập nhiều câu hỏi” trên thanh tiêu đề.'
                              : 'Chưa có câu hỏi nào.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _questionCard(questions[index], index),
                        childCount: questions.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        floatingActionButton: AccountSession.current?.isRoot == true
            ? FloatingActionButton(
                backgroundColor: primaryColor,
                onPressed: _moHopThoaiThemCauHoi,
                child: const Icon(Icons.add, color: Colors.white),
              )
            : null,
      ),
    );
  }
}
