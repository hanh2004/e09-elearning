import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/account_identity.dart';
import '../../services/account_auth.dart';
import '../../services/firestore_service.dart';
import '../login_screen.dart';
import 'admin_user_import_dialog.dart';
import 'admin_requests_screen.dart';
import '../../widgets/learning_widgets.dart';

class AdminAccountScreen extends StatefulWidget {
  const AdminAccountScreen({super.key, this.service});
  final FirestoreService? service;
  @override
  State<AdminAccountScreen> createState() => _AdminAccountScreenState();
}

class _AdminAccountScreenState extends State<AdminAccountScreen> {
  late final FirestoreService _service = widget.service ?? FirestoreService();
  String _search = '';
  AccountIdentity? get _identity => AccountSession.current;

  String _accountError(Object error) {
    if (error is AccountProvisioningException) return error.message;
    if (error is FirebaseFunctionsException) {
      return error.message ?? 'Không thể hoàn tất thao tác tài khoản.';
    }
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'email-already-in-use' => 'Tên đăng nhập đã tồn tại.',
        'weak-password' => 'Mật khẩu chưa đủ mạnh.',
        'network-request-failed' =>
          'Mất kết nối Firebase. Kiểm tra mạng rồi thử lại.',
        'operation-not-allowed' =>
          'Firebase Authentication chưa bật đăng nhập Email/Mật khẩu.',
        _ => 'Không thể tạo thông tin đăng nhập (${error.code}).',
      };
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Tài khoản hiện tại không có quyền thực hiện thao tác này.',
        'unavailable' => 'Firebase đang mất kết nối. Vui lòng thử lại.',
        _ => 'Firebase chưa hoàn tất thao tác (${error.code}).',
      };
    }
    return 'Chưa hoàn tất: $error';
  }

  Future<void> _showUserDialog({
    String? id,
    Map<String, dynamic>? user,
    bool propose = false,
  }) async {
    if (_identity?.isAdmin != true || (propose && !_identity!.isRoot)) return;
    if (id != null && !_identity!.canEdit(id, user!)) return;
    final name = TextEditingController(text: user?['name'] ?? '');
    final username = TextEditingController(text: user?['username'] ?? '');
    final password = TextEditingController();
    final unit = TextEditingController(text: user?['unit'] ?? '');
    final form = GlobalKey<FormState>();
    var busy = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: Text(
              propose
                  ? 'Đề xuất Admin phụ'
                  : id == null
                  ? 'Thêm User'
                  : 'Sửa tài khoản',
            ),
            content: SizedBox(
              width: 430,
              child: Form(
                key: form,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (propose)
                        const Text(
                          'Tài khoản chỉ hoạt động sau khi admin tổng còn lại đồng ý.',
                        ),
                      if (propose)
                        TextFormField(
                          controller: unit,
                          decoration: const InputDecoration(
                            labelText: 'Đơn vị admin phụ',
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty || v.length > 200
                              ? 'Nhập đơn vị, tối đa 200 ký tự.'
                              : null,
                        ),
                      if (id == null && !propose)
                        const Text(
                          'Học viên tự động thuộc đơn vị của admin tạo tài khoản.',
                        ),
                      TextFormField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'Họ và tên',
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty || v.length > 100
                            ? 'Nhập họ tên, tối đa 100 ký tự.'
                            : null,
                      ),
                      TextFormField(
                        controller: username,
                        enabled: id == null,
                        decoration: const InputDecoration(
                          labelText: 'Tên đăng nhập',
                        ),
                        validator: (v) =>
                            v == null ||
                                !RegExp(r'^[A-Za-z0-9_.@-]{3,64}$').hasMatch(v)
                            ? 'Tên đăng nhập 3–64 ký tự không dấu, không khoảng trắng.'
                            : null,
                      ),
                      if (id == null)
                        TextFormField(
                          controller: password,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Mật khẩu',
                          ),
                          validator: (v) =>
                              v == null || v.length < 6 || v.length > 128
                              ? 'Mật khẩu từ 6 đến 128 ký tự.'
                              : null,
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Bản Firebase miễn phí hiện chỉ cho sửa họ tên; '
                            'không đổi mật khẩu của tài khoản khác tại đây.',
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        propose
                            ? 'Vai trò: Admin phụ (chờ duyệt)'
                            : id == null
                            ? 'Vai trò: User (Học viên)'
                            : 'Không thay đổi vai trò hoặc người tạo qua màn hình sửa.',
                      ),
                      if (error != null)
                        Text(error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        update(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          if (propose) {
                            await _service.proposeAdmin(
                              name: name.text.trim(),
                              username: username.text,
                              password: password.text,
                              unit: unit.text.trim(),
                            );
                          } else if (id != null) {
                            await _service.updateUser(
                              docId: id,
                              name: name.text.trim(),
                              username: username.text,
                              password: password.text,
                              role: user!['role'].toString(),
                            );
                          } else {
                            await _service.addUser(
                              name: name.text.trim(),
                              username: username.text,
                              password: password.text,
                              role: 'user',
                            );
                          }
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            update(() {
                              busy = false;
                              error = _accountError(e);
                            });
                          }
                        }
                      },
                child: Text(
                  busy
                      ? 'Đang xử lý…'
                      : propose
                      ? 'Gửi yêu cầu'
                      : id == null
                      ? 'Thêm'
                      : 'Cập nhật',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // Dispose after the dialog's exit animation has removed its text fields.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    username.dispose();
    password.dispose();
    unit.dispose();
  }

  Future<void> _import() async {
    final count = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdminUserImportDialog(service: _service),
    );
    if (mounted && count != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã thêm $count User từ Excel.')));
    }
  }

  Future<void> _delete(String id, Map<String, dynamic> user) async {
    if (_identity?.canDelete(id, user) != true) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Xóa vĩnh viễn tài khoản "${user['username']}" và toàn bộ bài làm? '
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
      await _service.deleteUser(id);
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
            .showSnackBar(SnackBar(content: Text(_accountError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_identity?.isAdmin != true) {
      return const Scaffold(
        body: Center(child: Text('Cần đăng nhập quản trị.')),
      );
    }
    final root = _identity!.isRoot;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFFB51F24),
        foregroundColor: Colors.white,
        title: Text(root ? 'Quản lý Tài khoản' : 'User do tôi tạo'),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _import,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Nhập User từ Excel'),
                ),
                if (root)
                  OutlinedButton.icon(
                    onPressed: () => _showUserDialog(propose: true),
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('Đề xuất Admin phụ'),
                  ),
                if (root)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminRequestsScreen(service: _service),
                      ),
                    ),
                    icon: const Icon(Icons.approval),
                    label: const Text('Duyệt Admin phụ'),
                  ),
              ],
            ),
          ),
          if (!root)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Admin phụ được quản lý User và các chức năng hệ thống, nhưng chỉ xóa được User do mình tạo; không được tạo bài thi/câu hỏi hoặc quản lý Admin.',
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tìm kiếm tên hoặc tài khoản...',
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _service.getUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Không tải được danh sách. Kiểm tra quyền và kết nối.',
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final creatorNames = <String, String>{
                  for (final doc in snapshot.data!.docs)
                    doc.id:
                        (doc.data()['name'] ?? doc.data()['username'] ?? doc.id)
                            .toString(),
                };
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data();
                  return data['status'] != 'deleted' &&
                      data['status'] != 'rejected' &&
                      '${data['name']} ${data['username']}'
                          .toLowerCase()
                          .contains(_search);
                }).toList();
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Không tìm thấy tài khoản nào'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final user = doc.data();
                    final role = switch (user['role']) {
                      'super_admin' => 'Admin tổng',
                      'admin' => 'Admin phụ',
                      'user' => 'User',
                      _ => 'Tài khoản cũ chưa được cấp quyền',
                    };
                    final creatorId = user['createdBy']?.toString();
                    final creatorLabel = user['role'] == 'user'
                        ? '\nTạo bởi: ${creatorId == null ? 'Dữ liệu cũ/không xác định' : creatorNames[creatorId] ?? creatorId}'
                        : '';
                    return Card(
                      child: ListTile(
                        title: Text(user['name']?.toString() ?? ''),
                        subtitle: Text(
                          '${user['username']} • $role${user['status'] == 'active'
                              ? ''
                              : user['status'] == 'blocked'
                              ? ' • Đã khóa'
                              : ' • Chờ xử lý'}\nĐơn vị: ${user['role'] == 'super_admin' ? 'E09' : user['unit'] ?? 'Chưa phân đơn vị'}${(user['subUnit'] as String? ?? '').isEmpty ? '' : '\nTrực thuộc: ${user['subUnit']}'}$creatorLabel',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (root && user['role'] == 'admin')
                              IconButton(
                                tooltip: 'Phân đơn vị',
                                icon: const Icon(Icons.apartment),
                                onPressed: () => editLearningRecord(
                                  context,
                                  title: 'Phân đơn vị admin và học viên do admin tạo',
                                  fields: {'Đơn vị': user['unit'] ?? ''},
                                  maxLengths: {'Đơn vị': 200},
                                  save: (v) => _service.setAdminUnit(
                                    doc.id,
                                    v['Đơn vị']!,
                                  ),
                                ),
                              ),
                            if (root &&
                                user['role'] != 'super_admin' &&
                                ['active', 'blocked'].contains(user['status']))
                              IconButton(
                                tooltip: user['status'] == 'blocked'
                                    ? 'Mở khóa'
                                    : 'Khóa tài khoản',
                                icon: Icon(
                                  user['status'] == 'blocked'
                                      ? Icons.lock_open
                                      : Icons.lock_outline,
                                ),
                                onPressed: () async {
                                  try {
                                    await _service.setUserBlocked(
                                      doc.id,
                                      user['status'] != 'blocked',
                                    );
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(_accountError(error)),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            if (_identity!.canEdit(doc.id, user))
                              IconButton(
                                tooltip: 'Sửa tài khoản',
                                icon: const Icon(Icons.edit),
                                onPressed: () =>
                                    _showUserDialog(id: doc.id, user: user),
                              ),
                            if (_identity!.canDelete(doc.id, user))
                              IconButton(
                                tooltip: user['role'] == 'admin'
                                    ? 'Xóa Admin phụ'
                                    : 'Xóa User',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(doc.id, user),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(),
        tooltip: 'Thêm User',
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
