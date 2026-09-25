// WEB ADMIN: Quản lý tài khoản: học viên, quản lý, đơn vị và quyền thao tác.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/account_identity.dart';
import '../../widgets/admin_ui.dart';
import 'admin_responsive_shell.dart';
import '../../services/tai_khoan/account_auth.dart';
import '../../services/du_lieu/firestore_service.dart';
import '../login_screen.dart';
import 'admin_user_import_dialog.dart';
import 'admin_requests_screen.dart';
import 'admin_password_reset_screen.dart';

part "admin_account_dialogs.dart";

/// Quản lý tài khoản: học viên, quản lý, đơn vị và quyền thao tác.
class AdminAccountScreen extends StatefulWidget {
  const AdminAccountScreen({super.key, this.service});
  final FirestoreService? service;
  @override
  State<AdminAccountScreen> createState() => _TrangThaiTaiKhoanQuanTri();
}

class _TrangThaiTaiKhoanQuanTri extends State<AdminAccountScreen> {
  late final FirestoreService _dichVu = widget.service ?? FirestoreService();
  late final _luongTaiKhoan = _dichVu.getUsersStream();
  final _oNhapTimKiem = TextEditingController();
  String _timKiem = '';
  String? _boLocDonVi;
  String? _boLocTrucThuoc;
  bool _hienYeuCauCapLaiMatKhau = false;
  AccountIdentity? get _danhTinh => AccountSession.current;

  @override
  void dispose() {
    _oNhapTimKiem.dispose();
    super.dispose();
  }

  String _donViCua(Map<String, dynamic> nguoiDung) =>
      nguoiDung['role'] == 'super_admin'
      ? 'E09'
      : (nguoiDung['unit'] ?? '').toString().trim();

