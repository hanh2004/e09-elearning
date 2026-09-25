// APP HỌC VIÊN: Danh sách bài thi an toàn, chỉ nhận dữ liệu câu hỏi từ máy chủ tin cậy.
// Gồm danh sách đề, làm bài, kết quả và lịch sử; API: ../../services/ket_noi_api/secure_exam_service.dart.

import '../../widgets/learner_header.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/ket_noi_api/secure_exam_service.dart';
import '../../app/app_theme.dart';
import '../../widgets/learner_card.dart';

part 'secure_exam_result_history.dart';

/// Danh sách bài thi an toàn, chỉ nhận dữ liệu câu hỏi từ máy chủ tin cậy.
class SecureExamHomeScreen extends StatefulWidget {
  const SecureExamHomeScreen({super.key, this.service});
  final SecureExamService? service;
  @override
  State<SecureExamHomeScreen> createState() => _TrangThaiTrangChuThiBaoMat();
}

class _TrangThaiTrangChuThiBaoMat extends State<SecureExamHomeScreen> {
  late final service = widget.service ?? SecureExamService();
  late Future<Map<String, dynamic>> catalog = service.call('examList');
  String? starting;
  String search = '';
  bool openOnly = false;
  bool available(Map baiThi) {
    if (baiThi['studyCompleted'] != true) return false;
    final hienTai = DateTime.now().millisecondsSinceEpoch;
    return baiThi['active'] == true ||
        (baiThi['isOpen'] == true &&
            (baiThi['opensAt'] == null ||
                (baiThi['opensAt'] as num) <= hienTai) &&
            (baiThi['closesAt'] == null ||
                (baiThi['closesAt'] as num) > hienTai) &&
            (baiThi['maxAttempts'] == null ||
                (baiThi['usedAttempts'] as num? ?? 0) <
                    (baiThi['maxAttempts'] as num)));
  }

