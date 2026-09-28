// GÓP Ý: Học viên gửi phản hồi sau khi xác thực lại tài khoản.
// Mật khẩu chỉ đi đến Firebase Auth để xác thực, không gửi lên API góp ý.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/cau_hinh_ung_dung.dart';
import '../../app/chu_de_ung_dung.dart';
import '../../services/tai_khoan/xac_thuc_tai_khoan.dart';
import '../../widgets/dau_trang_hoc_vien.dart';

class UserFeedbackScreen extends StatefulWidget {
  const UserFeedbackScreen({super.key});

  @override
  State<UserFeedbackScreen> createState() => _UserFeedbackScreenState();
}

class _UserFeedbackScreenState extends State<UserFeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _message = TextEditingController();
  String _category = 'idea';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      setState(
        () => _error = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final typedUsername = _username.text.trim();
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      final savedUsername = (profile.data()?['username'] as String? ?? '')
          .trim();
      final expectedEmail = accountLoginEmail(typedUsername);
      if (profile.data()?['status'] != 'active' ||
          savedUsername.toLowerCase() != typedUsername.toLowerCase() ||
          user.email!.toLowerCase() != expectedEmail.toLowerCase()) {
        throw FirebaseAuthException(code: 'invalid-credential');
      }

      // Đây là thao tác duy nhất nhận mật khẩu. Không đưa mật khẩu vào callable,
      // Firestore, analytics hay log.
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: expectedEmail,
          password: _password.text,
        ),
      );
      _password.clear();
      await user.getIdToken(true);

      await FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion)
          .httpsCallable('feedbackSubmit')
          .call<Map<String, dynamic>>({
            'category': _category,
            'message': _message.text.trim(),
          });

      if (!mounted) return;
      _message.clear();
      _password.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi góp ý. Cảm ơn bạn!')),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.code == 'network-request-failed'
              ? 'Không có kết nối mạng. Hãy thử lại.'
              : 'Tên đăng nhập hoặc mật khẩu không chính xác.';
        });
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.message ?? 'Chưa gửi được góp ý. Hãy thử lại.',
        );
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.code == 'unavailable'
              ? 'Không kết nối được máy chủ. Hãy thử lại.'
              : 'Không thể xác minh tài khoản. Hãy thử lại.',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Có lỗi xảy ra. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: LearnerHeader(
      title: const Text('Góp ý ứng dụng'),
      backgroundColor: AppTheme.red,
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Chia sẻ lỗi bạn gặp hoặc ý tưởng giúp ứng dụng tốt hơn. Nội dung chỉ admin tổng xem được.',
                  style: TextStyle(fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Loại góp ý',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'idea', child: Text('Ý tưởng')),
                    DropdownMenuItem(value: 'bug', child: Text('Báo lỗi')),
                    DropdownMenuItem(value: 'other', child: Text('Khác')),
                  ],
                  onChanged: _sending
                      ? null
                      : (value) => setState(() => _category = value ?? 'idea'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _message,
                  minLines: 5,
                  maxLines: 8,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung góp ý',
                    hintText: 'Mô tả chi tiết điều bạn muốn góp ý…',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final length = value?.trim().length ?? 0;
                    if (length < 10) return 'Nhập ít nhất 10 ký tự.';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Xác thực lại để gửi góp ý',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _username,
                  enabled: !_sending,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    labelText: 'Tên đăng nhập',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nhập tên đăng nhập.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  enabled: !_sending,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Nhập mật khẩu để xác thực.'
                      : null,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mật khẩu chỉ được gửi tới Firebase để xác minh và không được lưu trong góp ý.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppTheme.red)),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _sending ? null : _submit,
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_sending ? 'Đang gửi…' : 'Gửi góp ý'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