  Widget _boLoc(
    List<String> cacDonVi,
    String? selectedUnit,
    List<String> subUnits,
    String? selectedSubUnit,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: AdminCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final chieuRong = constraints.maxWidth >= 650
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: chieuRong,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('account-unit:$selectedUnit'),
                        initialValue: selectedUnit,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Đơn vị',
                          prefixIcon: Icon(Icons.apartment),
                        ),
                        hint: const Text('Tất cả đơn vị'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tất cả đơn vị'),
                          ),
                          for (final donVi in cacDonVi)
                            DropdownMenuItem(
                              value: donVi,
                              child: Text(
                                donVi.isEmpty ? 'Chưa phân đơn vị' : donVi,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (giaTri) =>
                            setState(() => _boLocDonVi = giaTri),
                      ),
                    ),
                    SizedBox(
                      width: chieuRong,
                      child: TextField(
                        controller: _oNhapTimKiem,
                        onChanged: (giaTri) => setState(
                          () => _timKiem = giaTri.trim().toLowerCase(),
                        ),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Tìm học viên hoặc đơn vị',
                        ),
                      ),
                    ),
                    if (selectedUnit != null)
                      SizedBox(
                        width: chieuRong,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(
                            'account-sub-unit:$selectedUnit:$selectedSubUnit',
                          ),
                          initialValue: selectedSubUnit,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Trực thuộc',
                            prefixIcon: Icon(Icons.account_tree_outlined),
                          ),
                          hint: const Text('Tất cả trực thuộc'),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Tất cả trực thuộc'),
                            ),
                            for (final giaTri in subUnits)
                              DropdownMenuItem(
                                value: giaTri,
                                child: Text(
                                  giaTri,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (giaTri) =>
                              setState(() => _boLocTrucThuoc = giaTri),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => setState(() {
                _boLocDonVi = null;
                _boLocTrucThuoc = null;
                _timKiem = '';
                _oNhapTimKiem.clear();
              }),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB71C1C),
              ),
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Xóa bộ lọc'),
            ),
          ],
        ),
      ),
    ),
  );

  String _loiTaiKhoan(Object loi) {
    if (loi is AccountProvisioningException) return loi.message;
    if (loi is FirebaseFunctionsException) {
      return loi.message ?? 'Không thể hoàn tất thao tác tài khoản.';
    }
    if (loi is FirebaseAuthException) {
      return switch (loi.code) {
        'email-already-in-use' => 'Tên đăng nhập đã tồn tại.',
        'weak-password' => 'Mật khẩu chưa đủ mạnh.',
        'network-request-failed' =>
          'Mất kết nối Firebase. Kiểm tra mạng rồi thử lại.',
        'operation-not-allowed' =>
          'Firebase Authentication chưa bật đăng nhập Email/Mật khẩu.',
        _ => 'Không thể tạo thông tin đăng nhập (${loi.code}).',
      };
    }
    if (loi is FirebaseException) {
      return switch (loi.code) {
        'permission-denied' =>
          'Tài khoản hiện tại không có quyền thực hiện thao tác này.',
        'unavailable' => 'Firebase đang mất kết nối. Vui lòng thử lại.',
        _ => 'Firebase chưa hoàn tất thao tác (${loi.code}).',
      };
    }
    return 'Chưa hoàn tất: $loi';
  }

  Future<void> _nhapDuLieu() async {
    final soLuong = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdminUserImportDialog(service: _dichVu),
    );
    if (mounted && soLuong != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thêm $soLuong học viên từ Excel.')),
      );
    }
  }

  Future<void> _xoa(String ma, Map<String, dynamic> nguoiDung) async {
    if (_danhTinh?.canDelete(ma, nguoiDung) != true) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Xóa vĩnh viễn tài khoản "${nguoiDung['username']}" và toàn bộ bài làm? '
          'Dữ liệu sẽ không thể khôi phục.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _dichVu.deleteUser(ma);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa vĩnh viễn tài khoản và toàn bộ bài làm.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_loiTaiKhoan(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_danhTinh?.isAdmin != true) {
      return const Scaffold(
        body: Center(child: Text('Cần đăng nhập quản trị.')),
      );
    }
    final root = _danhTinh!.isRoot;
    return AdminResponsiveShell(
      selectedIndex: 0,
      activeExtra: 'Tài khoản',
      onSelected: (viTri) => pushAdminPrimary(context, viTri),
      child: Scaffold(
        backgroundColor: AdminUi.page,
        appBar: AdminUi.appBar(
          root ? 'Quản lý Tài khoản' : 'Học viên do tôi tạo',
          actions: [
            IconButton(
              tooltip: 'Đăng xuất',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await AccountAuth.signOut();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            if (MediaQuery.sizeOf(context).width >= 900)
              const AdminPageHeading(
                title: 'Danh sách tài khoản',
                subtitle:
                    'Quản lý học viên, quản lý đơn vị và phân quyền hệ thống.',
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _nhapDuLieu,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Nhập học viên từ Excel'),
                  ),
                  if (root)
                    OutlinedButton.icon(
                      onPressed: () => _moHopThoaiTaiKhoan(propose: true),
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Đề xuất Quản lý'),
                    ),
                  if (root)
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminRequestsScreen(service: _dichVu),
                        ),
                      ),
                      icon: const Icon(Icons.approval),
                      label: const Text('Duyệt Quản lý'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _hienYeuCauCapLaiMatKhau = true),
                    icon: const Icon(Icons.lock_reset_outlined),
                    label: const Text('Cấp lại mật khẩu'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _moHopThoaiTrucThuoc,
                    icon: const Icon(Icons.account_tree_outlined),
                    label: const Text('Tạo trực thuộc'),
                  ),
                ],
              ),
            ),
            if (!root)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Quản lý được thêm, sửa, xóa học viên do mình tạo và xem báo cáo. Nội dung học tập, đề thi và phân quyền do quản lý tổng quản lý.',
                ),
              ),
            if (_hienYeuCauCapLaiMatKhau)
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Yêu cầu cấp lại mật khẩu',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => setState(
                              () => _hienYeuCauCapLaiMatKhau = false,
                            ),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Quay lại tài khoản'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: AdminPasswordResetScreen(
                        service: _dichVu,
                        embedded: true,
                      ),
                    ),
                  ],
                ),
              ),
            if (!_hienYeuCauCapLaiMatKhau)
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _luongTaiKhoan,
                  builder: (context, duLieuNhan) {
                    if (duLieuNhan.hasError) {
                      return const Center(
                        child: Text(
                          'Không tải được danh sách. Kiểm tra quyền và kết nối.',
                        ),
                      );
                    }
                    if (!duLieuNhan.hasData) {
                      return const AdminLoading();
                    }
                    final creatorNames = <String, String>{
                      for (final banGhi in duLieuNhan.data!.docs)
                        banGhi.id:
                            (banGhi.data()['name'] ??
                                    banGhi.data()['username'] ??
                                    banGhi.id)
                                .toString(),
                    };
                    final available = duLieuNhan.data!.docs
                        .where(
                          (banGhi) =>
                              banGhi.data()['role'] != 'super_admin' &&
                              banGhi.data()['status'] != 'deleted' &&
                              banGhi.data()['status'] != 'rejected',
                        )
                        .toList();
                    final cacDonVi =
                        available
                            .map((banGhi) => _donViCua(banGhi.data()))
                            .toSet()
                            .toList()
                          ..sort();
                    final cacQuanLy = available
                        .where(
                          (banGhi) =>
                              banGhi.data()['role'] == 'admin' &&
                              banGhi.data()['status'] == 'active',
                        )
                        .toList();
                    final selectedUnit = cacDonVi.contains(_boLocDonVi)
                        ? _boLocDonVi
                        : null;
                    final selectedSubUnit = _boLocTrucThuoc;
                    // Học viên E09 do quản trị tổng tạo vẫn có trong danh sách;
                    // thêm lựa chọn trực thuộc của họ vào bộ lọc, nhưng không
                    // hiển thị chính tài khoản quản trị tổng.
                    final subUnitOwners = duLieuNhan.data!.docs
                        .where(
                          (banGhi) =>
                              [
                                'admin',
                                'super_admin',
                              ].contains(banGhi.data()['role']) &&
                              banGhi.data()['status'] != 'deleted' &&
                              banGhi.data()['status'] != 'rejected',
                        )
                        .toList();
                    final subUnits =
                        subUnitOwners
                            .where(
                              (banGhi) =>
                                  _donViCua(banGhi.data()) == selectedUnit,
                            )
                            .expand(
                              (banGhi) =>
                                  ((banGhi.data()['subUnits'] as List?) ??
                                          const [])
                                      .map(
                                        (giaTri) => giaTri.toString().trim(),
                                      ),
                            )
                            .where((giaTri) => giaTri.isNotEmpty)
                            .toSet()
                            .toList()
                          ..sort();
                    final activeSubUnit = subUnits.contains(selectedSubUnit)
                        ? selectedSubUnit
                        : null;
                    final cacBanGhi = available.where((banGhi) {
                      final duLieu = banGhi.data();
                      final donVi = _donViCua(duLieu);
                      return (selectedUnit == null || donVi == selectedUnit) &&
                          (activeSubUnit == null ||
                              duLieu['subUnit'] == activeSubUnit) &&
                          '${duLieu['name'] ?? ''} ${duLieu['username'] ?? ''} ${duLieu['userCode'] ?? ''} $donVi ${duLieu['subUnit'] ?? ''} ${duLieu['subUnit'] ?? ''}-$donVi'
                              .toLowerCase()
                              .contains(_timKiem);
                    }).toList();
                    return Column(
                      children: [
                        _boLoc(cacDonVi, selectedUnit, subUnits, activeSubUnit),
                        Expanded(
                          child: cacBanGhi.isEmpty
                              ? const Center(
                                  child: Text('Không tìm thấy tài khoản nào'),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: cacBanGhi.length,
                                  itemBuilder: (context, i) {
                                    final banGhi = cacBanGhi[i];
                                    final nguoiDung = banGhi.data();
                                    final vaiTro = switch (nguoiDung['role']) {
                                      'super_admin' => 'Quản lý tổng',
                                      'admin' => 'Quản lý',
                                      'user' => 'Học viên',
                                      _ => 'Tài khoản cũ chưa được cấp quyền',
                                    };
                                    final creatorId = nguoiDung['createdBy']
                                        ?.toString();
                                    final creatorLabel =
                                        nguoiDung['role'] == 'user'
                                        ? '\nQuản lý: ${creatorId == null ? 'Dữ liệu cũ/không xác định' : creatorNames[creatorId] ?? creatorId}'
                                        : '';
                                    return Card(
                                      child: ListTile(
                                        title: Text(
                                          nguoiDung['name']?.toString() ?? '',
                                        ),
                                        subtitle: Text(
                                          '${nguoiDung['username']} • $vaiTro${nguoiDung['status'] == 'active'
                                              ? ''
                                              : nguoiDung['status'] == 'blocked'
                                              ? ' • Đã khóa'
                                              : ' • Chờ xử lý'}\nĐơn vị: ${nguoiDung['role'] == 'super_admin' ? 'E09' : nguoiDung['unit'] ?? 'Chưa phân đơn vị'}${(nguoiDung['subUnit'] as String? ?? '').isEmpty ? '' : '\nTrực thuộc: ${nguoiDung['subUnit']}'}${nguoiDung['role'] == 'user' ? '\nMã người dùng: ${nguoiDung['userCode'] ?? 'Chưa được cấp'}' : ''}$creatorLabel',
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (root &&
                                                nguoiDung['role'] == 'admin')
                                              IconButton(
                                                tooltip: 'Phân đơn vị',
                                                icon: const Icon(
                                                  Icons.apartment,
                                                ),
                                                onPressed: () => _moHopThoaiDonVi(
                                                  banGhi.id,
                                                  nguoiDung,
                                                  duLieuNhan.data!.docs
                                                      .where(
                                                        (child) =>
                                                            child
                                                                    .data()['role'] ==
                                                                'user' &&
                                                            child.data()['createdBy'] ==
                                                                banGhi.id,
                                                      )
                                                      .toList(),
                                                ),
                                              ),
                                            if (root &&
                                                nguoiDung['role'] == 'user' &&
                                                cacQuanLy.any(
                                                  (manager) =>
                                                      (manager.data()['unit'] ??
                                                              '')
                                                          .toString()
                                                          .trim()
                                                          .toLowerCase() !=
                                                      (nguoiDung['unit'] ?? '')
                                                          .toString()
                                                          .trim()
                                                          .toLowerCase(),
                                                ))
                                              IconButton(
                                                tooltip:
                                                    'Chuyển cho quản lý khác',
                                                icon: const Icon(
                                                  Icons.swap_horiz,
                                                ),
                                                onPressed: () =>
                                                    _moHopThoaiChuyenQuanLy(
                                                      banGhi.id,
                                                      nguoiDung,
                                                      cacQuanLy,
                                                    ),
                                              ),
                                            if (root &&
                                                nguoiDung['role'] !=
                                                    'super_admin' &&
                                                [
                                                  'active',
                                                  'blocked',
                                                ].contains(nguoiDung['status']))
                                              IconButton(
                                                tooltip:
                                                    nguoiDung['status'] ==
                                                        'blocked'
                                                    ? 'Mở khóa'
                                                    : 'Khóa tài khoản',
                                                icon: Icon(
                                                  nguoiDung['status'] ==
                                                          'blocked'
                                                      ? Icons.lock_open
                                                      : Icons.lock_outline,
                                                ),
                                                onPressed: () async {
                                                  try {
                                                    await _dichVu
                                                        .setUserBlocked(
                                                          banGhi.id,
                                                          nguoiDung['status'] !=
                                                              'blocked',
                                                        );
                                                  } catch (loi) {
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            _loiTaiKhoan(loi),
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  }
                                                },
                                              ),
                                            if (_danhTinh!.canEdit(
                                              banGhi.id,
                                              nguoiDung,
                                            ))
                                              IconButton(
                                                tooltip: 'Sửa tài khoản',
                                                icon: const Icon(Icons.edit),
                                                onPressed: () =>
                                                    _moHopThoaiTaiKhoan(
                                                      id: banGhi.id,
                                                      user: nguoiDung,
                                                    ),
                                              ),
                                            if (_danhTinh!.canDelete(
                                              banGhi.id,
                                              nguoiDung,
                                            ))
                                              IconButton(
                                                tooltip:
                                                    nguoiDung['role'] == 'admin'
                                                    ? 'Xóa Quản lý'
                                                    : 'Xóa học viên',
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                                onPressed: () =>
                                                    _xoa(banGhi.id, nguoiDung),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _moHopThoaiTaiKhoan(),
          tooltip: 'Thêm học viên',
          child: const Icon(Icons.person_add),
        ),
      ),
    );
  }
}
