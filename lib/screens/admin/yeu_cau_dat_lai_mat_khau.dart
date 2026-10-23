// WEB ADMIN: Danh sách tài khoản đã gửi yêu cầu cấp lại mật khẩu.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/dinh_danh_tai_khoan.dart';
import '../../models/yeu_cau_cap_lai_mat_khau.dart';
import '../../services/du_lieu/dich_vu_firestore.dart';
import '../../widgets/giao_dien_quan_tri.dart';
import '../../widgets/thong_bao_loi.dart';
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
  late final _luongYeuCau = _dichVu.getPasswordResetRequestsStream();
  bool _dangXuLy = false;

  String _loi(Object loi) => loi.toString().replaceFirst('Exception: ', '');

  Future<void> _duyet(PasswordResetRequest banGhi) async {
    setState(() => _dangXuLy = true);
    try {
      if (banGhi.isRootRecovery) {
        await _dichVu.approveRootPasswordReset(banGhi.id);
      } else {
        await _dichVu.approvePasswordReset(banGhi.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              banGhi.isRootRecovery
                  ? 'Đã ghi nhận lượt duyệt.'
                  : 'Đã đồng ý cấp lại mật khẩu.',
            ),
          ),
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

  Future<void> _datLai(PasswordResetRequest banGhi) async {
    final duLieu = banGhi.data;
    final giaTri = await showDialog<String>(
      context: context,
      builder: (_) => _PasswordResetDialog(
        name: '${duLieu['name'] ?? duLieu['username'] ?? ''}',
        username: '${duLieu['username'] ?? ''}',
        actor: AccountSession.current!,
        requestUpdates: _dichVu.getPasswordResetRequestStream(banGhi.id),
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
    final actor = danhTinh!;
    final noiDung = StreamBuilder<List<PasswordResetRequest>>(
      stream: _luongYeuCau,
      builder: (context, duLieuNhan) {
        if (duLieuNhan.hasError) {
          return AppErrorNotice(
            error: duLieuNhan.error!,
            feature: 'Tải yêu cầu cấp lại mật khẩu',
            fallbackAction:
                'Kiểm tra quyền quản trị và kết nối máy chủ rồi tải lại.',
          );
        }
        if (!duLieuNhan.hasData) {
          return const AdminLoading();
        }
        final cacBanGhi = duLieuNhan.data!.toList()
          ..sort(
            (a, b) =>
                ((b.data['requestedAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0)
                    .compareTo(
                      (a.data['requestedAt'] as Timestamp?)
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
            final duLieu = banGhi.data;
            final state = banGhi.status;
            final root = actor.isRoot;
            final isRootRecovery = banGhi.isRootRecovery;
            final recoveryExpired = banGhi.recoveryExpired;
            final canApproveRootRecovery = banGhi.canApproveRootRecoveryBy(
              actor,
            );
            final canResolveRequest = banGhi.canResolveBy(actor);
            final canApproveAdminReset = banGhi.canApproveAdminResetBy(actor);
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.lock_reset)),
                title: Text(
                  '${duLieu['name'] ?? ''} (${duLieu['username'] ?? ''})',
                ),
                subtitle: Text(
                  state == 'processing'
                      ? banGhi.processingMessage
                      : isRootRecovery
                      ? recoveryExpired
                            ? 'Yêu cầu đã hết hạn — admin tổng cần gửi lại'
                            : state == 'approved'
                            ? 'Đã duyệt — admin tổng yêu cầu tự đặt mật khẩu mới'
                            : 'Chờ admin tổng còn lại duyệt yêu cầu khôi phục'
                      : banGhi.isAdminAccount
                      ? canResolveRequest
                            ? 'Cả hai quản lý tổng đã đồng ý. Một bên cấp lại thành công là hoàn tất.'
                            : state == 'approved_once'
                            ? duLieu['firstApprovedBy'] == actor.id
                                  ? 'Bạn đã đồng ý. Đang chờ quản lý tổng còn lại.'
                                  : 'Một quản lý tổng đã đồng ý. Cần bạn đồng ý để cấp lại.'
                            : 'Cần cả hai quản lý tổng đồng ý trước khi nhập mật khẩu mới.'
                      : canResolveRequest
                      ? 'Yêu cầu đang chờ bạn cấp lại mật khẩu'
                      : root
                      ? 'Đang chờ quản lý phụ trách cấp lại mật khẩu'
                      : 'Đang chờ quản lý phụ trách xử lý',
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
                    : canApproveAdminReset
                    ? FilledButton(
                        onPressed: _dangXuLy ? null : () => _duyet(banGhi),
                        child: const Text('Đồng ý cấp lại'),
                      )
                    : canResolveRequest
                    ? FilledButton(
                        onPressed: _dangXuLy ? null : () => _datLai(banGhi),
                        child: Text(
                          banGhi.isAdminAccount
                              ? 'Nhập mật khẩu mới'
                              : 'Cấp lại mật khẩu',
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
  const _PasswordResetDialog({
    required this.name,
    required this.username,
    required this.actor,
    required this.requestUpdates,
  });

  final String name;
  final String username;
  final AccountIdentity actor;
  final Stream<PasswordResetRequest?> requestUpdates;

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
  Widget build(BuildContext context) => StreamBuilder<PasswordResetRequest?>(
    stream: widget.requestUpdates,
    builder: (context, snapshot) {
      final waiting = snapshot.connectionState == ConnectionState.waiting;
      final canEnter =
          !waiting &&
          !snapshot.hasError &&
          snapshot.data?.canResolveBy(widget.actor) == true;
      return AlertDialog(
        title: Text('Cấp lại mật khẩu cho ${widget.name}'),
        content: SizedBox(
          width: 420,
          child: waiting
              ? const SizedBox(
                  height: 64,
                  child: Center(child: CircularProgressIndicator()),
                )
              : snapshot.hasError
              ? AppErrorNotice(
                  error: snapshot.error!,
                  feature: 'Theo dõi yêu cầu cấp lại mật khẩu',
                )
              : !canEnter
              ? Text(
                  snapshot.data?.status == 'processing'
                      ? snapshot.data!.processingMessage
                      : snapshot.data?.status == 'completed' ||
                            snapshot.data == null
                      ? 'Yêu cầu đã hoàn tất. Không cần cấp lại mật khẩu nữa.'
                      : 'Yêu cầu chưa được cả hai quản lý tổng đồng ý.',
                )
              : Form(
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
                              _visible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _visible = !_visible),
                          ),
                        ),
                        validator: (value) =>
                            value == null ||
                                value.length < 6 ||
                                value.length > 128
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
            child: Text(canEnter ? 'Hủy' : 'Đóng'),
          ),
          if (canEnter)
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
    },
  );
}
