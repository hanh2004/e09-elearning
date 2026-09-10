import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/secure_exam_service.dart';
import '../../app/app_theme.dart';

class SecureExamHomeScreen extends StatefulWidget {
  const SecureExamHomeScreen({super.key, this.service});
  final SecureExamService? service;
  @override
  State<SecureExamHomeScreen> createState() => _SecureExamHomeScreenState();
}

class _SecureExamHomeScreenState extends State<SecureExamHomeScreen> {
  late final service = widget.service ?? SecureExamService();
  late Future<Map<String, dynamic>> catalog = service.call('examList');
  String? starting;
  String search = '';
  bool openOnly = false;
  bool available(Map exam) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return exam['active'] == true ||
        (exam['isOpen'] == true &&
            (exam['opensAt'] == null || (exam['opensAt'] as num) <= now) &&
            (exam['closesAt'] == null || (exam['closesAt'] as num) > now) &&
            (exam['maxAttempts'] == null ||
                (exam['usedAttempts'] as num? ?? 0) <
                    (exam['maxAttempts'] as num)));
  }

  Future<void> start(String id) async {
    if (starting != null) return;
    setState(() => starting = id);
    try {
      final run = await service.call('examStart', {'examId': id});
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => run['status'] == 'completed'
              ? SecureExamResultScreen(result: run)
              : SecureExamScreen(run: run, service: service),
        ),
      );
      if (mounted) setState(() => catalog = service.call('examList'));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(SecureExamService.error(error))));
      }
    } finally {
      if (mounted) setState(() => starting = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
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
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(SecureExamService.error(snapshot.error!)),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final allExams = (snapshot.data!['exams'] as List).cast<Map>();
        final exams = allExams
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
            if (exams.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Không có đề phù hợp.'),
              ),
            for (final e in exams)
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

class SecureExamScreen extends StatefulWidget {
  const SecureExamScreen({super.key, required this.run, required this.service});
  final Map<String, dynamic> run;
  final SecureExamService service;
  @override
  State<SecureExamScreen> createState() => _SecureExamScreenState();
}

class _SecureExamScreenState extends State<SecureExamScreen> {
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
      final updated = await widget.service.call('examStart', {
        'examId': run['examId'],
      });
      if (!mounted) return;
      if (updated['status'] == 'completed') {
        showResult(updated);
        return;
      }
      setState(() {
        run = updated;
        clockOffset =
            (updated['serverNow'] as num).toInt() -
            DateTime.now().millisecondsSinceEpoch;
        answers = Map<String, dynamic>.from(updated['selectedAnswers']);
        revision = (updated['revision'] as num).toInt();
      });
    } catch (e) {
      if (mounted) setState(() => error = SecureExamService.error(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void showResult(Map<String, dynamic> result) {
    finishing = true;
    timer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SecureExamResultScreen(result: result),
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
      final result = await widget.service.call(
        submit ? 'examSubmit' : 'examSave',
        {
          'runId': run['runId'],
          'revision': revision,
          'selectedAnswers': Map<String, dynamic>.from(answers),
        },
      );
      if (!mounted) return;
      if (result['status'] == 'completed') {
        showResult(result);
        return;
      }
      setState(() => revision = (result['revision'] as num).toInt());
    } catch (e) {
      if (mounted) setState(() => error = SecureExamService.error(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = seconds.clamp(0, 86400);
    final questions = (run['questions'] as List).cast<Map>();
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(run['title']),
          actions: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
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
                          'Đã trả lời ${answers.length}/${questions.length} câu',
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
                    value: questions.isEmpty
                        ? 0
                        : answers.length / questions.length,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (var i = 0; i < questions.length; i++)
                    if (showAll || i == currentQuestion)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${i + 1}. ${questions[i]['title']}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              for (
                                var j = 0;
                                j < (questions[i]['options'] as List).length;
                                j++
                              )
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(questions[i]['options'][j]),
                                  value: answers[questions[i]['id']] == j,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  selected: answers[questions[i]['id']] == j,
                                  selectedTileColor: const Color(0xFFFFEEEE),
                                  onChanged:
                                      busy || remaining == 0 || error != null
                                      ? null
                                      : (_) {
                                          setState(
                                            () =>
                                                answers[questions[i]['id']] = j,
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
                          Text('${currentQuestion + 1}/${questions.length}'),
                          TextButton.icon(
                            onPressed: currentQuestion >= questions.length - 1
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
                                      'Đã trả lời ${answers.length}/${questions.length} câu.',
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

class SecureExamResultScreen extends StatelessWidget {
  const SecureExamResultScreen({super.key, required this.result});
  final Map<String, dynamic> result;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.navy,
    appBar: AppBar(title: const Text('Kết quả bài thi')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Text(
                  result['passed'] == true
                      ? 'Chúc mừng bạn!'
                      : 'Tiếp tục cố gắng!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(result['title'] ?? 'Bài thi', textAlign: TextAlign.center),
                const SizedBox(height: 28),
                SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: ((result['score'] as num) / 10).clamp(0, 1),
                          strokeWidth: 9,
                          backgroundColor: const Color(0xFFE7F0E7),
                          color: result['passed'] == true
                              ? Colors.green
                              : AppTheme.red,
                        ),
                      ),
                      Text(
                        '${result['score']}/10',
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
                  '${result['correctAnswers']}/${result['totalQuestions']} câu đúng • ${result['passed'] == true ? 'Đạt' : 'Chưa đạt'}',
                ),
              ],
            ),
          ),
        ),
        if (result['expired'] == true)
          const Text(
            'Đã hết giờ. Kết quả tính từ các đáp án được máy chủ lưu trước hạn.',
            style: TextStyle(color: Colors.white),
          ),
        for (final q in (result['review'] as List? ?? const []))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q['title']),
                  Text('Đáp án đúng: ${q['options'][q['correctIndex']]}'),
                  Text(q['explanation'] ?? ''),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class SecureExamHistoryScreen extends StatefulWidget {
  const SecureExamHistoryScreen({super.key, required this.service});
  final SecureExamService service;
  @override
  State<SecureExamHistoryScreen> createState() =>
      _SecureExamHistoryScreenState();
}

class _SecureExamHistoryScreenState extends State<SecureExamHistoryScreen> {
  late final history = widget.service.call('examHistory');
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lịch sử thi trên máy chủ')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: history,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(SecureExamService.error(snapshot.error!)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final runs = snapshot.data!['runs'] as List;
        if (runs.isEmpty) {
          return const Center(child: Text('Chưa có lượt thi hoàn thành.'));
        }
        return ListView(
          children: [
            for (final raw in runs)
              ListTile(
                title: Text(raw['title']),
                subtitle: Text(
                  '${raw['score']}/10 • ${DateTime.fromMillisecondsSinceEpoch((raw['completedAt'] as num).toInt())}',
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SecureExamResultScreen(
                      result: Map<String, dynamic>.from(raw),
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
