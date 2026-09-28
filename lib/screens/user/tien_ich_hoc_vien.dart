import 'package:flutter/material.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../services/ket_noi_api/dich_vu_bai_kiem_tra_bao_mat.dart';
import '../../models/tham_so_nguoi_dung.dart';
import '../../widgets/dau_trang_hoc_vien.dart';
import 'danh_sach_tin_tuc.dart';
import 'bai_hoc_da_luu.dart';
import 'chinh_sua_ho_so.dart';
import 'lam_bai_kiem_tra_bao_mat.dart';
import 'gui_y_kien_phan_hoi.dart';
import 'cac_khoa_hoc.dart';
import 'bai_kiem_tra_hoc_vien.dart';
import 'thong_bao_hoc_vien.dart';
import 'ho_so_hoc_vien.dart';

class UserUtilitiesScreen extends StatelessWidget {
  const UserUtilitiesScreen({
    super.key,
    required this.args,
    required this.service,
    this.examService,
  });
  final UserArguments args;
  final LearningService service;
  final SecureExamService? examService;

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
              () => open(UserCoursesScreen(uid: args.userId, service: service)),
            ),
            (
              'Kiểm tra',
              Icons.assignment_rounded,
              const Color(0xFFD39B00),
              () => open(
                UserLearningTestsScreen(
                  uid: args.userId,
                  service: service,
                  examService: examService,
                ),
              ),
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
            (
              'Bài đã lưu',
              Icons.bookmark_rounded,
              const Color(0xFF429B59),
              () =>
                  open(SavedLessonsScreen(service: service, uid: args.userId)),
            ),
          ]),
          _nhom(context, 'Thông tin', [
            (
              'Tin tức',
              Icons.newspaper_rounded,
              AppTheme.red,
              () => open(NewsScreen(service: service)),
            ),
            (
              'Thông báo',
              Icons.notifications_active_rounded,
              const Color(0xFF248FC4),
              () => open(
                UserNotificationsScreen(uid: args.userId, service: service),
              ),
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
              () => open(
                UserProfileScreen(
                  args: args,
                  service: service,
                  examService: examService,
                ),
              ),
            ),
            (
              'Cập nhật hồ sơ',
              Icons.manage_accounts_rounded,
              const Color(0xFF429B59),
              () => open(
                ProfileEditScreen(
                  uid: args.userId,
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
