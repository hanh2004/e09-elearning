// WEB ADMIN: Cài đặt hệ thống, đăng xuất; admin tổng quản lý góp ý và bật/tắt bảo trì.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'package:flutter/material.dart';

import '../../app/chu_de_ung_dung.dart';
import '../man_hinh_dang_nhap.dart';
import '../../services/tai_khoan/xac_thuc_tai_khoan.dart';
import '../../services/du_lieu/dich_vu_firestore.dart';
import '../../models/dinh_danh_tai_khoan.dart';
import '../../widgets/giao_dien_quan_tri.dart';
import '../../widgets/anh_dai_dien_mac_dinh.dart';
import '../../widgets/thong_bao_loi.dart';
import 'quan_ly_y_kien_phan_hoi.dart';
import 'khung_giao_dien_quan_tri.dart';

/// Cài đặt hệ thống và công tắc bảo trì ứng dụng học viên.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({
    super.key,
    this.service,
    this.maintenanceModeUpdater,
  });

  final FirestoreService? service;
  final Future<void> Function(bool enabled)? maintenanceModeUpdater;

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
    if (_dangCapNhatBaoTri) return;
    setState(() {
      _dangCapNhatBaoTri = true;
    });
    try {
      await (widget.maintenanceModeUpdater ?? _dichVu.setMaintenanceMode)(
        daBat,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            daBat
                ? 'Đã tạm dừng ứng dụng học viên.'
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
              const AdminPageHeading(title: 'Cài đặt hệ thống'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AdminUi.border),
                  ),
                  child: Row(
                    children: [
                      const DefaultUserAvatar(radius: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AccountSession.current?.displayName ?? 'Quản lý',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.navy,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tài khoản quản trị',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Color(0xFF60779A)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (AccountSession.current?.isRoot == true) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Card(
                    margin: EdgeInsets.zero,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: AdminUi.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const Icon(
                        Icons.feedback_outlined,
                        color: AppTheme.red,
                      ),
                      title: const Text(
                        'Góp ý học viên',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Xem và xử lý góp ý do học viên gửi.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pushReplacement(
                        context,
                        adminTabRoute(const AdminFeedbackScreen()),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: ReloadableStreamBuilder<bool>(
                    streamFactory: _dichVu.getMaintenanceModeStream,
                    feature: 'Tải trạng thái bảo trì',
                    builder: (context, duLieuNhan) {
                      if (!duLieuNhan.hasData) {
                        return const LinearProgressIndicator();
                      }
                      final dangBaoTri = duLieuNhan.data!;
                      return Material(
                        color: Colors.white,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: AdminUi.border),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              value: dangBaoTri,
                              onChanged: _dangCapNhatBaoTri
                                  ? null
                                  : _datCheDoBaoTri,
                              secondary: const Icon(
                                Icons.pause_circle_outline,
                                color: AppTheme.red,
                              ),
                              title: const Text(
                                'Tạm dừng ứng dụng học viên (bảo trì)',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                dangBaoTri
                                    ? 'Đang bật: tất cả học viên bị đăng xuất và không thể dùng app.'
                                    : 'Đang tắt: học viên đăng nhập và sử dụng app bình thường.',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
        bottomNavigationBar: adminMobileNavigationBar(
          context,
          selectedIndex: _viTriDaChon,
          onSelected: _chonMuc,
        ),
      ),
    );
  }
}
