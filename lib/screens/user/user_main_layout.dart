// APP HỌC VIÊN: Khung chính của ứng dụng học viên với thanh điều hướng phía dưới.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'user_dashboard_screen.dart';
import 'profile_edit_screen.dart';
import '../../widgets/unit_update_notice.dart';
import '../../widgets/learner_navigation.dart';
import 'user_learning_tests_screen.dart';
import 'user_courses_screen.dart';
import 'user_notifications_screen.dart';
import 'news_screen.dart';
import 'user_utilities_screen.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_profile_screen.dart';
import '../../models/user_arguments.dart';
import '../../services/nghiep_vu/learning_service.dart';
import '../../services/ket_noi_api/secure_exam_service.dart';

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
  late final profileStream = service.db
      .collection('users')
      .doc(widget.args.userId)
      .snapshots();
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

  // Danh sách màn hình cho thanh Bottom Navigation
  @override
  Widget build(BuildContext context) {
    final pages = [
      UserDashboardScreen(
        args: widget.args,
        service: widget.learningService,
        onSelect: (viTri) => LearnerNavigation.section.value = viTri,
      ),
      UserCoursesScreen(
        uid: widget.args.userId,
        service: widget.learningService,
      ),
      UserLearningTestsScreen(
        uid: widget.args.userId,
        service: widget.learningService,
        examService: widget.examService,
      ),
      UserNotificationsScreen(
        uid: widget.args.userId,
        service: widget.learningService,
      ),
      UserProfileScreen(
        args: widget.args,
        service: widget.learningService,
        examService: widget.examService,
      ),
      NewsScreen(service: service, active: _viTriDaChon == 5),
      UserUtilitiesScreen(
        uid: widget.args.userId,
        service: service,
        examService: widget.examService,
        onSelect: (viTri) => LearnerNavigation.section.value = viTri,
      ),
    ];
    final noiDung = Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: profileStream,
            builder: (context, duLieuNhan) {
              if (!duLieuNhan.hasData || duLieuNhan.hasError) {
                return const SizedBox.shrink();
              }
              final duLieu = duLieuNhan.data?.data() ?? {};
              return UnitUpdateNotice(
                profile: duLieu,
                onUpdate: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProfileEditScreen(
                      uid: widget.args.userId,
                      firestore: service.db,
                      openEditor: true,
                    ),
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: IndexedStack(index: _viTriDaChon, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: LearnerNavigation(
        selectedIndex: _viTriDaChon,
        onSelected: (viTri) => LearnerNavigation.section.value = viTri,
      ),
    );
    return noiDung;
  }
}
