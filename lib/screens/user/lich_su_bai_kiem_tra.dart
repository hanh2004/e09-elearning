// APP HỌC VIÊN: Đọc lịch sử kiểm tra của phiên đăng nhập qua API máy chủ.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/ket_noi_api/dich_vu_bai_kiem_tra_bao_mat.dart';
import '../../widgets/dau_trang_hoc_vien.dart';
import '../../widgets/the_hoc_vien.dart';
import '../../widgets/thong_bao_loi.dart';
import 'lam_bai_kiem_tra_bao_mat.dart';

/// Lịch sử kiểm tra do máy chủ cấp cho học viên đang đăng nhập.
class ExamHistoryScreen extends StatefulWidget {
  const ExamHistoryScreen({super.key, this.service});

  final SecureExamService? service;

  @override
  State<ExamHistoryScreen> createState() => _TrangThaiLichSuThi();
}

class _TrangThaiLichSuThi extends State<ExamHistoryScreen> {
  static const _primaryColor = Color(0xFFB51F24);

  final _searchController = TextEditingController();
  String _search = '';
  late Future<Map<String, dynamic>> _secureHistory;
  SecureExamService get _examService => widget.service ?? SecureExamService();

  @override
  void initState() {
    super.initState();
    _secureHistory = _loadSecureHistory();
  }

  Future<Map<String, dynamic>> _loadSecureHistory() =>
      _examService.call('examHistory').timeout(const Duration(seconds: 20));

  void _reloadHistory() {
    final history = _loadSecureHistory();
    setState(() {
      _secureHistory = history;
    });
  }

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
        IconButton(
          tooltip: 'Làm mới',
          icon: const Icon(Icons.refresh),
          onPressed: _reloadHistory,
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
        Expanded(child: _dungLichSuApi()),
      ],
    ),
  );

  Widget _dungLichSuApi() => FutureBuilder<Map<String, dynamic>>(
    future: _secureHistory,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return AppErrorNotice(
          error: snapshot.error!,
          feature: 'Tải lịch sử bài kiểm tra',
          onRetry: _reloadHistory,
        );
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
