import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/learning_widgets.dart';

class ExamRunsScreen extends StatefulWidget {
  const ExamRunsScreen({super.key, required this.uid});
  final String uid;
  @override
  State<ExamRunsScreen> createState() => _ExamRunsScreenState();
}

class _ExamRunsScreenState extends State<ExamRunsScreen> {
  late final stream = FirebaseFirestore.instance
      .collection('exam_attempts')
      .where('userId', isEqualTo: widget.uid)
      .snapshots();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết từng lần thi')),
    body: LearningList(
      stream: stream,
      builder: (docs) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Các lần thi từ bản nâng cấp này được lưu riêng. Bài thi cũ chỉ còn điểm tốt nhất.',
          ),
          for (final doc in docs)
            Card(
              child: ExpansionTile(
                title: Text(
                  doc.data()['examTitle'] ?? doc.data()['examId'] ?? 'Bài thi',
                ),
                children: [
                  LearningList(
                    stream: doc.reference
                        .collection('runs')
                        .orderBy('runNumber', descending: true)
                        .snapshots(),
                    builder: (runs) => Column(
                      children: [
                        if (runs.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Chưa có lịch sử chi tiết.'),
                          ),
                        for (final run in runs)
                          ListTile(
                            title: Text(
                              'Lần ${run.data()['runNumber']}: ${run.data()['score']}/10',
                            ),
                            subtitle: Text(
                              '${run.data()['correctAnswers']}/${run.data()['totalQuestions']} câu đúng • ${(run.data()['completedAt'] as Timestamp?)?.toDate() ?? ''}',
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
