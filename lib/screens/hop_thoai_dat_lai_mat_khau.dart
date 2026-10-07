// Hộp thoại yêu cầu đặt lại mật khẩu học viên và khôi phục tài khoản admin tổng.

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/dinh_danh_tai_khoan.dart';
import '../services/du_lieu/dich_vu_firestore.dart';
import '../services/thong_bao_loi_ung_dung.dart';

/// Shows the learner password-reset request dialog.
///
/// The login screen supplies the account actions; this file owns the dialog UI.
Future<void> showPasswordResetDialog({
  required BuildContext context,
  required String initialUsername,
  required bool canRecoverRootAccount,
  required Future<bool> Function({
    required String username,
    required String codeSuffix,
  })
  submitRequest,
  required Future<void> Function(String username) recoverRootAccount,
}) async {
  final screenContext = context;
  var busy = false;
  String? error;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _DialogTextControllers(
      initialValues: [initialUsername, ''],
      builder: (dialogContext, controllers) {
        final username = controllers[0];
        final codeSuffix = controllers[1];
        return StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Quên mật khẩu?'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nhập tên đăng nhập và mã đuôi. Học viên nhập phần sau dấu gạch trong mã người dùng (ví dụ E09-123 thì nhập 123); admin phụ nhập mã đơn vị được gán.',
                  ),
                  if (canRecoverRootAccount) ...[
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : () {
                              Navigator.pop(dialogContext);
                              recoverRootAccount(username.text.trim());
                            },
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text(
                        'Admin tổng: nhờ admin tổng còn lại duyệt',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: username,
                    enabled: !busy,
                    autofocus: username.text.isEmpty,
                    decoration: const InputDecoration(
                      labelText: 'Tên đăng nhập',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeSuffix,
                    enabled: !busy,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Mã đuôi / mã đơn vị',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: Colors.red)),
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
                        final value = username.text.trim();
                        if (!AccountIdentity.isValidUsername(value)) {
                          update(() => error = 'Nhập tên đăng nhập hợp lệ.');
                          return;
                        }
                        final suffix = codeSuffix.text.trim();
                        if (suffix.isEmpty || suffix.length > 100) {
                          update(() => error = 'Nhập mã đuôi hợp lệ.');
                          return;
                        }

                        update(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          final matched = await submitRequest(
                            username: value,
                            codeSuffix: suffix,
                          );
                          if (!matched) {
                            if (!dialogContext.mounted) return;
                            update(() {
                              busy = false;
                              error =
                                  'Bạn nhập sai tài khoản hoặc mã người dùng';
                            });
                            return;
                          }
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(screenContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Yêu cầu đã được gửi đến quản lý phụ trách.',
                              ),
                            ),
                          );
                        } catch (loi) {
                          if (!dialogContext.mounted) return;
                          update(() {
                            busy = false;
                            error = AppErrorMessage.from(
                              loi,
                              feature: 'Gửi yêu cầu đặt lại mật khẩu',
                              fallbackAction: 'Kiểm tra thông tin tài khoản, quyền truy cập và cấu hình máy chủ rồi thử lại.',
                            );
                          });
                        }
                      },
                child: Text(busy ? 'Đang gửi…' : 'Gửi yêu cầu'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Runs the two-admin recovery flow for a root administrator account.
Future<void> showRootPasswordRecoveryDialog({
  required BuildContext screenContext,
  required String initialUsername,
}) async {
  String? proof;
  var sent = false;
  var approved = false;
  var busy = false;
  String? error;
  String? notice;

  await showDialog<void>(
    context: screenContext,
    barrierDismissible: false,
    builder: (dialogContext) => _DialogTextControllers(
      initialValues: [initialUsername, '', ''],
      builder: (dialogContext, controllers) {
        final username = controllers[0];
        final password = controllers[1];
        final confirm = controllers[2];
        return StatefulBuilder(
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
                            if (!dialogContext.mounted) return;
                            update(() {
                              approved = status == 'approved';
                              if (status == 'expired' ||
                                  status == 'not_found') {
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
                          } catch (loi) {
                            if (dialogContext.mounted) {
                              update(
                                () => error = AppErrorMessage.from(
                                  loi,
                                  feature:
                                      'Kiểm tra trạng thái khôi phục mật khẩu',
                                  fallbackAction: 'Kiểm tra kết nối và cấu hình máy chủ rồi thử lại.',
                                ),
                              );
                            }
                          } finally {
                            if (dialogContext.mounted) {
                              update(() => busy = false);
                            }
                          }
                        },
                  child: const Text('Kiểm tra duyệt'),
                ),
              FilledButton(
                onPressed: busy || (sent && !approved)
                    ? null
                    : () async {
                        if (!sent &&
                            !AccountIdentity.isValidUsername(
                              username.text.trim(),
                            )) {
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
                            if (!dialogContext.mounted) return;
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
                          if (!screenContext.mounted) return;
                          ScaffoldMessenger.of(screenContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Đã đổi mật khẩu admin tổng. Hãy đăng nhập lại.',
                              ),
                            ),
                          );
                        } catch (loi) {
                          if (!dialogContext.mounted) return;
                          update(() {
                            busy = false;
                            error = AppErrorMessage.from(
                              loi,
                              feature: approved
                                  ? 'Đặt lại mật khẩu quản trị tổng'
                                  : 'Gửi yêu cầu khôi phục mật khẩu quản trị tổng',
                              fallbackAction: 'Kiểm tra thông tin tài khoản, quyền quản trị và cấu hình máy chủ rồi thử lại.',
                            );
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
        );
      },
    ),
  );
}

class _DialogTextControllers extends StatefulWidget {
  const _DialogTextControllers({
    required this.initialValues,
    required this.builder,
  });

  final List<String> initialValues;
  final Widget Function(
    BuildContext context,
    List<TextEditingController> controllers,
  )
  builder;

  @override
  State<_DialogTextControllers> createState() => _DialogTextControllersState();
}

class _DialogTextControllersState extends State<_DialogTextControllers> {
  late final List<TextEditingController> _controllers = widget.initialValues
      .map((value) => TextEditingController(text: value))
      .toList(growable: false);

  @override
  Widget build(BuildContext context) => widget.builder(context, _controllers);

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
