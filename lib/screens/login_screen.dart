import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../app/app_portal.dart';
import '../models/account_identity.dart';
import '../services/account_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authenticate, this.maintenanceChecker});

  // Injectable boundary for testing login without touching live Firebase.
  final Future<Map<String, dynamic>?> Function(String, String)? authenticate;
  final Future<bool> Function()? maintenanceChecker;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final Color primaryColor = const Color(0xFF6B0000);
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    final scope = PortalScope.of(context);
    setState(() => _isLoading = true);

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

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
      final userData = await authenticate(username, password);

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
        AccountSession.current = null;
        if (widget.authenticate == null) await AccountAuth.signOut();
        if (!mounted) return;
        // Use the same message for invalid credentials and a rejected role.
        // Do not reveal whether this account belongs to the other portal.
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 40 : 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Card(
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: const BorderSide(color: Color(0xFFE7E8EC)),
                    ),
                    child: Row(
                      children: [
                        if (isDesktop)
                          Expanded(
                            child: Container(
                              height: 580,
                              padding: const EdgeInsets.all(48),
                              color: primaryColor,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.school_rounded,
                                    color: Colors.white,
                                    size: 64,
                                  ),
                                  SizedBox(height: 28),
                                  Text(
                                    'Học tập và kiểm tra\ntrên một nền tảng',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 34,
                                      height: 1.25,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Theo dõi tiến độ, tham gia bài thi và quản lý nội dung dễ dàng.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(isDesktop ? 48 : 28),
                            child: _buildLoginForm(),
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
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset(
            'lib/assets/images/logo.png',
            height: 100,
            width: 100,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.school_outlined, size: 80, color: primaryColor);
            },
          ),
          const SizedBox(height: 16),
          Text(
            PortalScope.of(context).portal.title.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryColor,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            PortalScope.of(context).portal.loginLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),

          // Ô nhập Tên đăng nhập (Username)
          TextFormField(
            controller: _usernameController,
            enabled: !_isLoading,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Tên đăng nhập',
              prefixIcon: const Icon(Icons.person_outline),
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Vui lòng nhập tên đăng nhập'
                : null,
          ),
          const SizedBox(height: 16),

          // Ô nhập Mật khẩu (Password)
          TextFormField(
            controller: _passwordController,
            enabled: !_isLoading,
            onFieldSubmitted: (_) => _handleLogin(),
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              labelText: 'Mật khẩu',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
            validator: (value) => (value == null || value.isEmpty)
                ? 'Vui lòng nhập mật khẩu'
                : null,
          ),
          const SizedBox(height: 24),

          // Nút Đăng nhập
          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'ĐĂNG NHẬP',
                      style: TextStyle(
                        fontSize: 16,
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
