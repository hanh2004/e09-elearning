// APP HỌC VIÊN: Xem hồ sơ, cập nhật đơn vị, đổi mật khẩu, gửi góp ý và đăng xuất.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/tham_so_nguoi_dung.dart';
import '../../services/ket_noi_api/dich_vu_bai_kiem_tra_bao_mat.dart';
import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../services/tai_khoan/thao_tac_tai_khoan_hoc_vien.dart';
import '../../services/tai_khoan/xac_thuc_tai_khoan.dart';
import '../../widgets/dau_trang_hoc_vien.dart';
import '../../widgets/the_ho_so_hoc_vien.dart';
import '../../widgets/the_hoc_vien.dart';
import '../man_hinh_dang_nhap.dart';
import 'gui_y_kien_phan_hoi.dart';

/// Trang tài khoản của học viên.
class UserProfileScreen extends StatefulWidget {
  final UserArguments args;

  const UserProfileScreen({
    super.key,
    required this.args,
    this.service,
    this.examService,
    this.active = true,
  });

  final LearningService? service;
  final SecureExamService? examService;
  final bool active;

  @override
  State<UserProfileScreen> createState() => _TrangThaiTaiKhoanHocVien();
}

class _TrangThaiTaiKhoanHocVien extends State<UserProfileScreen> {
  final Color primaryColor = const Color(0xFFB51F24);
  bool _noticeOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _kiemTraDonViKhiMoTrang();
  }

  @override
  void didUpdateWidget(covariant UserProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) _kiemTraDonViKhiMoTrang();
  }

  void _kiemTraDonViKhiMoTrang() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !widget.active || _noticeOpen) return;
      try {
        final profile = await (widget.service?.db ?? FirebaseFirestore.instance)
            .collection('users')
            .doc(widget.args.userId)
            .get();
        if (!mounted || !widget.active || !profile.exists) return;
        final unit = (profile.data()?['unit'] ?? '').toString().trim();
        if (unit.isNotEmpty) return;
        _noticeOpen = true;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Chưa có đơn vị'),
            content: const Text(
              'Tài khoản của bạn chưa được phân đơn vị. Vui lòng liên hệ quản lý.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đã hiểu'),
              ),
            ],
          ),
        );
        _noticeOpen = false;
      } catch (_) {
        // Kết nối lỗi không đồng nghĩa với việc học viên chưa được phân đơn vị.
      }
    });
  }

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
              uid: widget.args.userId,
              fallbackName: widget.args.userName,
              email: widget.args.email,
              service: widget.service,
            ),
            const SizedBox(height: 20),

            _dungTuyChonCaiDat(
              icon: Icons.edit_location_alt_outlined,
              title: 'Cập nhật đơn vị',
              onTap: () => updateLearnerUnit(
                context,
                uid: widget.args.userId,
                firestore: widget.service?.db,
              ),
            ),
            _dungTuyChonCaiDat(
              icon: Icons.lock_reset_outlined,
              title: 'Đổi mật khẩu',
              onTap: () => changeLearnerPassword(context),
            ),
            _dungTuyChonCaiDat(
              icon: Icons.feedback_outlined,
              title: 'Góp ý ứng dụng',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const UserFeedbackScreen(),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Đăng xuất.
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
