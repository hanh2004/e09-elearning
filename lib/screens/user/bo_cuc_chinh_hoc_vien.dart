// APP HỌC VIÊN: Khung chính của ứng dụng học viên với thanh điều hướng phía dưới.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'bang_tien_do_hoc_vien.dart';
import '../../widgets/dieu_huong_hoc_vien.dart';
import 'bai_kiem_tra_hoc_vien.dart';
import 'cac_khoa_hoc.dart';
import 'thong_tin_hoc_vien.dart';
import 'thong_bao_hoc_vien.dart';
import 'tien_ich_hoc_vien.dart';

import 'package:flutter/material.dart';

import 'ho_so_hoc_vien.dart';
import '../../models/tham_so_nguoi_dung.dart';
import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../services/ket_noi_api/dich_vu_bai_kiem_tra_bao_mat.dart';

/// Khung chính của ứng dụng học viên với thanh điều hướng phía dưới.
class UserMainLayout extends StatefulWidget {
  final UserArguments args;

  const UserMainLayout({
    super.key,
    required this.args,
    this.learningService,
    this.examService,
  });
  final LearningService? learningService;
  final SecureExamService? examService;

  @override
  State<UserMainLayout> createState() => _TrangThaiKhungHocVien();
}

class _TrangThaiKhungHocVien extends State<UserMainLayout> {
  int _viTriDaChon = 0;
  late final service = widget.learningService ?? LearningService();
  @override
  void initState() {
    super.initState();
    LearnerNavigation.section.value = 0;
    LearnerNavigation.section.addListener(syncSection);
  }

  void syncSection() {
    if (mounted) {
      setState(() => _viTriDaChon = LearnerNavigation.section.value);
    }
  }

  @override
  void dispose() {
    LearnerNavigation.section.removeListener(syncSection);
    super.dispose();
  }

  // Chỉ số trang khớp với LearnerNavigation.section; một số trang mở từ lối tắt.
  @override
  Widget build(BuildContext context) {
    final pages = [
      UserDashboardScreen(
        args: widget.args,
        service: service,
        onSelect: (viTri) => LearnerNavigation.section.value = viTri,
      ),
      UserCoursesScreen(uid: widget.args.userId, service: service),
      UserLearningTestsScreen(
        uid: widget.args.userId,
        service: service,
        examService: widget.examService,
      ),
      UserNotificationsScreen(uid: widget.args.userId, service: service),
      UserProfileScreen(
        args: widget.args,
        service: service,
        active: _viTriDaChon == 4,
      ),
      UserInformationScreen(service: service),
      UserUtilitiesScreen(
        args: widget.args,
        service: service,
        examService: widget.examService,
      ),
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(index: _viTriDaChon, children: pages),
      bottomNavigationBar: LearnerNavigation(
        selectedIndex: _viTriDaChon,
        onSelected: (viTri) => LearnerNavigation.section.value = viTri,
      ),
    );
  }
}
