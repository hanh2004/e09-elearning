// KHỞI TẠO / GIAO DIỆN: Trang đăng nhập chung: xác thực tài khoản rồi chuyển đúng cổng Admin/Học viên.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../widgets/brand_logo.dart';
import '../services/du_lieu/firestore_service.dart';
import '../app/app_portal.dart';
import '../models/account_identity.dart';
import '../services/tai_khoan/account_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.authenticate,
    this.maintenanceChecker,
    this.requestPasswordReset,
  });

  // Điểm thay thế để kiểm thử đăng nhập mà không chạm vào Firebase thật.
  final Future<Map<String, dynamic>?> Function(String, String)? authenticate;
  final Future<bool> Function()? maintenanceChecker;
  final Future<void> Function(String)? requestPasswordReset;

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
    setState(() => _dangTai = true);

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
                'Ứng dụng đang được cập nhật. Vui lòng quay lại sau.',
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

      if (!mounted) return;

      if (userData != null && scope.portal.acceptsRole(userData['role'])) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tên đăng nhập hoặc mật khẩu không chính xác!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể đăng nhập. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  Future<void> _moHopThoaiCapLaiMatKhau() async {
    final tenDangNhap = TextEditingController(text: _oNhapTenDangNhap.text);
    var busy = false;
    String? loi;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Quên mật khẩu?'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nhập tên đăng nhập. Quản lý phụ trách tài khoản sẽ nhận yêu cầu và cấp lại mật khẩu cho bạn.',
                ),
                if (_laCongQuanTri) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () {
                            Navigator.pop(dialogContext);
                            _khoiPhucAdminTong(tenDangNhap.text.trim());
                          },
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text(
                      'Admin tổng: nhờ admin tổng còn lại duyệt',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: tenDangNhap,
                  enabled: !busy,
                  autofocus: tenDangNhap.text.isEmpty,
                  decoration: const InputDecoration(
                    labelText: 'Tên đăng nhập',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                if (loi != null) ...[
                  const SizedBox(height: 10),
                  Text(loi!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final giaTri = tenDangNhap.text.trim();
                      if (!RegExp(r'^[A-Za-z0-9_.@-]{3,64}$')
                          .hasMatch(giaTri)) {
                        update(() => loi = 'Nhập tên đăng nhập hợp lệ.');
                        return;
                      }
                      update(() {
                        busy = true;
                        loi = null;
                      });
                      try {
                        final submit =
                            widget.requestPasswordReset ??
                            FirestoreService().requestPasswordReset;
                        await submit(giaTri);
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Đã gửi yêu cầu. Quản lý phụ trách sẽ cấp lại mật khẩu cho bạn.',
                            ),
                          ),
                        );
                      } catch (_) {
                        update(() {
                          busy = false;
                          loi = 'Không thể gửi yêu cầu. Vui lòng thử lại.';
                        });
                      }
                    },
              child: Text(busy ? 'Đang gửi…' : 'Gửi yêu cầu'),
            ),
          ],
        ),
      ),
    );
    tenDangNhap.dispose();
  }

  Future<void> _khoiPhucAdminTong(String initialUsername) async {
    final username = TextEditingController(text: initialUsername);
    final password = TextEditingController();
    final confirm = TextEditingController();
    String? proof;
    var sent = false;
    var approved = false;
    var busy = false;
    String? error;
    String? notice;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Khôi phục tài khoản admin tổng'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  !sent
                      ? 'Nhập tên đăng nhập của admin tổng cần khôi phục. Admin tổng còn lại phải duyệt yêu cầu.'
                      : approved
                      ? 'Admin tổng còn lại đã duyệt. Nhập mật khẩu mới để hoàn tất.'
                      : 'Yêu cầu đã gửi. Hãy báo admin tổng còn lại đăng nhập và duyệt. Giữ cửa sổ này mở trong lúc chờ.',
                ),
                if (!sent) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: username,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: 'Tên đăng nhập admin tổng',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                ],
                if (approved) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    enabled: !busy,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu mới (8 ký tự trở lên)',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirm,
                    enabled: !busy,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nhập lại mật khẩu mới',
                      prefixIcon: Icon(Icons.lock_reset_outlined),
                    ),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
                if (notice != null) ...[
                  const SizedBox(height: 10),
                  Text(notice!, style: const TextStyle(color: Colors.orange)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            if (sent && !approved)
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        update(() {
                          busy = true;
                          error = null;
                          notice = null;
                        });
                        try {
                          final status = await FirestoreService()
                              .rootPasswordResetStatus(
                                username: username.text.trim(),
                                proof: proof!,
                              );
                          update(() {
                            approved = status == 'approved';
                            if (status == 'expired' || status == 'not_found') {
                              sent = false;
                              proof = null;
                            }
                            notice = switch (status) {
                              'pending' => 'Yêu cầu vẫn đang chờ duyệt.',
                              'expired' || 'not_found' => 'Yêu cầu hết hạn hoặc không hợp lệ. Bạn có thể gửi yêu cầu mới.',
                              'approved' => null,
                              _ =>
                                'Chưa kiểm tra được trạng thái. Hãy thử lại.',
                            };
                          });
                        } catch (_) {
                          update(
                            () => error = 'Không kiểm tra được. Hãy thử lại.',
                          );
                        } finally {
                          update(() => busy = false);
                        }
                      },
                child: const Text('Kiểm tra duyệt'),
              ),
            FilledButton(
              onPressed: busy || (sent && !approved)
                  ? null
                  : () async {
                      if (!sent &&
                          !RegExp(r'^[A-Za-z0-9_.@-]{3,64}$')
                              .hasMatch(username.text.trim())) {
                        update(() => error = 'Nhập tên đăng nhập hợp lệ.');
                        return;
                      }
                      if (approved &&
                          (password.text.length < 8 ||
                              password.text.length > 128 ||
                              password.text != confirm.text)) {
                        update(
                          () => error = 'Mật khẩu cần 8–128 ký tự và hai ô phải giống nhau.',
                        );
                        return;
                      }
                      update(() {
                        busy = true;
                        error = null;
                        notice = null;
                      });
                      try {
                        if (!sent) {
                          final random = Random.secure();
                          proof = base64Url
                              .encode(
                                List<int>.generate(
                                  32,
                                  (_) => random.nextInt(256),
                                ),
                              )
                              .replaceAll('=', '');
                          await FirestoreService().requestRootPasswordReset(
                            username: username.text.trim(),
                            proof: proof!,
                          );
                          update(() {
                            sent = true;
                            busy = false;
                            notice = 'Hãy liên hệ admin tổng còn lại để duyệt yêu cầu.';
                          });
                          return;
                        }
                        await FirestoreService().finishRootPasswordReset(
                          username: username.text.trim(),
                          proof: proof!,
                          password: password.text,
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Đã đổi mật khẩu admin tổng. Hãy đăng nhập lại.',
                            ),
                          ),
                        );
                      } catch (_) {
                        update(() {
                          busy = false;
                          error = approved
                              ? 'Không thể đổi mật khẩu. Hãy thử lại.'
                              : 'Không thể gửi yêu cầu. Hãy kiểm tra tên đăng nhập hoặc thử lại sau.';
                        });
                      }
                    },
              child: Text(
                busy
                    ? 'Đang xử lý…'
                    : approved
                    ? 'Đặt mật khẩu mới'
                    : sent
                    ? 'Đã gửi yêu cầu'
                    : 'Gửi yêu cầu duyệt',
              ),
            ),
          ],
        ),
      ),
    );
    username.dispose();
    password.dispose();
    confirm.dispose();
  }

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
