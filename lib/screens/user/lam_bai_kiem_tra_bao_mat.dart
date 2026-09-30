// APP HỌC VIÊN: Làm bài kiểm tra an toàn với câu hỏi từ máy chủ tin cậy.
// Gồm làm bài, kết quả và xem lại đáp án; lịch sử ở lich_su_bai_kiem_tra.dart.
// API: ../../services/ket_noi_api/dich_vu_bai_kiem_tra_bao_mat.dart.

import '../../widgets/dau_trang_hoc_vien.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/ket_noi_api/dich_vu_bai_kiem_tra_bao_mat.dart';
import '../../app/chu_de_ung_dung.dart';
import '../../widgets/the_hoc_vien.dart';

part 'lich_su_ket_qua_bai_kiem_tra_bao_mat.dart';

/// Phiên làm bài an toàn với giới hạn thời gian và nộp bài qua backend.
class SecureExamScreen extends StatefulWidget {
  const SecureExamScreen({super.key, required this.run, required this.service});
  final Map<String, dynamic> run;
  final SecureExamService service;
  @override
  State<SecureExamScreen> createState() => _TrangThaiLamBaiThiBaoMat();
}

class _TrangThaiLamBaiThiBaoMat extends State<SecureExamScreen>
    with WidgetsBindingObserver {
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
  Timer? heartbeatTimer;
  bool foreground = true;
  Future<void> presenceQueue = Future<void>.value();
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
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (seconds <= 0 && !busy && !finishing && error == null) {
        unawaited(save(submit: true));
      }
    });
    heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted || finishing || !foreground) return;
      updatePresence(true);
    });
  }

  void updatePresence(bool active) {
    // Giữ thứ tự để heartbeat đang gửi không ghi đè thao tác rời bài.
    presenceQueue = presenceQueue.then((_) async {
      try {
        await widget.service.call('examHeartbeat', {
          'runId': run['runId'],
          'active': active,
        });
      } catch (_) {
        // Mất kết nối thì máy chủ dùng hạn heartbeat để nhận biết ngoại tuyến.
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (finishing) return;
    if (state == AppLifecycleState.resumed) {
      foreground = true;
      updatePresence(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      foreground = false;
      updatePresence(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!finishing) updatePresence(false);
    timer?.cancel();
    heartbeatTimer?.cancel();
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
    heartbeatTimer?.cancel();
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
                                  title: Text(
                                    cacCauHoi[i]['options'][j].toString(),
                                  ),
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
