// WEB ADMIN: Danh sách học viên đã gửi yêu cầu cấp lại mật khẩu.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/dinh_danh_tai_khoan.dart';
import '../../services/du_lieu/dich_vu_firestore.dart';
import '../../widgets/giao_dien_quan_tri.dart';
import 'khung_giao_dien_quan_tri.dart';

class AdminPasswordResetScreen extends StatefulWidget {
  const AdminPasswordResetScreen({
    super.key,
    this.service,
    this.embedded = false,
  });
  final FirestoreService? service;
  final bool embedded;

  @override
  State<AdminPasswordResetScreen> createState() =>
      _TrangThaiCapLaiMatKhauQuanTri();
}

class _TrangThaiCapLaiMatKhauQuanTri extends State<AdminPasswordResetScreen> {
  late final FirestoreService _dichVu = widget.service ?? FirestoreService();
  bool _dangXuLy = false;

  String _loi(Object loi) => loi.toString().replaceFirst('Exception: ', '');

  Future<void> _duyet(
    QueryDocumentSnapshot<Map<String, dynamic>> banGhi,
  ) async {
    setState(() => _dangXuLy = true);
    try {
      if (banGhi.data()['type'] == 'root_recovery') {
        await _dichVu.approveRootPasswordReset(banGhi.id);
      } else {
        await _dichVu.approvePasswordReset(banGhi.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã ghi nhận lượt duyệt.')),
        );
      }
    } catch (loi) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_loi(loi))));
      }
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  Future<void> _datLai(
    QueryDocumentSnapshot<Map<String, dynamic>> banGhi,
  ) async {
    final duLieu = banGhi.data();
    final giaTri = await showDialog<String>(
      context: context,
      builder: (_) => _PasswordResetDialog(
        name: '${duLieu['name'] ?? duLieu['username'] ?? ''}',
        username: '${duLieu['username'] ?? ''}',
      ),
    );
    if (giaTri == null || !mounted) return;
    setState(() => _dangXuLy = true);
    try {
      await _dichVu.resolvePasswordReset(
        requestId: banGhi.id,
        userId: duLieu['userId'].toString(),
        password: giaTri,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cấp lại mật khẩu. Yêu cầu đã hoàn tất.'),
          ),
        );
      }
    } catch (loi) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_loi(loi))));
      }
    } finally {
      if (mounted) {
        setState(() => _dangXuLy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final danhTinh = AccountSession.current;
    if (danhTinh?.isAdmin != true) {
      return const Scaffold(
        body: Center(child: Text('Cần đăng nhập quản trị.')),
      );
    }
    final noiDung = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _dichVu.getPasswordResetRequestsStream(),
      builder: (context, duLieuNhan) {
        if (duLieuNhan.hasError) {
          return const Center(
            child: Text('Không tải được yêu cầu cấp lại mật khẩu.'),
          );
        }
        if (!duLieuNhan.hasData) {
          return const AdminLoading();
        }
        final cacBanGhi = duLieuNhan.data!.docs.toList()
          ..sort(
            (a, b) =>
                ((b.data()['requestedAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0)
                    .compareTo(
                      (a.data()['requestedAt'] as Timestamp?)
                              ?.millisecondsSinceEpoch ??
                          0,
                    ),
          );
        if (cacBanGhi.isEmpty) {
          return const Center(
            child: Text('Chưa có yêu cầu cấp lại mật khẩu cần xử lý.'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: cacBanGhi.length,
          itemBuilder: (context, viTri) {
            final banGhi = cacBanGhi[viTri];
            final duLieu = banGhi.data();
            final state = duLieu['status']?.toString();
            final root = danhTinh!.isRoot;
            final isRootRecovery = duLieu['type'] == 'root_recovery';
            final expiresAt = duLieu['expiresAt'];
            final recoveryExpired =
                expiresAt is Timestamp &&
                expiresAt.toDate().isBefore(DateTime.now());
            final canApproveRootRecovery =
                root &&
                isRootRecovery &&
                state == 'pending' &&
                !recoveryExpired &&
                duLieu['userId'] != danhTinh.id;
            final canResolveRequest =
                !isRootRecovery &&
                state == 'approved' &&
                duLieu['managerId'] == danhTinh.id;
            final canApproveRequest =
                !isRootRecovery &&
                root &&
                (state == 'pending' ||
                    (state == 'approved_once' &&
                        duLieu['firstApprovedBy'] != danhTinh.id));
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.lock_reset)),
                title: Text(
                  '${duLieu['name'] ?? ''} (${duLieu['username'] ?? ''})',
                ),
                subtitle: Text(
                  isRootRecovery
                      ? recoveryExpired
                            ? 'Yêu cầu đã hết hạn — admin tổng cần gửi lại'
                            : state == 'approved'
                            ? 'Đã duyệt — admin tổng yêu cầu tự đặt mật khẩu mới'
                            : 'Chờ admin tổng còn lại duyệt yêu cầu khôi phục'
                      : state == 'processing'
                      ? 'Đang cập nhật mật khẩu…'
                      : root
                      ? state == 'approved'
                            ? canResolveRequest
                                  ? 'Đã được duyệt — có thể cấp lại mật khẩu'
                                  : 'Đã được duyệt — chờ quản lý phụ trách'
                            : state == 'approved_once'
                            ? 'Đã được duyệt lần 1 — chờ quản lý tổng còn lại'
                            : 'Chờ duyệt lần 1'
                      : switch (state) {
                          'pending' =>
                            'Đã nhận yêu cầu — chờ admin tổng duyệt lần 1',
                          'approved_once' =>
                            'Đã duyệt lần 1 — chờ admin tổng còn lại duyệt',
                          'approved' => 'Đã được hai admin tổng duyệt — có thể cấp lại mật khẩu',
                          _ => 'Đang chờ xử lý',
                        },
                ),
                trailing: isRootRecovery
                    ? canApproveRootRecovery
                          ? FilledButton(
                              onPressed: _dangXuLy
                                  ? null
                                  : () => _duyet(banGhi),
                              child: const Text('Duyệt yêu cầu'),
                            )
                          : null
                    : canResolveRequest
                    ? FilledButton(
                        onPressed: _dangXuLy ? null : () => _datLai(banGhi),
                        child: const Text('Cấp lại mật khẩu'),
                      )
                    : canApproveRequest
                    ? FilledButton(
                        onPressed: _dangXuLy ? null : () => _duyet(banGhi),
                        child: Text(
                          state == 'approved_once'
                              ? 'Duyệt lần 2'
                              : 'Duyệt lần 1',
                        ),
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
    if (widget.embedded) return noiDung;
    return AdminResponsiveShell(
      selectedIndex: 0,
      activeExtra: 'Tài khoản',
      onSelected: (viTri) => pushAdminPrimary(context, viTri),
      child: Scaffold(
        backgroundColor: AdminUi.page,
        appBar: AdminUi.appBar('Cấp lại mật khẩu'),
        body: noiDung,
      ),
    );
  }
}

class _PasswordResetDialog extends StatefulWidget {
  const _PasswordResetDialog({required this.name, required this.username});

  final String name;
  final String username;

  @override
  State<_PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<_PasswordResetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _visible = false;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Cấp lại mật khẩu cho ${widget.name}'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tên đăng nhập: ${widget.username}'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: !_visible,
              decoration: InputDecoration(
                labelText: 'Mật khẩu mới',
                suffixIcon: IconButton(
                  icon: Icon(
                    _visible ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _visible = !_visible),
                ),
              ),
              validator: (value) =>
                  value == null || value.length < 6 || value.length > 128
                  ? 'Mật khẩu dài 6–128 ký tự.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmation,
              obscureText: !_visible,
              decoration: const InputDecoration(
                labelText: 'Nhập lại mật khẩu mới',
              ),
              validator: (value) => value != _password.text
                  ? 'Mật khẩu nhập lại không khớp.'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState?.validate() == true) {
            Navigator.pop(context, _password.text);
          }
        },
        child: const Text('Cấp lại'),
      ),
    ],
  );
}
