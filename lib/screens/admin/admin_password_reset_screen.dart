// WEB ADMIN: Danh sách học viên đã gửi yêu cầu cấp lại mật khẩu.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/account_identity.dart';
import '../../services/du_lieu/firestore_service.dart';
import '../../widgets/admin_ui.dart';
import 'admin_responsive_shell.dart';

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
    final matKhau = TextEditingController();
    final confirmation = TextEditingController();
    final form = GlobalKey<FormState>();
    var visible = false;
    final giaTri = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            'Cấp lại mật khẩu cho ${duLieu['name'] ?? duLieu['username']}',
          ),
          content: SizedBox(
            width: 420,
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Tên đăng nhập: ${duLieu['username'] ?? ''}'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: matKhau,
                    obscureText: !visible,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu mới',
                      suffixIcon: IconButton(
                        icon: Icon(
                          visible ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => update(() => visible = !visible),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.length < 6 || v.length > 128
                        ? 'Mật khẩu dài 6–128 ký tự.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmation,
                    obscureText: !visible,
                    decoration: const InputDecoration(
                      labelText: 'Nhập lại mật khẩu mới',
                    ),
                    validator: (v) => v != matKhau.text
                        ? 'Mật khẩu nhập lại không khớp.'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState?.validate() == true) {
                  Navigator.pop(dialogContext, matKhau.text);
                }
              },
              child: const Text('Cấp lại'),
            ),
          ],
        ),
      ),
    );
    matKhau.dispose();
    confirmation.dispose();
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
            final canResolveAdmin =
                !isRootRecovery &&
                root &&
                state == 'approved' &&
                duLieu['managerId'] == danhTinh.id;
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
                      : root
                      ? state == 'approved'
                            ? canResolveAdmin
                                  ? 'Đã được duyệt — có thể cấp lại mật khẩu'
                                  : 'Đã được duyệt — chờ quản lý tổng phụ trách'
                            : state == 'approved_once'
                            ? 'Đã được duyệt lần 1 — chờ quản lý tổng còn lại'
                            : 'Chờ duyệt lần 1'
                      : 'Đã được hai quản lý tổng duyệt',
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
                    : canResolveAdmin
                    ? FilledButton(
                        onPressed: _dangXuLy ? null : () => _datLai(banGhi),
                        child: const Text('Cấp lại mật khẩu'),
                      )
                    : root && state != 'approved'
                    ? FilledButton(
                        onPressed: _dangXuLy ? null : () => _duyet(banGhi),
                        child: Text(
                          state == 'approved_once'
                              ? 'Duyệt lần 2'
                              : 'Duyệt lần 1',
                        ),
                      )
                    : !root
                    ? FilledButton(
                        onPressed: _dangXuLy ? null : () => _datLai(banGhi),
                        child: const Text('Cấp lại mật khẩu'),
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
