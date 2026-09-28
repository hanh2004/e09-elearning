// APP HỌC VIÊN: Danh sách các lượt làm bài của một học viên.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import '../../widgets/dau_trang_hoc_vien.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/tien_ich_giao_dien_hoc_tap.dart';
import '../../widgets/the_hoc_vien.dart';

/// Danh sách các lượt làm bài của một học viên.
class ExamRunsScreen extends StatefulWidget {
  const ExamRunsScreen({super.key, required this.uid});
  final String uid;
  @override
  State<ExamRunsScreen> createState() => _TrangThaiCacLuotThi();
}

class _TrangThaiCacLuotThi extends State<ExamRunsScreen> {
  late final stream = FirebaseFirestore.instance
      .collection('exam_attempts')
      .where('userId', isEqualTo: widget.uid)
      .snapshots();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: LearnerHeader(title: const Text('Chi tiết từng lần thi')),
    body: LearningList(
      stream: stream,
      builder: (cacBanGhi) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Các lần thi từ bản nâng cấp này được lưu riêng. Bài thi cũ chỉ còn điểm tốt nhất.',
          ),
          for (final banGhi in cacBanGhi)
            LearnerCard(
              accentColor: const Color(0xFFB51F24),
              child: ExpansionTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                title: Text(
                  banGhi.data()['examTitle'] ??
                      banGhi.data()['examId'] ??
                      'Bài thi',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                children: [
                  LearningList(
                    stream: banGhi.reference
                        .collection('runs')
                        .orderBy('runNumber', descending: true)
                        .snapshots(),
                    builder: (cacLanThi) => Column(
                      children: [
                        if (cacLanThi.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Chưa có lịch sử chi tiết.'),
                          ),
                        for (final lanThi in cacLanThi)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F8FA),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE4E8F0),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFF8E7E7),
                                  foregroundColor: const Color(0xFFB51F24),
                                  child: Text('${lanThi.data()['runNumber']}'),
                                ),
                                title: Text(
                                  'Lần ${lanThi.data()['runNumber']}: ${lanThi.data()['score']}/10',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  '${lanThi.data()['correctAnswers']}/${lanThi.data()['totalQuestions']} câu đúng • ${(lanThi.data()['completedAt'] as Timestamp?)?.toDate() ?? ''}',
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
