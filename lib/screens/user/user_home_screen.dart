// APP HỌC VIÊN: Trang bài thi của học viên, hiển thị các đề đang mở và trạng thái làm bài.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import '../../widgets/learner_header.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/default_user_avatar.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../login_screen.dart';
import '../../models/exam_arguments.dart';
import 'user_exam_screen.dart';
import '../../models/user_arguments.dart';
import '../../services/tai_khoan/account_auth.dart';
import '../../services/du_lieu/firestore_service.dart';

/// Trang bài thi của học viên, hiển thị các đề đang mở và trạng thái làm bài.
class UserHomeScreen extends StatefulWidget {
  final UserArguments args;

  const UserHomeScreen({
    super.key,
    required this.args,
    this.service,
    this.onSignOut,
  });

  final FirestoreService? service;
  final Future<void> Function()? onSignOut;

  @override
  State<UserHomeScreen> createState() => _TrangThaiTrangChuHocVien();
}

class _TrangThaiTrangChuHocVien extends State<UserHomeScreen> {
  final Color primaryColor = const Color(0xFFB51F24);
  late final FirestoreService _dichVuFirestore =
      widget.service ?? FirestoreService();
  Timer? _lamMoiHanChot;

  @override
  void initState() {
    super.initState();
    _lamMoiHanChot = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _lamMoiHanChot?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: LearnerHeader(
        backgroundColor: primaryColor,
        elevation: 0,
        title: const Text(
          'Giao diện Học viên',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await (widget.onSignOut ?? AccountAuth.signOut)();
              if (!context.mounted) return;
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
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
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
                      const DefaultUserAvatar(radius: 28),
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
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
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
                  stream: _dichVuFirestore.getExamsStream(),
                  builder: (context, duLieuNhan) {
                    if (duLieuNhan.hasError) {
                      return const Center(child: Text('Lỗi tải bài thi'));
                    }
                    if (duLieuNhan.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final cacBanGhi = duLieuNhan.data!.docs.where((banGhi) {
                      final duLieu = banGhi.data();
                      final rawClosing = duLieu['closesAt'];
                      final closing = rawClosing is Timestamp
                          ? rawClosing.toDate()
                          : null;
                      return duLieu['isOpen'] == true &&
                          (closing == null || closing.isAfter(DateTime.now()));
                    }).toList();
                    if (cacBanGhi.isEmpty) {
                      return const Center(
                        child: Text('Hiện chưa có bài thi nào'),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 820 ? 2 : 1;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent: 126,
                              ),
                          itemCount: cacBanGhi.length,
                          itemBuilder: (context, viTri) {
                            final duLieu = cacBanGhi[viTri].data();

                            return FutureBuilder(
                              future: _dichVuFirestore.getQuestionsForExam(
                                cacBanGhi[viTri].id,
                              ),
                              builder: (context, questionSnapshot) {
                                final validQuestions =
                                    questionSnapshot.data
                                        ?.where(
                                          (cauHoi) => cauHoi.isValidForExam,
                                        )
                                        .toList() ??
                                    const [];
                                final actualQuestionCount =
                                    validQuestions.length;
                                final isChecking =
                                    questionSnapshot.connectionState ==
                                    ConnectionState.waiting;
                                final canStart =
                                    !isChecking &&
                                    !questionSnapshot.hasError &&
                                    actualQuestionCount > 0 &&
                                    actualQuestionCount ==
                                        questionSnapshot.data?.length;
                                final durationText =
                                    duLieu['duration']?.toString() ?? '45 phút';
                                final rawClosing = duLieu['closesAt'];
                                final closing = rawClosing is Timestamp
                                    ? rawClosing.toDate()
                                    : null;
                                final closingText = closing == null
                                    ? 'Không giới hạn ngày nộp'
                                    : 'Hạn ${closing.day.toString().padLeft(2, '0')}/'
                                          '${closing.month.toString().padLeft(2, '0')} '
                                          '${closing.hour.toString().padLeft(2, '0')}:'
                                          '${closing.minute.toString().padLeft(2, '0')}';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                    ),
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
                                      duLieu['title'] ?? 'Bài kiểm tra',
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
                                      '${duLieu['maxAttempts'] == null ? 'Không giới hạn lượt' : '${duLieu['maxAttempts']} lượt'}\n'
                                      '$closingText',
                                    ),
                                    trailing: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: canStart
                                          ? () async {
                                              final durationText =
                                                  duLieu['duration']
                                                      ?.toString() ??
                                                  '45';
                                              final soPhut =
                                                  int.tryParse(
                                                    RegExp(r'\d+')
                                                            .firstMatch(
                                                              durationText,
                                                            )
                                                            ?.group(0) ??
                                                        '',
                                                  ) ??
                                                  45;
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => UserExamScreen(
                                                    args: ExamArguments(
                                                      maBaiKiemTra:
                                                          cacBanGhi[viTri].id,
                                                      dsMaCauHoi: const [],
                                                      maNguoiDung:
                                                          widget.args.userId,
                                                      thoiGianLamBaiPhut:
                                                          soPhut,
                                                      tenBaiKiemTra:
                                                          duLieu['title']
                                                              ?.toString() ??
                                                          'Bài kiểm tra',
                                                      soLuotLamToiDa:
                                                          (duLieu['maxAttempts']
                                                                  as num?)
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
                                          color: canStart
                                              ? Colors.white
                                              : Colors.grey,
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
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
