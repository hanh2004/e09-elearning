import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/exam_history_arguments.dart';
import '../../services/firestore_service.dart';

class ExamHistoryScreen extends StatefulWidget {
  final ExamHistoryArguments args;

  const ExamHistoryScreen({super.key, required this.args});

  @override
  State<ExamHistoryScreen> createState() => _ExamHistoryScreenState();
}

class _ExamHistoryScreenState extends State<ExamHistoryScreen> {
  final Color primaryColor = const Color(0xFF6B0000);
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Lịch sử bài làm',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // 1. Thanh tìm kiếm bài làm
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim().toLowerCase();
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Tìm kiếm tên bài làm...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    ),
                ],
              ),
            ),
          ),

          // 2. Danh sách lượt làm bài từ Firebase Server
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestoreService.getUserAttemptsStream(
                widget.args.maNguoiDung,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Đã xảy ra lỗi: ${snapshot.error}'),
                  );
                }

                final grouped = <String, Map<String, dynamic>>{};
                for (final doc in snapshot.data?.docs ?? const []) {
                  final data = doc.data();
                  final count =
                      (data['attemptCount'] as num?)?.toInt() ??
                      (data['status'] == 'completed' ? 1 : 0);
                  if (count == 0) continue;
                  final examId = data['examId']?.toString() ?? doc.id;
                  final score =
                      (data['bestScore'] as num?)?.toDouble() ??
                      (data['diemSo'] as num?)?.toDouble() ??
                      0;
                  final current = grouped[examId];
                  if (current == null) {
                    grouped[examId] = {
                      ...data,
                      'displayScore': score,
                      'displayAttemptCount': count,
                    };
                  } else {
                    current['displayAttemptCount'] =
                        (current['displayAttemptCount'] as int) + count;
                    if (score > (current['displayScore'] as double)) {
                      grouped[examId] = {
                        ...data,
                        'displayScore': score,
                        'displayAttemptCount': current['displayAttemptCount'],
                      };
                    }
                  }
                }
                final items = grouped.values.toList();
                if (items.isEmpty) {
                  return const Center(
                    child: Text('Chưa có lịch sử làm bài nào.'),
                  );
                }

                // Lọc danh sách theo từ khóa tìm kiếm
                final filteredItems = items.where((data) {
                  final tieuDe = (data['examTitle'] ?? 'Bài kiểm tra')
                      .toString()
                      .toLowerCase();
                  return tieuDe.contains(_searchQuery);
                }).toList();

                if (filteredItems.isEmpty) {
                  return const Center(
                    child: Text('Không tìm thấy bài làm phù hợp.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    final double diemSo = item['displayScore'] as double;
                    final bool isPassed = diemSo >= 5.0;

                    final Timestamp? nopBaiLuc =
                        (item['bestCompletedAt'] ?? item['completedAt'])
                            as Timestamp?;
                    final String dateStr = nopBaiLuc != null
                        ? "${nopBaiLuc.toDate().day}/${nopBaiLuc.toDate().month}/${nopBaiLuc.toDate().year} ${nopBaiLuc.toDate().hour}:${nopBaiLuc.toDate().minute}"
                        : 'N/A';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item['examTitle'] ?? 'Bài kiểm tra',
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isPassed
                                      ? Colors.green[50]
                                      : Colors.red[50],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isPassed ? Colors.green : Colors.red,
                                  ),
                                ),
                                child: Text(
                                  isPassed ? 'Đạt' : 'Chưa đạt',
                                  style: TextStyle(
                                    color: isPassed
                                        ? Colors.green[700]
                                        : Colors.red[700],
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
                              const Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Text(
                            'Đã làm ${item['displayAttemptCount']} lần',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Điểm cao nhất:',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${diemSo.toStringAsFixed(1)} / 10',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
