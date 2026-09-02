import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../login_screen.dart';
import '../../models/exam_arguments.dart';
import 'user_exam_screen.dart';
import '../../models/user_arguments.dart';
import '../../services/firestore_service.dart';

class UserHomeScreen extends StatefulWidget {
  final UserArguments args;

  const UserHomeScreen({super.key, required this.args});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final Color primaryColor = const Color(0xFF6B0000);
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: const Text(
          'Giao diện Học viên',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Chào mừng
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.school, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xin chào, ${widget.args.userName}!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Chúc bạn làm bài thi đạt kết quả cao',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Danh sách Bài thi mở',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestoreService.getExamsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Lỗi tải bài thi'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data();
                  return data['isOpen'] == true;
                }).toList();
                if (docs.isEmpty) {
                  return const Center(child: Text('Hiện chưa có bài thi nào'));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();

                    return FutureBuilder(
                      future: _firestoreService.getQuestionsForExam(
                        docs[index].id,
                      ),
                      builder: (context, questionSnapshot) {
                        final validQuestions =
                            questionSnapshot.data
                                ?.where((question) => question.isValidForExam)
                                .toList() ??
                            const [];
                        final actualQuestionCount = validQuestions.length;
                        final isChecking =
                            questionSnapshot.connectionState ==
                            ConnectionState.waiting;
                        final canStart =
                            !isChecking &&
                            !questionSnapshot.hasError &&
                            actualQuestionCount > 0;
                        final durationText =
                            data['duration']?.toString() ?? '45 phút';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange[50],
                              child: Icon(
                                Icons.assignment,
                                color: Colors.orange[800],
                              ),
                            ),
                            title: Text(
                              data['title'] ?? 'Bài kiểm tra',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Thời gian: $durationText | '
                              '${questionSnapshot.hasError
                                  ? 'Lỗi tải câu hỏi'
                                  : isChecking
                                  ? 'Đang kiểm tra'
                                  : '$actualQuestionCount câu thực tế'} | '
                              '${data['maxAttempts'] == null ? 'Không giới hạn lượt' : '${data['maxAttempts']} lượt'}',
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: canStart
                                  ? () async {
                                      final durationText =
                                          data['duration']?.toString() ?? '45';
                                      final minutes =
                                          int.tryParse(
                                            RegExp(r'\d+')
                                                    .firstMatch(durationText)
                                                    ?.group(0) ??
                                                '',
                                          ) ??
                                          45;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => UserExamScreen(
                                            args: ExamArguments(
                                              maBaiKiemTra: docs[index].id,
                                              dsMaCauHoi: const [],
                                              maNguoiDung: widget.args.userId,
                                              thoiGianLamBaiPhut: minutes,
                                              tenBaiKiemTra:
                                                  data['title']?.toString() ??
                                                  'Bài kiểm tra',
                                              soLuotLamToiDa:
                                                  (data['maxAttempts'] as num?)
                                                      ?.toInt(),
                                              questions: validQuestions,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                              child: Text(
                                questionSnapshot.hasError
                                    ? 'Lỗi tải'
                                    : isChecking
                                    ? 'Đang tải'
                                    : actualQuestionCount == 0
                                    ? 'Chưa có câu hỏi'
                                    : 'Làm bài',
                                style: TextStyle(
                                  color: canStart ? Colors.white : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
