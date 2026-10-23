// WEB ADMIN: Quản lý học viên/quản lý, đơn vị, phân quyền và chuyển học viên giữa đơn vị.
// Form tài khoản và xóa hàng loạt được tách trong các file part cùng thư mục.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../models/dinh_danh_tai_khoan.dart';
import '../../models/yeu_cau_cap_lai_mat_khau.dart';
import '../../widgets/giao_dien_quan_tri.dart';
import 'khung_giao_dien_quan_tri.dart';
import '../../services/du_lieu/dich_vu_firestore.dart';
import '../../services/thong_bao_loi_ung_dung.dart';
import '../../widgets/thong_bao_loi.dart';
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
  late final _luongYeuCauMatKhau = _dichVu.getPasswordResetRequestsStream();
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
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: AdminCard(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth >= 900;
            final chieuRong = constraints.maxWidth >= 650
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            final controls = <Widget>[
              SizedBox(
                width: compact ? null : chieuRong,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('account-unit:$selectedUnit'),
                  initialValue: selectedUnit,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Đơn vị',
                    prefixIcon: Icon(Icons.apartment),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
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
                  onChanged: (giaTri) => setState(() => _boLocDonVi = giaTri),
                ),
              ),
              SizedBox(
                width: compact ? null : chieuRong,
                child: TextField(
                  controller: _oNhapTimKiem,
                  onChanged: (giaTri) =>
                      setState(() => _timKiem = giaTri.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Tìm học viên hoặc đơn vị',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ];
            if (selectedUnit != null) {
              controls.add(
                SizedBox(
                  width: compact ? null : chieuRong,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(
                      'account-sub-unit:$selectedUnit:$selectedSubUnit',
                    ),
                    initialValue: selectedSubUnit,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Trực thuộc',
                      prefixIcon: Icon(Icons.account_tree_outlined),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
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
                          child: Text(giaTri, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (giaTri) =>
                        setState(() => _boLocTrucThuoc = giaTri),
                  ),
                ),
              );
            }
            final xoaBoLoc = TextButton.icon(
              onPressed: () => setState(() {
                _boLocDonVi = null;
                _boLocTrucThuoc = null;
                _timKiem = '';
                _oNhapTimKiem.clear();
              }),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB71C1C),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Xóa bộ lọc'),
            );
            if (compact) {
              return Row(
                children: [
                  for (var i = 0; i < controls.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: controls[i]),
                  ],
                  const SizedBox(width: 4),
                  xoaBoLoc,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 12, runSpacing: 10, children: controls),
                const SizedBox(height: 4),
                xoaBoLoc,
              ],
            );
          },
        ),
      ),
    ),
  );

  String _loiTaiKhoan(Object loi) {
    if (loi is AccountProvisioningException) return loi.message;
    if (loi is FirebaseAuthException) {
      final specific = switch (loi.code) {
        'email-already-in-use' => 'Tên đăng nhập đã tồn tại.',
        'weak-password' => 'Mật khẩu chưa đủ mạnh.',
        _ => null,
      };
      if (specific != null) return specific;
    }
    return AppErrorMessage.from(
      loi,
      feature: 'Quản lý tài khoản',
      fallbackAction: 'Kiểm tra dữ liệu, quyền tài khoản, kết nối và cấu hình máy chủ rồi thử lại.',
    );
  }

  Widget _dungBangTaiKhoan(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cacBanGhi,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cacQuanLy,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> tatCaTaiKhoan,
    Map<String, String> tenNguoiTao,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final chieuRongHuuDung = constraints.maxWidth - 32;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: chieuRongHuuDung,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AdminUi.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  Container(
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF4F7FB),
                      border: Border(bottom: BorderSide(color: AdminUi.border)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        _oCotBang(3, 'Họ và tên', tieuDe: true),
                        _vachCotBang(),
                        _oCotBang(2, 'Vai trò', tieuDe: true),
                        _vachCotBang(),
                        _oCotBang(1, 'Đơn vị', tieuDe: true),
                        _vachCotBang(),
                        _oCotBang(2, 'Trực thuộc', tieuDe: true),
                        _vachCotBang(),
                        _oCotBang(2, 'Tài khoản', tieuDe: true),
                        _vachCotBang(),
                        _oCotBang(2, 'Quản lý', tieuDe: true),
                        _vachCotBang(),
                        SizedBox(
                          width: 196,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'Thao tác',
                              maxLines: 1,
                              style: const TextStyle(
                                color: Color(0xFF5E6F89),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: cacBanGhi.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        thickness: 1,
                        color: AdminUi.border,
                      ),
                      itemBuilder: (context, index) => _dungDongBangTaiKhoan(
                        cacBanGhi[index],
                        cacQuanLy,
                        tatCaTaiKhoan,
                        tenNguoiTao,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _oCotBang(int flex, String nhan, {bool tieuDe = false}) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        nhan,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: tieuDe ? const Color(0xFF5E6F89) : AppTheme.navy,
          fontSize: tieuDe ? 14 : 15,
          fontWeight: tieuDe ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    ),
  );

  Widget _vachCotBang() => const SizedBox(
    height: 30,
    child: VerticalDivider(width: 1, thickness: 1, color: AdminUi.border),
  );

  Widget _dungDongBangTaiKhoan(
    QueryDocumentSnapshot<Map<String, dynamic>> banGhi,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cacQuanLy,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> tatCaTaiKhoan,
    Map<String, String> tenNguoiTao,
  ) {
    final nguoiDung = banGhi.data();
    final vaiTro = switch (nguoiDung['role']) {
      'super_admin' => 'Quản lý tổng',
      'admin' => 'Quản lý',
      'user' => 'Học viên',
      _ => 'Chưa phân quyền',
    };
    final ten = (nguoiDung['name'] ?? '').toString().trim();
    final tenTaiKhoan = (nguoiDung['username'] ?? '').toString().trim();
    final hienThiTen = ten.isNotEmpty ? ten : tenTaiKhoan;
    final tenDangNhap = tenTaiKhoan;
    final maQuanLy = nguoiDung['createdBy']?.toString();
    String quanLyHienThi() {
      if (maQuanLy == null || maQuanLy.isEmpty) return '—';
      for (final quanLy in cacQuanLy) {
        if (quanLy.id == maQuanLy) {
          return (quanLy.data()['username'] ??
                  tenNguoiTao[maQuanLy] ??
                  maQuanLy)
              .toString();
        }
      }
      return tenNguoiTao[maQuanLy] ?? maQuanLy;
    }

    final trangThai = nguoiDung['adminDeletionPending'] == true
        ? 'Chờ duyệt xóa'
        : nguoiDung['status'] == 'blocked'
        ? 'Đã khóa'
        : !['active', null].contains(nguoiDung['status'])
        ? 'Chờ xử lý'
        : null;
    final thaoTac = <Widget>[];
    if (_danhTinh!.isRoot && nguoiDung['role'] == 'admin') {
      thaoTac.add(
        _nutBangTaiKhoan(
          'Phân đơn vị',
          Icons.apartment_rounded,
          () => _moHopThoaiDonVi(
            banGhi.id,
            nguoiDung,
            tatCaTaiKhoan
                .where(
                  (hocVien) =>
                      hocVien.data()['role'] == 'user' &&
                      hocVien.data()['createdBy'] == banGhi.id,
                )
                .toList(),
          ),
        ),
      );
    }
    if (_danhTinh!.isRoot &&
        nguoiDung['role'] == 'user' &&
        cacQuanLy.any((quanLy) => _coTheChuyenHocVienCho(quanLy, nguoiDung))) {
      thaoTac.add(
        _nutBangTaiKhoan(
          'Chuyển đơn vị',
          Icons.swap_horiz_rounded,
          () => _moHopThoaiChuyenQuanLy(banGhi.id, nguoiDung, cacQuanLy),
        ),
      );
    }
    if (_danhTinh!.isRoot &&
        nguoiDung['role'] != 'super_admin' &&
        ['active', 'blocked'].contains(nguoiDung['status'])) {
      final dangKhoa = nguoiDung['status'] == 'blocked';
      thaoTac.add(
        _nutBangTaiKhoan(
          dangKhoa ? 'Mở khóa' : 'Khóa tài khoản',
          dangKhoa ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
          () async {
            try {
              await _dichVu.setUserBlocked(banGhi.id, !dangKhoa);
            } catch (loi) {
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(_loiTaiKhoan(loi))));
              }
            }
          },
        ),
      );
    }
    if (_danhTinh!.canEdit(nguoiDung)) {
      thaoTac.add(
        _nutBangTaiKhoan(
          'Sửa tài khoản',
          Icons.edit_rounded,
          () => _moHopThoaiTaiKhoan(id: banGhi.id, user: nguoiDung),
        ),
      );
    }
    if (_danhTinh!.canDelete(nguoiDung)) {
      thaoTac.add(
        _nutBangTaiKhoan(
          nguoiDung['role'] == 'admin' ? 'Đề xuất xóa Quản lý' : 'Xóa học viên',
          Icons.delete_outline_rounded,
          () => _xoa(banGhi.id, nguoiDung),
          mauDo: true,
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hienThiTen.isEmpty ? 'Chưa có tên' : hienThiTen,
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (trangThai != null)
                    Text(
                      trangThai,
                      style: const TextStyle(
                        color: Color(0xFFB14B32),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
          _vachCotBang(),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCE9EC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    vaiTro,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF98202A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _vachCotBang(),
          Expanded(
            flex: 1,
            child: _giaTriCotBang(
              nguoiDung['role'] == 'super_admin'
                  ? 'E09'
                  : (nguoiDung['unit'] ?? '').toString(),
            ),
          ),
          _vachCotBang(),
          Expanded(
            flex: 2,
            child: _giaTriCotBang((nguoiDung['subUnit'] ?? '').toString()),
          ),
          _vachCotBang(),
          Expanded(flex: 2, child: _giaTriCotBang(tenDangNhap)),
          _vachCotBang(),
          Expanded(
            flex: 2,
            child: _giaTriCotBang(
              nguoiDung['role'] == 'user' ? quanLyHienThi() : '',
            ),
          ),
          _vachCotBang(),
          SizedBox(
            width: 196,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  alignment: WrapAlignment.start,
                  spacing: 4,
                  runSpacing: 6,
                  children: thaoTac.isEmpty ? [const Text('—')] : thaoTac,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _giaTriCotBang(String giaTri) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Text(
      giaTri.trim().isEmpty ? '—' : giaTri,
      style: TextStyle(
        color: giaTri.trim().isEmpty ? const Color(0xFF95A1B2) : AppTheme.navy,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _nutBangTaiKhoan(
    String tooltip,
    IconData icon,
    VoidCallback onPressed, {
    bool mauDo = false,
  }) => Tooltip(
    message: tooltip,
    child: Material(
      color: mauDo ? const Color(0xFFFFF3F3) : const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AdminUi.border),
          ),
          child: Icon(
            icon,
            size: 21,
            color: mauDo ? const Color(0xFFBA202B) : const Color(0xFF353A42),
          ),
        ),
      ),
    ),
  );

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
    if (_danhTinh?.canDelete(nguoiDung) != true) return;
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
              const AdminPageHeading(title: 'Danh sách tài khoản'),
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
                    StreamBuilder<List<PasswordResetRequest>>(
                      stream: _luongYeuCauMatKhau,
                      builder: (context, requests) {
                        final soDangCho =
                            requests.data
                                ?.where(
                                  (request) =>
                                      request.needsAttentionFor(_danhTinh!),
                                )
                                .length ??
                            0;
                        return Badge(
                          isLabelVisible: requests.hasError || soDangCho > 0,
                          label: Text(requests.hasError ? '!' : '$soDangCho'),
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
                      return AppErrorNotice(
                        error: duLieuNhan.error!,
                        feature: 'Tải danh sách tài khoản',
                        fallbackAction: 'Kiểm tra quyền quản trị, kết nối và cấu hình máy chủ rồi tải lại.',
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
                    // Hiển thị quản trị tổng cùng các tài khoản để danh sách
                    // được sắp theo vai trò từ quản trị tổng đến học viên.
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
                    final cacBanGhi =
                        available.where((banGhi) {
                          final duLieu = banGhi.data();
                          final donVi = _donViCua(duLieu);
                          return (selectedUnit == null ||
                                  donVi == selectedUnit) &&
                              (activeSubUnit == null ||
                                  duLieu['subUnit'] == activeSubUnit) &&
                              '${duLieu['name'] ?? ''} ${duLieu['username'] ?? ''} $donVi ${duLieu['subUnit'] ?? ''}'
                                  .toLowerCase()
                                  .contains(_timKiem);
                        }).toList()..sort((a, b) {
                          int mucVaiTro(String? role) => switch (role) {
                            'super_admin' => 0,
                            'admin' => 1,
                            'user' => 2,
                            _ => 3,
                          };

                          final theoVaiTro = mucVaiTro(
                            a.data()['role']?.toString(),
                          ).compareTo(mucVaiTro(b.data()['role']?.toString()));
                          if (theoVaiTro != 0) return theoVaiTro;

                          String tenSapXep(
                            QueryDocumentSnapshot<Map<String, dynamic>> record,
                          ) {
                            final duLieu = record.data();
                            final ten = (duLieu['name'] ?? '')
                                .toString()
                                .trim();
                            final tenDangNhap = (duLieu['username'] ?? '')
                                .toString()
                                .trim();
                            return (ten.isNotEmpty
                                    ? ten
                                    : tenDangNhap.isNotEmpty
                                    ? tenDangNhap
                                    : record.id)
                                .toLowerCase();
                          }

                          final theoTen = tenSapXep(a).compareTo(tenSapXep(b));
                          return theoTen != 0 ? theoTen : a.id.compareTo(b.id);
                        });
                    return Column(
                      children: [
                        _boLoc(cacDonVi, selectedUnit, subUnits, activeSubUnit),
                        Expanded(
                          child: cacBanGhi.isEmpty
                              ? const Center(
                                  child: Text('Không tìm thấy tài khoản nào'),
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) =>
                                      constraints.maxWidth >= 1100
                                      ? _dungBangTaiKhoan(
                                          cacBanGhi,
                                          cacQuanLy,
                                          duLieuNhan.data!.docs,
                                          creatorNames,
                                        )
                                      : ListView.builder(
                                          padding: const EdgeInsets.all(16),
                                          itemCount: cacBanGhi.length,
                                          itemBuilder: (context, i) {
                                            final banGhi = cacBanGhi[i];
                                            final nguoiDung = banGhi.data();
                                            final vaiTro =
                                                switch (nguoiDung['role']) {
                                                  'super_admin' =>
                                                    'Quản lý tổng',
                                                  'admin' => 'Quản lý',
                                                  'user' => 'Học viên',
                                                  _ => 'Tài khoản cũ chưa được cấp quyền',
                                                };
                                            final creatorId =
                                                nguoiDung['createdBy']
                                                    ?.toString();
                                            final creatorLabel =
                                                nguoiDung['role'] == 'user'
                                                ? '\nQuản lý: ${creatorId == null ? 'Dữ liệu cũ/không xác định' : creatorNames[creatorId] ?? creatorId}'
                                                : '';
                                            return Card(
                                              child: ListTile(
                                                title: Text(
                                                  nguoiDung['name']
                                                          ?.toString() ??
                                                      '',
                                                ),
                                                subtitle: Text(
                                                  '${nguoiDung['username']} • $vaiTro${nguoiDung['adminDeletionPending'] == true
                                                      ? ' • Chờ duyệt xóa'
                                                      : nguoiDung['status'] == 'active'
                                                      ? ''
                                                      : nguoiDung['status'] == 'blocked'
                                                      ? ' • Đã khóa'
                                                      : ' • Chờ xử lý'}\nĐơn vị: ${nguoiDung['role'] == 'super_admin' ? 'E09' : nguoiDung['unit'] ?? 'Chưa phân đơn vị'}${(nguoiDung['subUnit'] as String? ?? '').isEmpty ? '' : '\nTrực thuộc: ${nguoiDung['subUnit']}'}$creatorLabel',
                                                ),
                                                trailing: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (root &&
                                                        nguoiDung['role'] ==
                                                            'admin')
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
                                                        nguoiDung['role'] ==
                                                            'user' &&
                                                        cacQuanLy.any(
                                                          (manager) =>
                                                              _coTheChuyenHocVienCho(
                                                                manager,
                                                                nguoiDung,
                                                              ),
                                                        ))
                                                      IconButton(
                                                        tooltip:
                                                            'Chuyển đơn vị',
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
                                                        ].contains(
                                                          nguoiDung['status'],
                                                        ))
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
                                                              : Icons
                                                                    .lock_outline,
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
                                                            if (context
                                                                .mounted) {
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    _loiTaiKhoan(
                                                                      loi,
                                                                    ),
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          }
                                                        },
                                                      ),
                                                    if (_danhTinh!.canEdit(
                                                      nguoiDung,
                                                    ))
                                                      IconButton(
                                                        tooltip:
                                                            'Sửa tài khoản',
                                                        icon: const Icon(
                                                          Icons.edit,
                                                        ),
                                                        onPressed: () =>
                                                            _moHopThoaiTaiKhoan(
                                                              id: banGhi.id,
                                                              user: nguoiDung,
                                                            ),
                                                      ),
                                                    if (_danhTinh!.canDelete(
                                                      nguoiDung,
                                                    ))
                                                      IconButton(
                                                        tooltip:
                                                            nguoiDung['role'] ==
                                                                'admin'
                                                            ? 'Đề xuất xóa Quản lý'
                                                            : 'Xóa học viên',
                                                        icon: const Icon(
                                                          Icons.delete_outline,
                                                        ),
                                                        onPressed: () => _xoa(
                                                          banGhi.id,
                                                          nguoiDung,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
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
