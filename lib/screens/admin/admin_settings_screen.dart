import 'package:flutter/material.dart';

import 'admin_exam_screen.dart';
import 'admin_home_screen.dart';
import 'admin_report_screen.dart';
import '../login_screen.dart';
import '../../services/account_auth.dart';
import '../../services/firestore_service.dart';
import '../../models/account_identity.dart';
import 'admin_responsive_shell.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key, this.service});

  final FirestoreService? service;

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final int _selectedIndex = 3;
  final Color primaryColor = const Color(0xFFB51F24);
  late final FirestoreService _service;
  bool _updatingMaintenance = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FirestoreService();
  }

  Future<void> _setMaintenance(bool enabled) async {
    setState(() => _updatingMaintenance = true);
    try {
      await _service.setMaintenanceMode(enabled);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Đã bật chế độ cập nhật cho app User.'
                : 'App User đã hoạt động trở lại.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể cập nhật trạng thái ứng dụng.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingMaintenance = false);
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    final pages = <Widget>[
      const AdminHomeScreen(),
      const AdminExamScreen(),
      const AdminReportScreen(),
      const AdminSettingsScreen(),
    ];
    Navigator.pushReplacement(context, adminTabRoute(pages[index]));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AdminResponsiveShell.isDesktop(context);
    return AdminResponsiveShell(
      selectedIndex: _selectedIndex,
      onSelected: _onItemTapped,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: primaryColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Cài đặt hệ thống',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      child: Icon(Icons.person, color: primaryColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Admin',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tài khoản quản trị',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (AccountSession.current?.isRoot == true) ...[
                StreamBuilder<bool>(
                  stream: _service.getMaintenanceModeStream(),
                  initialData: false,
                  builder: (context, snapshot) => Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: SwitchListTile(
                      value: snapshot.data ?? false,
                      onChanged: _updatingMaintenance ? null : _setMaintenance,
                      secondary: Icon(
                        Icons.system_update_alt,
                        color: primaryColor,
                      ),
                      title: const Text('Cập nhật ứng dụng'),
                      subtitle: Text(
                        (snapshot.data ?? false)
                            ? 'App User đang bị khóa đăng nhập để cập nhật.'
                            : 'App User đang hoạt động bình thường.',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await AccountAuth.signOut();
                    if (!context.mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    'Đăng xuất hệ thống',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: isDesktop
            ? null
            : BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: primaryColor,
                unselectedItemColor: Colors.grey,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: 'Trang chủ',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.assignment),
                    label: 'Bài thi',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.bar_chart),
                    label: 'Báo cáo',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings),
                    label: 'Cài đặt',
                  ),
                ],
              ),
      ),
    );
  }
}
