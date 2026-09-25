// WEB ADMIN: Cài đặt hệ thống và công tắc khóa/mở đăng nhập ứng dụng học viên.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../login_screen.dart';
import '../../services/tai_khoan/account_auth.dart';
import '../../services/du_lieu/firestore_service.dart';
import '../../models/account_identity.dart';
import '../../widgets/admin_ui.dart';
import '../../widgets/default_user_avatar.dart';
import 'admin_responsive_shell.dart';

/// Cài đặt hệ thống và công tắc khóa/mở đăng nhập ứng dụng học viên.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key, this.service});

  final FirestoreService? service;

  @override
  State<AdminSettingsScreen> createState() => _TrangThaiCaiDatQuanTri();
}

class _TrangThaiCaiDatQuanTri extends State<AdminSettingsScreen> {
  final int _viTriDaChon = 3;
  late final FirestoreService _dichVu;
  bool _dangCapNhatBaoTri = false;

  @override
  void initState() {
    super.initState();
    _dichVu = widget.service ?? FirestoreService();
  }

  Future<void> _datCheDoBaoTri(bool daBat) async {
    setState(() => _dangCapNhatBaoTri = true);
    try {
      await _dichVu.setMaintenanceMode(daBat);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            daBat
                ? 'Đã bật chế độ cập nhật cho ứng dụng học viên.'
                : 'Ứng dụng học viên đã hoạt động trở lại.',
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
      if (mounted) setState(() => _dangCapNhatBaoTri = false);
    }
  }

  void _chonMuc(int viTri) {
    if (viTri == _viTriDaChon) return;
    pushAdminPrimary(context, viTri);
  }

  @override
  Widget build(BuildContext context) {
    final laMayTinh = AdminResponsiveShell.isDesktop(context);
    return AdminResponsiveShell(
      selectedIndex: _viTriDaChon,
      onSelected: _chonMuc,
      child: Scaffold(
        backgroundColor: AdminUi.page,
        appBar: AdminUi.appBar('Cài đặt hệ thống'),
        body: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              const AdminPageHeading(
                title: 'Cài đặt hệ thống',
                subtitle: 'Quản lý tài khoản và trạng thái vận hành hệ thống.',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AdminUi.border),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final hoSo = Row(
                        children: [
                          const DefaultUserAvatar(radius: 32),
                          const SizedBox(width: 16),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Admin',
                                style: TextStyle(
                                  color: AppTheme.navy,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Tài khoản quản trị',
                                style: TextStyle(color: Color(0xFF60779A)),
                              ),
                            ],
                          ),
                        ],
                      );
                      return hoSo;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (AccountSession.current?.isRoot == true) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: StreamBuilder<bool>(
                    stream: _dichVu.getMaintenanceModeStream(),
                    initialData: false,
                    builder: (context, duLieuNhan) => Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AdminUi.border),
                      ),
                      child: SwitchListTile(
                        value: duLieuNhan.data ?? false,
                        onChanged: _dangCapNhatBaoTri ? null : _datCheDoBaoTri,
                        secondary: const Icon(
                          Icons.system_update_alt,
                          color: AppTheme.red,
                        ),
                        title: const Text(
                          'Chế độ bảo trì (khóa đăng nhập học viên)',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          (duLieuNhan.data ?? false)
                              ? 'Ứng dụng học viên đang bị khóa đăng nhập để cập nhật.'
                              : 'Ứng dụng học viên đang hoạt động bình thường.',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
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
                      side: const BorderSide(color: AppTheme.red, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.logout, color: AppTheme.red),
                    label: const Text(
                      'Đăng xuất hệ thống',
                      style: TextStyle(
                        color: AppTheme.red,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: laMayTinh
            ? null
            : BottomNavigationBar(
                currentIndex: _viTriDaChon,
                onTap: _chonMuc,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: AppTheme.red,
                unselectedItemColor: Colors.grey,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: 'Trang chủ',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.assignment),
                    label: 'Quản lý khóa học',
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
