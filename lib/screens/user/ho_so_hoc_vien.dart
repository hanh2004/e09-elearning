// APP HỌC VIÊN: Hồ sơ học viên, lịch sử thi và đăng xuất.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import '../../widgets/dau_trang_hoc_vien.dart';
import '../../widgets/the_ho_so_hoc_vien.dart';
import '../../widgets/the_hoc_vien.dart';
import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'lam_bai_kiem_tra_bao_mat.dart';
import '../../services/ket_noi_api/dich_vu_bai_kiem_tra_bao_mat.dart';
import 'luot_lam_bai_kiem_tra.dart';
import 'chinh_sua_ho_so.dart';

import 'package:flutter/material.dart';

import 'lich_su_bai_kiem_tra.dart';
import '../../models/tham_so_nguoi_dung.dart';
import '../../models/tham_so_lich_su_bai_kiem_tra.dart';
import '../man_hinh_dang_nhap.dart';
import '../../services/tai_khoan/xac_thuc_tai_khoan.dart';
import '../../app/cau_hinh_ung_dung.dart';

/// Hồ sơ học viên, lịch sử thi và đăng xuất.
class UserProfileScreen extends StatelessWidget {
  final UserArguments args;

  const UserProfileScreen({
    super.key,
    required this.args,
    this.service,
    this.examService,
  });
  final LearningService? service;
  final SecureExamService? examService;

  final Color primaryColor = const Color(0xFFB51F24);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LearnerHeader(
        title: const Text(
          'Tài khoản của tôi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ProfileCard(
              uid: args.userId,
              fallbackName: args.userName,
              email: args.email,
              service: service,
            ),
            const SizedBox(height: 20),

            _dungTuyChonCaiDat(
              icon: Icons.manage_accounts,
              title: 'Hồ sơ và bảo mật',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ProfileEditScreen(
                    uid: args.userId,
                    firestore: service?.db,
                  ),
                ),
              ),
            ),
            _dungTuyChonCaiDat(
              icon: Icons.receipt_long,
              title: 'Chi tiết từng lần thi',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AppConfig.useSecureBackend
                      ? SecureExamHistoryScreen(
                          service: examService ?? SecureExamService(),
                        )
                      : ExamRunsScreen(uid: args.userId),
                ),
              ),
            ),
            // 2. Chức năng Lịch sử bài kiểm tra
            _dungTuyChonCaiDat(
              icon: Icons.history,
              title: 'Lịch sử bài kiểm tra',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AppConfig.useSecureBackend
                        ? SecureExamHistoryScreen(
                            service: examService ?? SecureExamService(),
                          )
                        : ExamHistoryScreen(
                            args: ExamHistoryArguments(
                              maNguoiDung: args.userId,
                            ),
                          ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // 3. Nút Đăng xuất
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  await AccountAuth.signOut();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'Đăng xuất',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dungTuyChonCaiDat({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return LearnerCard(
      accentColor: primaryColor,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: primaryColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
