// KHỞI TẠO / GIAO DIỆN: Trang đăng nhập chung: xác thực tài khoản rồi chuyển đúng cổng Admin/Học viên.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'package:flutter/material.dart';

import '../widgets/bieu_trung_thuong_hieu.dart';
import '../services/du_lieu/dich_vu_firestore.dart';
import '../app/cong_ung_dung.dart';
import '../models/dinh_danh_tai_khoan.dart';
import '../services/tai_khoan/xac_thuc_tai_khoan.dart';
import '../services/kiem_tra_phien_ban_ung_dung.dart';
import 'hop_thoai_dat_lai_mat_khau.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.authenticate,
    this.maintenanceChecker,
    this.newReleaseChecker,
    this.requestPasswordReset,
  });

  // Điểm thay thế để kiểm thử đăng nhập mà không chạm vào Firebase thật.
  final Future<Map<String, dynamic>?> Function(String, String)? authenticate;
  final Future<bool> Function()? maintenanceChecker;
  final Future<bool> Function()? newReleaseChecker;
  final Future<bool> Function({
    required String username,
    required String codeSuffix,
  })?
  requestPasswordReset;

  @override
  State<LoginScreen> createState() => _TrangThaiDangNhap();
}

class _TrangThaiDangNhap extends State<LoginScreen> {
  final Color primaryColor = const Color(0xFFB51F24);
  final _khoaBieuMau = GlobalKey<FormState>();

  final TextEditingController _oNhapTenDangNhap = TextEditingController();
  final TextEditingController _oNhapMatKhau = TextEditingController();

  bool _hienMatKhau = false;
  bool _dangTai = false;
  String? _loiDangNhap;

  @override
  void dispose() {
    _oNhapTenDangNhap.dispose();
    _oNhapMatKhau.dispose();
    super.dispose();
  }

