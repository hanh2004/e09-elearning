import '../../widgets/profile_card.dart';
import '../../services/learning_service.dart';
import 'secure_exam_screen.dart';
import '../../services/secure_exam_service.dart';
import 'exam_runs_screen.dart';
import 'user_schedule_screen.dart';
import 'profile_edit_screen.dart';

import 'package:flutter/material.dart';

import 'exam_history_screen.dart';
import '../../models/user_arguments.dart';
import '../../models/exam_history_arguments.dart';
import '../login_screen.dart';
import '../../services/account_auth.dart';

class UserProfileScreen extends StatelessWidget {
  final UserArguments args;

  const UserProfileScreen({super.key, required this.args, this.service});
  final LearningService? service;

  final Color primaryColor = const Color(0xFFB51F24);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
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

            _buildSettingOption(
              icon: Icons.manage_accounts,
              title: 'Hồ sơ và bảo mật',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ProfileEditScreen(uid: args.userId),
                ),
              ),
            ),
            _buildSettingOption(
              icon: Icons.calendar_month,
              title: 'Lịch học và lịch thi',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => UserScheduleScreen(uid: args.userId),
                ),
              ),
            ),
            _buildSettingOption(
              icon: Icons.receipt_long,
              title: 'Chi tiết từng lần thi',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const bool.fromEnvironment(
                        'USE_SECURE_BACKEND',
                        defaultValue: true,
                      )
                      ? SecureExamHistoryScreen(service: SecureExamService())
                      : ExamRunsScreen(uid: args.userId),
                ),
              ),
            ),
            // 2. Chức năng Lịch sử bài kiểm tra
            _buildSettingOption(
              icon: Icons.history,
              title: 'Lịch sử bài kiểm tra',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExamHistoryScreen(
                      args: ExamHistoryArguments(maNguoiDung: args.userId),
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

  Widget _buildSettingOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
