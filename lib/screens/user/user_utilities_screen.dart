import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../services/nghiep_vu/learning_service.dart';
import '../../services/ket_noi_api/secure_exam_service.dart';
import '../../widgets/learner_header.dart';
import 'saved_lessons_screen.dart';
import 'profile_edit_screen.dart';
import 'secure_exam_screen.dart';
import 'user_feedback_screen.dart';

class UserUtilitiesScreen extends StatelessWidget {
  const UserUtilitiesScreen({
    super.key,
    required this.uid,
    required this.service,
    required this.onSelect,
    this.examService,
  });
  final String uid;
  final LearningService service;
  final SecureExamService? examService;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: LearnerHeader(
        title: const Text('Tiện ích'),
        backgroundColor: AppTheme.red,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _nhom(context, 'Học tập số', [
            (
              'Học tập',
              Icons.menu_book_rounded,
              AppTheme.red,
              () => onSelect(1),
            ),
            (
              'Kiểm tra',
              Icons.assignment_rounded,
              const Color(0xFFD39B00),
              () => onSelect(2),
            ),
            (
              'Lịch sử kiểm tra',
              Icons.history_rounded,
              const Color(0xFF248FC4),
              () => open(
                SecureExamHistoryScreen(
                  service: examService ?? SecureExamService(),
                ),
              ),
            ),
          ]),
          _nhom(context, 'Thông tin', [
            (
              'Tin tức',
              Icons.newspaper_rounded,
              AppTheme.red,
              () => onSelect(5),
            ),
            (
              'Bài đã lưu',
              Icons.bookmark_rounded,
              const Color(0xFF429B59),
              () => open(SavedLessonsScreen(service: service, uid: uid)),
            ),
            (
              'Thông báo',
              Icons.notifications_active_rounded,
              const Color(0xFF248FC4),
              () => onSelect(3),
            ),
            (
              'Góp ý ứng dụng',
              Icons.feedback_outlined,
              const Color(0xFF429B59),
              () => open(const UserFeedbackScreen()),
            ),
          ]),
          _nhom(context, 'Tài khoản', [
            (
              'Cá nhân',
              Icons.person_rounded,
              const Color(0xFFD39B00),
              () => onSelect(4),
            ),
            (
              'Cập nhật hồ sơ',
              Icons.manage_accounts_rounded,
              const Color(0xFF429B59),
              () => open(
                ProfileEditScreen(
                  uid: uid,
                  firestore: service.db,
                  openEditor: true,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _nhom(
    BuildContext context,
    String tieuDe,
    List<(String, IconData, Color, VoidCallback)> cacMuc,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tieuDe,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth < 350 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3
                ? 2
                : 3;
            final chieuRong =
                (constraints.maxWidth - 16 * (columns - 1)) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 22,
              children: [
                for (final muc in cacMuc)
                  SizedBox(
                    width: chieuRong,
                    child: InkWell(
                      onTap: muc.$4,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    muc.$3.withValues(alpha: .8),
                                    muc.$3,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                muc.$2,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              muc.$1,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 15, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