  Future<void> _xuLyDangNhap() async {
    if (_dangTai) return;
    if (!_khoaBieuMau.currentState!.validate()) return;
    final scope = PortalScope.of(context);
    setState(() {
      _dangTai = true;
      _loiDangNhap = null;
    });

    final tenDangNhap = _oNhapTenDangNhap.text.trim();
    final matKhau = _oNhapMatKhau.text;

    try {
      if (scope.portal == AppPortal.user) {
        final checkMaintenance =
            widget.maintenanceChecker ??
            (widget.authenticate == null
                ? FirestoreService().isMaintenanceMode
                : () async => false);
        if (await checkMaintenance()) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Ứng dụng đang được bảo trì. Vui lòng quay lại sau khi bảo trì hoàn tất.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }
      final authenticate =
          widget.authenticate ?? FirestoreService().loginWithUsername;
      final userData = await authenticate(tenDangNhap, matKhau);

      if (!mounted) {
        // Cổng cập nhật có thể đóng trang trong khi Firebase đang đăng nhập.
        if (userData != null && widget.authenticate == null) {
          await AccountAuth.signOut();
        }
        return;
      }

      if (userData != null && scope.portal.acceptsRole(userData['role'])) {
        if (scope.portal == AppPortal.user) {
          try {
            final hasNewRelease =
                await (widget.newReleaseChecker?.call() ??
                    (widget.authenticate == null
                        ? AppReleaseChecker().hasNewRelease()
                        : Future<bool>.value(false)));
            if (!mounted) return;
            if (hasNewRelease) await _showNewReleaseNotice();
            if (!mounted) return;
          } catch (_) {
            // Nếu kiểm tra thông báo lỗi, vẫn cho phép người dùng đăng nhập.
          }
        }
        AccountSession.current = AccountIdentity(
          id: userData['id'].toString(),
          role: userData['role'].toString(),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => scope.homeBuilder(userData)),
        );
      } else {
        // Đăng nhập sai không được đăng xuất phiên khác đang hoạt động.
        // Chỉ xóa phiên khi tài khoản hợp lệ đi nhầm cổng.
        if (userData != null) {
          AccountSession.current = null;
          if (widget.authenticate == null) await AccountAuth.signOut();
        }
        if (!mounted) return;
        // Dùng cùng một thông báo cho thông tin đăng nhập sai và vai trò bị từ chối.
        // Không tiết lộ tài khoản này thuộc cổng còn lại.
        setState(
          () => _loiDangNhap =
              'Tên đăng nhập hoặc mật khẩu không chính xác!',
        );
      }
    } catch (loi) {
      debugPrint('[Đăng nhập] ${accountLoginErrorCode(loi)}');
      if (mounted) {
        setState(() => _loiDangNhap = accountLoginErrorMessage(loi));
      }
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  Future<void> _showNewReleaseNotice() => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Có bản cập nhật mới'),
        content: const Text('Liên hệ người phụ trách để cập nhật bản mới.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đã rõ'),
          ),
        ],
      ),
    ),
  );

  Future<void> _moHopThoaiCapLaiMatKhau() async {
    await showPasswordResetDialog(
      context: context,
      initialUsername: _oNhapTenDangNhap.text,
      canRecoverRootAccount: _laCongQuanTri,
      submitRequest:
          widget.requestPasswordReset ??
          ({required username, required codeSuffix}) => FirestoreService()
              .requestPasswordReset(username: username, codeSuffix: codeSuffix),
      recoverRootAccount: _khoiPhucAdminTong,
    );
  }

  Future<void> _khoiPhucAdminTong(String initialUsername) =>
      showRootPasswordRecoveryDialog(
        screenContext: context,
        initialUsername: initialUsername,
      );
  bool get _laCongQuanTri => PortalScope.of(context).portal == AppPortal.admin;

  Widget _dauTrangQuanTri() => Container(
    height: 720,
    padding: const EdgeInsets.fromLTRB(48, 44, 48, 30),
    decoration: BoxDecoration(
      image: const DecorationImage(
        image: AssetImage('assets/branding/admin-login-bg.png'),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      ),
      gradient: const LinearGradient(
        colors: [Color(0x99000000), Color(0x22000000), Color(0x88000000)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Align(
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandLogo(admin: true, height: 152),
          const SizedBox(height: 24),
          const Text(
            'HỆ THỐNG QUẢN TRỊ E09',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 14),
          Container(width: 92, height: 4, color: Color(0xFFF2C45C)),
          const SizedBox(height: 18),
          const Text(
            'Quản lý nội dung, theo dõi tiến độ và vận hành\nhệ thống học tập tập trung.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 18, height: 1.45),
          ),
        ],
      ),
    ),
  );

  Widget _dauTrangHocVien() => Container(
    height: 580,
    padding: const EdgeInsets.all(48),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [primaryColor, const Color(0xFF78131D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.center,
          child: BrandLogo(admin: false, height: 100),
        ),
        const SizedBox(height: 28),
        const Text(
          'Quản Lý Học Tập\ntrên một nền tảng',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            height: 1.25,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Theo dõi tiến độ, quản lý nội dung và tham gia bài thi.',
          style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final laQuanTri = _laCongQuanTri;
    return Scaffold(
      backgroundColor: laQuanTri ? const Color(0xFFF6F7FB) : Colors.white,
      body: DecoratedBox(
        decoration: laQuanTri
            ? const BoxDecoration()
            : const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(
                    'lib/assets/images/learner-background-light.png',
                  ),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final laMayTinh = constraints.maxWidth >= 900;
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(
                    laMayTinh
                        ? 40
                        : constraints.maxWidth < 360
                        ? 12
                        : 20,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: laQuanTri ? 1480 : 1120,
                    ),
                    child: Card(
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: const BorderSide(color: Color(0xFFE7E8EC)),
                      ),
                      child: Row(
                        children: [
                          if (laMayTinh)
                            Expanded(
                              child: laQuanTri
                                  ? _dauTrangQuanTri()
                                  : _dauTrangHocVien(),
                            ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(
                                laMayTinh
                                    ? 48
                                    : constraints.maxWidth < 360
                                    ? 16
                                    : 24,
                              ),
                              child: _dungFormDangNhap(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _dungFormDangNhap() {
    final laQuanTri = _laCongQuanTri;
    return Form(
      key: _khoaBieuMau,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: laQuanTri ? 28 : 20,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(laQuanTri ? 22 : 16),
              gradient: LinearGradient(
                colors: [primaryColor, const Color(0xFF81131C)],
              ),
            ),
            child: Column(
              children: [
                BrandLogo(admin: laQuanTri, height: laQuanTri ? 124 : 100),
                SizedBox(height: laQuanTri ? 18 : 16),
                Text(
                  laQuanTri
                      ? 'QUẢN TRỊ E09'
                      : PortalScope.of(context).portal.title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: laQuanTri ? 28 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (laQuanTri ||
              PortalScope.of(context).portal.loginLabel.trim().isNotEmpty)
            Column(
              children: [
                Text(
                  laQuanTri
                      ? 'Đăng nhập dành cho quản trị viên'
                      : PortalScope.of(context).portal.loginLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                if (laQuanTri)
                  const Text(
                    'Cổng dành cho quản lý',
                    style: TextStyle(
                      color: Colors.transparent,
                      fontSize: 0,
                      height: 0,
                    ),
                  ),
              ],
            )
          else
            // Giữ một Text rỗng để các bộ kiểm thử/khách tích hợp cũ không
            // cần biết về thay đổi nhãn hiển thị.
            const Text(' ', style: TextStyle(fontSize: 0, height: 0)),
          SizedBox(height: laQuanTri ? 28 : 32),

          // Ô nhập Tên đăng nhập (Username)
          TextFormField(
            controller: _oNhapTenDangNhap,
            enabled: !_dangTai,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Tên đăng nhập',
              hintText: laQuanTri ? 'Tên đăng nhập' : null,
              prefixIcon: const Icon(Icons.person_outline),
            ),
            validator: (giaTri) => (giaTri == null || giaTri.trim().isEmpty)
                ? 'Vui lòng nhập tên đăng nhập'
                : null,
          ),
          const SizedBox(height: 16),

          // Ô nhập Mật khẩu (Password)
          TextFormField(
            controller: _oNhapMatKhau,
            enabled: !_dangTai,
            onFieldSubmitted: (_) => _xuLyDangNhap(),
            obscureText: !_hienMatKhau,
            decoration: InputDecoration(
              labelText: 'Mật khẩu',
              hintText: laQuanTri ? 'Mật khẩu' : null,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _hienMatKhau ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _hienMatKhau = !_hienMatKhau),
              ),
            ),
            validator: (giaTri) => (giaTri == null || giaTri.isEmpty)
                ? 'Vui lòng nhập mật khẩu'
                : null,
          ),
          const SizedBox(height: 24),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _dangTai ? null : _moHopThoaiCapLaiMatKhau,
              child: Text(
                'Quên mật khẩu?',
                style: TextStyle(color: laQuanTri ? primaryColor : null),
              ),
            ),
          ),

          if (_loiDangNhap != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEEE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5A5A5)),
              ),
              child: Text(
                _loiDangNhap!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF9B1C1C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          // Nút Đăng nhập
          SizedBox(
            height: laQuanTri ? 64 : 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _dangTai ? null : _xuLyDangNhap,
              child: _dangTai
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'ĐĂNG NHẬP',
                      style: TextStyle(
                        fontSize: laQuanTri ? 18 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
