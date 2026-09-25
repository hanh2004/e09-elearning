// APP HỌC VIÊN: Lịch sử các lần thi và điểm số của học viên.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import '../../widgets/learner_header.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/exam_history_arguments.dart';
import '../../models/exam_outcome.dart';
import '../../services/du_lieu/firestore_service.dart';
import '../../widgets/learner_card.dart';

/// Lịch sử các lần thi và điểm số của học viên.
class ExamHistoryScreen extends StatefulWidget {
  final ExamHistoryArguments args;

  const ExamHistoryScreen({super.key, required this.args});

  @override
  State<ExamHistoryScreen> createState() => _TrangThaiLichSuThi();
}

class _TrangThaiLichSuThi extends State<ExamHistoryScreen> {
  final Color primaryColor = const Color(0xFFB51F24);
  final TextEditingController _oNhapTimKiem = TextEditingController();
  String _tuKhoaTimKiem = '';
  final FirestoreService _dichVuFirestore = FirestoreService();

  @override
  void dispose() {
    _oNhapTimKiem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: LearnerHeader(
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
                      controller: _oNhapTimKiem,
                      onChanged: (val) {
                        setState(() {
                          _tuKhoaTimKiem = val.trim().toLowerCase();
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Tìm kiếm tên bài làm...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  ),
                  if (_tuKhoaTimKiem.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _oNhapTimKiem.clear();
                          _tuKhoaTimKiem = '';
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
              stream: _dichVuFirestore.getUserAttemptsStream(
                widget.args.maNguoiDung,
              ),
              builder: (context, duLieuNhan) {
                if (duLieuNhan.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (duLieuNhan.hasError) {
                  return Center(
                    child: Text('Đã xảy ra lỗi: ${duLieuNhan.error}'),
                  );
                }

                final grouped = <String, Map<String, dynamic>>{};
                for (final banGhi in duLieuNhan.data?.docs ?? const []) {
                  final duLieu = banGhi.data();
                  final soLuong =
                      (duLieu['attemptCount'] as num?)?.toInt() ??
                      (duLieu['status'] == 'completed' ? 1 : 0);
                  if (soLuong == 0) continue;
                  final examId = duLieu['examId']?.toString() ?? banGhi.id;
                  final diem =
                      (duLieu['bestScore'] as num?)?.toDouble() ??
                      (duLieu['diemSo'] as num?)?.toDouble() ??
                      0;
                  final hienHanh = grouped[examId];
                  if (hienHanh == null) {
                    grouped[examId] = {
                      ...duLieu,
                      'displayScore': diem,
                      'displayAttemptCount': soLuong,
                    };
                  } else {
                    hienHanh['displayAttemptCount'] =
                        (hienHanh['displayAttemptCount'] as int) + soLuong;
                    if (diem > (hienHanh['displayScore'] as double)) {
                      grouped[examId] = {
                        ...duLieu,
                        'displayScore': diem,
                        'displayAttemptCount': hienHanh['displayAttemptCount'],
                      };
                    }
                  }
                }
                final cacMuc = grouped.values.toList();
                if (cacMuc.isEmpty) {
                  return const Center(
                    child: Text('Chưa có lịch sử làm bài nào.'),
                  );
                }

                // Lọc danh sách theo từ khóa tìm kiếm
                final filteredItems = cacMuc.where((duLieu) {
                  final tieuDe = (duLieu['examTitle'] ?? 'Bài kiểm tra')
                      .toString()
                      .toLowerCase();
                  return tieuDe.contains(_tuKhoaTimKiem);
                }).toList();

                if (filteredItems.isEmpty) {
                  return const Center(
                    child: Text('Không tìm thấy bài làm phù hợp.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, viTri) {
                    final muc = filteredItems[viTri];
                    final double diemSo = muc['displayScore'] as double;
                    final bool isPassed = ExamOutcome.passed(muc);

                    final Timestamp? nopBaiLuc =
                        (muc['bestCompletedAt'] ?? muc['completedAt'])
                            as Timestamp?;
                    final String dateStr = nopBaiLuc != null
                        ? "${nopBaiLuc.toDate().day}/${nopBaiLuc.toDate().month}/${nopBaiLuc.toDate().year} ${nopBaiLuc.toDate().hour}:${nopBaiLuc.toDate().minute}"
                        : 'N/A';

                    return LearnerCard(
                      accentColor: isPassed ? Colors.green : primaryColor,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  muc['examTitle'] ?? 'Bài kiểm tra',
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
                            'Đã làm ${muc['displayAttemptCount']} lần',
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
