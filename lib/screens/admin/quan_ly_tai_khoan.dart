// WEB ADMIN: Quản lý học viên/quản lý, đơn vị, phân quyền và chuyển học viên giữa đơn vị.
// Form tài khoản và xóa hàng loạt được tách trong các file part cùng thư mục.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/dinh_danh_tai_khoan.dart';
import '../../widgets/giao_dien_quan_tri.dart';
import 'khung_giao_dien_quan_tri.dart';
import '../../services/du_lieu/dich_vu_firestore.dart';
import 'hop_thoai_nhap_hoc_vien.dart';
import 'duyet_yeu_cau.dart';
import 'yeu_cau_dat_lai_mat_khau.dart';

part "hop_thoai_tai_khoan.dart";
part "xoa_hang_loat_tai_khoan.dart";

bool _coTheChuyenHocVienCho(
  QueryDocumentSnapshot<Map<String, dynamic>> manager,
  Map<String, dynamic> learner,
) {
  final data = manager.data();
  if (data['status'] != 'active' ||
      !['admin', 'super_admin'].contains(data['role']) ||
      manager.id == learner['createdBy']?.toString()) {
    return false;
  }
  if (data['role'] == 'super_admin') return true;
  final managerUnit = (data['unit'] ?? '').toString().trim().toLowerCase();
  final learnerUnit = (learner['unit'] ?? '').toString().trim().toLowerCase();
  return managerUnit.isNotEmpty && managerUnit != learnerUnit;
}

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
  bool _hienYeuCauDuyetQuanLy = false;
  bool _hienXoaHangLoat = false;
  bool _dangXoaHangLoat = false;
  int _buocXoaHangLoat = 0;
  final Set<String> _quanLyChonXoa = {};
  final Set<String> _hocVienChonXoa = {};
  AccountIdentity? get _danhTinh => AccountSession.current;

  @override
  void dispose() {
    _oNhapTimKiem.dispose();
    super.dispose();
  }

  void _capNhatTrangThaiXoaHangLoat(VoidCallback capNhat) => setState(capNhat);

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
    final xoaQuanLy = nguoiDung['role'] == 'admin';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          xoaQuanLy ? 'Đề xuất xóa Quản lý?' : 'Bạn muốn xóa người này?',
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                xoaQuanLy
                    ? 'Nếu yêu cầu được duyệt, tài khoản Quản lý và tất cả học viên đang do họ quản lý, kể cả học viên được chuyển qua, sẽ bị xóa. Trong lúc chờ duyệt, các tài khoản vẫn hoạt động và có thể chuyển học viên đi.'
                    : 'Tài khoản "${nguoiDung['username']}" và toàn bộ bài làm sẽ bị xóa vĩnh viễn. Dữ liệu sẽ không thể khôi phục.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(xoaQuanLy ? 'Gửi duyệt xóa' : 'Xóa người này'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (xoaQuanLy) {
        await _dichVu.requestAdminDeletion(userId: ma);
      } else {
        await _dichVu.deleteUser(ma);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              xoaQuanLy
                  ? 'Đã gửi yêu cầu. Quản lý tổng còn lại cần duyệt trước khi xóa.'
                  : 'Đã xóa vĩnh viễn tài khoản và toàn bộ bài làm.',
            ),
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
                  if (!_hienXoaHangLoat)
                    OutlinedButton.icon(
                      onPressed: _nhapDuLieu,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Nhập học viên từ Excel'),
                    ),
                  if (root && !_hienXoaHangLoat)
                    OutlinedButton.icon(
                      onPressed: _moXoaHangLoat,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text('Xóa nhiều học viên'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB71C1C),
                      ),
                    ),
                  if (root && !_hienXoaHangLoat)
                    OutlinedButton.icon(
                      onPressed: () => _moHopThoaiTaiKhoan(propose: true),
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Đề xuất Quản lý'),
                    ),
                  if (root && !_hienXoaHangLoat)
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _dichVu.getAdminDeletionRequestsStream(),
                      builder: (context, requests) {
                        final soDangCho =
                            requests.data?.docs
                                .where(
                                  (request) => [
                                    'pending',
                                    'processing',
                                    'provisioning',
                                  ].contains(request.data()['status']),
                                )
                                .length ??
                            0;
                        return Badge(
                          isLabelVisible: soDangCho > 0,
                          label: Text('$soDangCho'),
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() {
                              _hienYeuCauCapLaiMatKhau = false;
                              _hienYeuCauDuyetQuanLy = true;
                            }),
                            icon: const Icon(Icons.approval),
                            label: const Text('Duyệt Quản lý'),
                          ),
                        );
                      },
                    ),
                  if (!_hienXoaHangLoat)
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _dichVu.getPasswordResetRequestsStream(),
                      builder: (context, requests) {
                        final soDangCho =
                            requests.data?.docs
                                .where((request) {
                                  final data = request.data();
                                  final assignedToMe =
                                      data['managerId'] == _danhTinh!.id;
                                  final rootRecovery =
                                      root &&
                                      data['type'] == 'root_recovery' &&
                                      data['userId'] != _danhTinh!.id;
                                  final adminReset =
                                      root && data['userRole'] == 'admin';
                                  return (assignedToMe ||
                                          rootRecovery ||
                                          adminReset) &&
                                      [
                                        'pending',
                                        'approved_once',
                                      ].contains(data['status']);
                                })
                                .length ??
                            0;
                        return Badge(
                          isLabelVisible: soDangCho > 0,
                          label: Text('$soDangCho'),
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() {
                              _hienYeuCauDuyetQuanLy = false;
                              _hienYeuCauCapLaiMatKhau = true;
                            }),
                            icon: const Icon(Icons.lock_reset_outlined),
                            label: const Text('Cấp lại mật khẩu'),
                          ),
                        );
                      },
                    ),
                  if (!_hienXoaHangLoat)
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
                  'Quản lý được thêm, sửa, xóa học viên do mình quản lý và xem báo cáo. Nội dung học tập, đề thi và phân quyền do quản lý tổng quản lý.',
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
            if (_hienYeuCauDuyetQuanLy)
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Yêu cầu duyệt Quản lý',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _hienYeuCauDuyetQuanLy = false),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Quay lại tài khoản'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: AdminRequestsScreen(
                        service: _dichVu,
                        embedded: true,
                      ),
                    ),
                  ],
                ),
              ),
            if (!_hienYeuCauCapLaiMatKhau && !_hienYeuCauDuyetQuanLy)
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
                    if (_hienXoaHangLoat && root) {
                      return _manHinhXoaHangLoat(duLieuNhan.data!.docs);
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
                    final cacQuanLy = duLieuNhan.data!.docs.where((banGhi) {
                      final role = banGhi.data()['role'];
                      return ['admin', 'super_admin'].contains(role) &&
                          banGhi.data()['status'] == 'active';
                    }).toList();
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
                                          '${nguoiDung['username']} • $vaiTro${nguoiDung['adminDeletionPending'] == true
                                              ? ' • Chờ duyệt xóa'
                                              : nguoiDung['status'] == 'active'
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
                                                      _coTheChuyenHocVienCho(
                                                        manager,
                                                        nguoiDung,
                                                      ),
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
                                                    ? 'Đề xuất xóa Quản lý'
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
        floatingActionButton: _hienXoaHangLoat
            ? null
            : FloatingActionButton(
                onPressed: () => _moHopThoaiTaiKhoan(),
                tooltip: 'Thêm học viên',
                child: const Icon(Icons.person_add),
              ),
      ),
    );
  }
}
