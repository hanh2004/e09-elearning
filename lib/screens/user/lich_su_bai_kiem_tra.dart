// APP HỌC VIÊN: Lịch sử thi dùng chung giao diện cho Firestore và API an toàn.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/ket_qua_bai_kiem_tra.dart';
import '../../services/du_lieu/dich_vu_firestore.dart';
import '../../services/ket_noi_api/dich_vu_bai_kiem_tra_bao_mat.dart';
import '../../widgets/dau_trang_hoc_vien.dart';
import '../../widgets/the_hoc_vien.dart';
import 'lam_bai_kiem_tra_bao_mat.dart';

/// Một màn hình lịch sử, chọn nguồn dữ liệu theo chế độ backend của ứng dụng.
class ExamHistoryScreen extends StatefulWidget {
  const ExamHistoryScreen({
    super.key,
    required this.userId,
    this.secureBackend = false,
    this.service,
    this.firestoreService,
  });

  final String userId;
  final bool secureBackend;
  final SecureExamService? service;
  final FirestoreService? firestoreService;

  @override
  State<ExamHistoryScreen> createState() => _TrangThaiLichSuThi();
}

class _TrangThaiLichSuThi extends State<ExamHistoryScreen> {
  static const _primaryColor = Color(0xFFB51F24);

  final _searchController = TextEditingController();
  String _search = '';
  late final FirestoreService _firestore =
      widget.firestoreService ?? FirestoreService();
  late Future<Map<String, dynamic>> _secureHistory;
  SecureExamService get _examService => widget.service ?? SecureExamService();

  @override
  void initState() {
    super.initState();
    if (widget.secureBackend) _secureHistory = _loadSecureHistory();
  }

  Future<Map<String, dynamic>> _loadSecureHistory() =>
      _examService.call('examHistory');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: LearnerHeader(
      backgroundColor: _primaryColor,
      elevation: 0,
      foregroundColor: Colors.white,
      title: const Text(
        'Lịch sử bài kiểm tra',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      actions: [
        if (widget.secureBackend)
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                setState(() => _secureHistory = _loadSecureHistory()),
          ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: (value) =>
                setState(() => _search = value.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Tìm tên bài kiểm tra hoặc khóa học',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _search = '';
                      }),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ),
        Expanded(
          child: widget.secureBackend
              ? _dungLichSuApi()
              : _dungLichSuFirestore(),
        ),
      ],
    ),
  );

  Widget _dungLichSuApi() => FutureBuilder<Map<String, dynamic>>(
    future: _secureHistory,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text(SecureExamService.error(snapshot.error!)));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final runs = (snapshot.data!['runs'] as List? ?? const [])
          .whereType<Map>()
          .map((run) => Map<String, dynamic>.from(run))
          .where(
            (run) =>
                run['status'] == 'completed' &&
                (run['courseId']?.toString().isNotEmpty ?? false),
          )
          .where(_matchesSearch)
          .toList();
      if (runs.isEmpty) {
        return Center(
          child: Text(
            _search.isEmpty
                ? 'Chưa có lịch sử kiểm tra đã hoàn thành.'
                : 'Không tìm thấy bài kiểm tra phù hợp.',
            textAlign: TextAlign.center,
          ),
        );
      }

      final courses = <String, List<Map<String, dynamic>>>{};
      for (final run in runs) {
        courses.putIfAbsent(run['courseId'].toString(), () => []).add(run);
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final entry in courses.entries)
            Card(
              child: ExpansionTile(
                key: PageStorageKey(entry.key),
                title: Text(
                  entry.value.first['courseTitle']?.toString() ?? 'Khóa học',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Đã hoàn thành ${entry.value.length} lượt kiểm tra',
                ),
                children: [
                  for (final run in entry.value)
                    LearnerCard(
                      accentColor: run['passed'] == true
                          ? Colors.green
                          : _primaryColor,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: run['passed'] == true
                              ? const Color(0xFFE7F0E7)
                              : const Color(0xFFF8E7E7),
                          foregroundColor: run['passed'] == true
                              ? Colors.green.shade800
                              : _primaryColor,
                          child: const Icon(
                            Icons.assignment_turned_in_outlined,
                          ),
                        ),
                        title: Text(
                          run['title']?.toString() ?? 'Bài kiểm tra',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${run['score'] ?? 0}/10 • ${_formatDate(run['completedAt'])}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => SecureExamResultScreen(result: run),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );

  Widget _dungLichSuFirestore() =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.getUserAttemptsStream(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                SecureExamService.error(
                  snapshot.error!,
                  feature: 'Tải lịch sử bài kiểm tra',
                ),
                textAlign: TextAlign.center,
              ),
            );
          }

          final grouped = <String, Map<String, dynamic>>{};
          for (final record in snapshot.data?.docs ?? const []) {
            final data = record.data();
            final attemptCount =
                (data['attemptCount'] as num?)?.toInt() ??
                (data['status'] == 'completed' ? 1 : 0);
            if (attemptCount == 0) continue;

            final examId = data['examId']?.toString() ?? record.id;
            final score =
                (data['bestScore'] as num?)?.toDouble() ??
                (data['diemSo'] as num?)?.toDouble() ??
                0;
            final existing = grouped[examId];
            if (existing == null) {
              grouped[examId] = {
                ...data,
                'displayScore': score,
                'displayAttemptCount': attemptCount,
              };
              continue;
            }

            final combinedAttempts =
                (existing['displayAttemptCount'] as int) + attemptCount;
            if (score > (existing['displayScore'] as double)) {
              grouped[examId] = {
                ...data,
                'displayScore': score,
                'displayAttemptCount': combinedAttempts,
              };
            } else {
              existing['displayAttemptCount'] = combinedAttempts;
            }
          }

          final items = grouped.values.where(_matchesSearch).toList();
          if (items.isEmpty) {
            return Center(
              child: Text(
                _search.isEmpty
                    ? 'Chưa có lịch sử làm bài nào.'
                    : 'Không tìm thấy bài kiểm tra phù hợp.',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: items.length,
            itemBuilder: (context, index) => _theLichSuFirestore(items[index]),
          );
        },
      );

  Widget _theLichSuFirestore(Map<String, dynamic> data) {
    final score = (data['displayScore'] as num?)?.toDouble() ?? 0;
    final passed = ExamOutcome.passed(data);
    return LearnerCard(
      accentColor: passed ? Colors.green : _primaryColor,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data['examTitle']?.toString() ?? 'Bài kiểm tra',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: passed ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: passed ? Colors.green : Colors.red),
                ),
                child: Text(
                  passed ? 'Đạt' : 'Chưa đạt',
                  style: TextStyle(
                    color: passed ? Colors.green[700] : Colors.red[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                _formatDate(data['bestCompletedAt'] ?? data['completedAt']),
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          const Divider(height: 20),
          Text(
            'Đã làm ${data['displayAttemptCount']} lần',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Điểm cao nhất:'),
              Text(
                '${score.toStringAsFixed(1)} / 10',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    final title = (data['title'] ?? data['examTitle'] ?? 'Bài kiểm tra')
        .toString()
        .toLowerCase();
    final course = (data['courseTitle'] ?? '').toString().toLowerCase();
    return title.contains(_search) || course.contains(_search);
  }

  String _formatDate(Object? value) {
    final date = switch (value) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime date => date,
      num milliseconds => DateTime.fromMillisecondsSinceEpoch(
        milliseconds.toInt(),
      ),
      String dateText => DateTime.tryParse(dateText),
      _ => null,
    };
    if (date == null) return 'Thời gian không có sẵn';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }
}