  Future<void> start(String ma) async {
    if (starting != null) return;
    setState(() => starting = ma);
    try {
      final lanThi = await service.call('examStart', {'examId': ma});
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => lanThi['status'] == 'completed'
              ? SecureExamResultScreen(result: lanThi)
              : SecureExamScreen(run: lanThi, service: service),
        ),
      );
      if (mounted) setState(() => catalog = service.call('examList'));
    } catch (loi) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(SecureExamService.error(loi))));
      }
    } finally {
      if (mounted) setState(() => starting = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: LearnerHeader(
      title: const Text('Bài kiểm tra'),
      actions: [
        IconButton(
          tooltip: 'Lịch sử thi',
          icon: const Icon(Icons.history),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => SecureExamHistoryScreen(service: service),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Làm mới',
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(() => catalog = service.call('examList')),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: catalog,
      builder: (context, duLieuNhan) {
        if (duLieuNhan.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(SecureExamService.error(duLieuNhan.error!)),
            ),
          );
        }
        if (!duLieuNhan.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final allExams = (duLieuNhan.data!['exams'] as List).cast<Map>();
        final cacBaiThi = allExams
            .where(
              (e) =>
                  e['title'].toString().toLowerCase().contains(search) &&
                  (!openOnly || available(e)),
            )
            .toList();
        if (allExams.isEmpty) {
          return const Center(child: Text('Chưa có bài kiểm tra.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tìm kiếm bài kiểm tra',
              ),
              onChanged: (v) => setState(() => search = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Tất cả (${allExams.length})'),
                  selected: !openOnly,
                  onSelected: (_) => setState(() => openOnly = false),
                ),
                ChoiceChip(
                  label: const Text('Có thể làm bài'),
                  selected: openOnly,
                  onSelected: (_) => setState(() => openOnly = true),
                ),
              ],
            ),
            if (cacBaiThi.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Không có đề phù hợp.'),
              ),
            for (final e in cacBaiThi)
              Card(
                child: ListTile(
                  title: Text(e['title']),
                  subtitle: Text(
                    '${e['durationMinutes']} phút • Đã dùng ${e['usedAttempts']} / ${e['maxAttempts'] ?? 'không giới hạn'} lượt',
                  ),
                  trailing: FilledButton(
                    onPressed: starting != null || !available(e)
                        ? null
                        : () => start(e['id']),
                    child: Text(
                      starting == e['id']
                          ? 'Đang tải…'
                          : e['studyCompleted'] != true
                          ? 'Học trước khi kiểm tra'
                          : e['active'] == true
                          ? 'Tiếp tục'
                          : !available(e)
                          ? 'Chưa khả dụng'
                          : 'Vào thi',
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// Phiên làm bài an toàn với giới hạn thời gian và nộp bài qua backend.
class SecureExamScreen extends StatefulWidget {
  const SecureExamScreen({super.key, required this.run, required this.service});
  final Map<String, dynamic> run;
  final SecureExamService service;
  @override
  State<SecureExamScreen> createState() => _TrangThaiLamBaiThiBaoMat();
}

class _TrangThaiLamBaiThiBaoMat extends State<SecureExamScreen> {
  late Map<String, dynamic> run = widget.run;
  late Map<String, dynamic> answers = Map<String, dynamic>.from(
    run['selectedAnswers'] as Map,
  );
  late int revision = (run['revision'] as num).toInt();
  late int clockOffset =
      ((run['serverNow'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch) -
      DateTime.now().millisecondsSinceEpoch;
  Timer? timer;
  bool busy = false;
  bool finishing = false;
  int currentQuestion = 0;
  bool showAll = false;
  String? error;
  int get seconds =>
      ((run['endsAt'] as num).toInt() -
          DateTime.now().millisecondsSinceEpoch -
          clockOffset) ~/
      1000;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (seconds <= 0 && !busy && !finishing && error == null) {
        unawaited(save(submit: true));
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> reload() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final daCapNhat = await widget.service.call('examStart', {
        'examId': run['examId'],
        'courseId': run['courseId'],
        'lessonId': run['lessonId'],
      });
      if (!mounted) return;
      if (daCapNhat['status'] == 'completed') {
        showResult(daCapNhat);
        return;
      }
      setState(() {
        run = daCapNhat;
        clockOffset =
            (daCapNhat['serverNow'] as num).toInt() -
            DateTime.now().millisecondsSinceEpoch;
        answers = Map<String, dynamic>.from(daCapNhat['selectedAnswers']);
        revision = (daCapNhat['revision'] as num).toInt();
      });
    } catch (e) {
      if (mounted) setState(() => error = SecureExamService.error(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void showResult(Map<String, dynamic> ketQua) {
    finishing = true;
    timer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SecureExamResultScreen(result: ketQua),
      ),
    );
  }

  Future<void> save({bool submit = false}) async {
    if (busy || finishing) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final ketQua = await widget.service.call(
        submit ? 'examSubmit' : 'examSave',
        {
          'runId': run['runId'],
          'revision': revision,
          'selectedAnswers': Map<String, dynamic>.from(answers),
        },
      );
      if (!mounted) return;
      if (ketQua['status'] == 'completed') {
        showResult(ketQua);
        return;
      }
      setState(() => revision = (ketQua['revision'] as num).toInt());
    } catch (e) {
      if (mounted) setState(() => error = SecureExamService.error(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conLai = seconds.clamp(0, 86400);
    final cacCauHoi = (run['questions'] as List).cast<Map>();
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: LearnerHeader(
          title: Text(run['title']),
          actions: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${conLai ~/ 60}:${(conLai % 60).toString().padLeft(2, '0')}',
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            if (error != null)
              MaterialBanner(
                content: Text(error!),
                actions: [
                  TextButton(
                    onPressed: busy ? null : () => save(),
                    child: const Text('Lưu lại'),
                  ),
                  TextButton(
                    onPressed: busy ? null : reload,
                    child: const Text('Tải bài đã lưu'),
                  ),
                ],
              ),
            if (busy) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Đã trả lời ${answers.length}/${cacCauHoi.length} câu',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => showAll = !showAll),
                        icon: Icon(
                          showAll
                              ? Icons.view_agenda_outlined
                              : Icons.grid_view,
                          size: 18,
                        ),
                        label: Text(showAll ? 'Từng câu' : 'Toàn bộ câu'),
                      ),
                    ],
                  ),
                  LinearProgressIndicator(
                    value: cacCauHoi.isEmpty
                        ? 0
                        : answers.length / cacCauHoi.length,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (var i = 0; i < cacCauHoi.length; i++)
                    if (showAll || i == currentQuestion)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${i + 1}. ${cacCauHoi[i]['title']}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              for (
                                var j = 0;
                                j < (cacCauHoi[i]['options'] as List).length;
                                j++
                              )
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(cacCauHoi[i]['options'][j]),
                                  value: answers[cacCauHoi[i]['id']] == j,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  selected: answers[cacCauHoi[i]['id']] == j,
                                  selectedTileColor: const Color(0xFFFFEEEE),
                                  onChanged:
                                      busy || conLai == 0 || error != null
                                      ? null
                                      : (_) {
                                          setState(
                                            () =>
                                                answers[cacCauHoi[i]['id']] = j,
                                          );
                                          unawaited(save());
                                        },
                                ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!showAll)
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: currentQuestion == 0
                                ? null
                                : () => setState(() => currentQuestion--),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Câu trước'),
                          ),
                          Text('${currentQuestion + 1}/${cacCauHoi.length}'),
                          TextButton.icon(
                            onPressed: currentQuestion >= cacCauHoi.length - 1
                                ? null
                                : () => setState(() => currentQuestion++),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Câu tiếp'),
                          ),
                        ],
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Nộp bài?'),
                                    content: Text(
                                      'Đã trả lời ${answers.length}/${cacCauHoi.length} câu.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Tiếp tục làm'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Nộp bài'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true && mounted) {
                                  await save(submit: true);
                                }
                              },
                        icon: const Icon(Icons.check),
                        label: const Text('Nộp bài và xem kết quả'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
