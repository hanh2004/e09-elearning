import 'package:cloud_firestore/cloud_firestore.dart';

import 'dinh_danh_tai_khoan.dart';

/// Yêu cầu cấp lại mật khẩu sau khi đã bổ sung vai trò từ hồ sơ nếu cần.
class PasswordResetRequest {
  const PasswordResetRequest({required this.id, required this.data});

  static const openStatuses = [
    'pending',
    'approved_once',
    'approved',
    'processing',
  ];

  final String id;
  final Map<String, dynamic> data;

  bool get isRootRecovery => data['type'] == 'root_recovery';
  bool get isAdminAccount => !isRootRecovery && data['userRole'] == 'admin';
  String? get status => data['status'] as String?;
  String get processingMessage => data['processingIssue'] == 'password_updated'
      ? 'Mật khẩu đã cập nhật nhưng chưa hoàn tất xác nhận. Yêu cầu đã khóa; liên hệ người phụ trách hệ thống kiểm tra.'
      : data['processingIssue'] == 'result_unknown'
      ? 'Chưa xác nhận được kết quả cập nhật mật khẩu. Yêu cầu đã khóa; liên hệ người phụ trách hệ thống kiểm tra.'
      : 'Đang cập nhật mật khẩu. Yêu cầu đã khóa thao tác cấp lại.';
  bool get recoveryExpired {
    final expiresAt = data['expiresAt'];
    return expiresAt is Timestamp &&
        expiresAt.toDate().isBefore(DateTime.now());
  }

  bool isVisibleTo(AccountIdentity actor) {
    if (!actor.isAdmin) return false;
    if (isRootRecovery) {
      return actor.isRoot && data['userId'] != actor.id;
    }
    return data['managerId'] == actor.id ||
        (actor.isRoot && data['userRole'] == 'admin');
  }

  bool canResolveBy(AccountIdentity actor) {
    if (!isVisibleTo(actor) ||
        isRootRecovery ||
        !const ['pending', 'approved_once', 'approved'].contains(status)) {
      return false;
    }
    return isAdminAccount
        ? actor.isRoot &&
              status == 'approved' &&
              data['firstApprovedBy'] is String &&
              data['secondApprovedBy'] is String &&
              (data['firstApprovedBy'] as String).isNotEmpty &&
              (data['secondApprovedBy'] as String).isNotEmpty &&
              data['firstApprovedBy'] != data['secondApprovedBy'] &&
              [
                data['firstApprovedBy'],
                data['secondApprovedBy'],
              ].contains(actor.id)
        : data['managerId'] == actor.id;
  }

  bool canApproveAdminResetBy(AccountIdentity actor) =>
      actor.isRoot &&
      isVisibleTo(actor) &&
      isAdminAccount &&
      (status == 'pending' ||
          (status == 'approved_once' && data['firstApprovedBy'] != actor.id));

  bool canApproveRootRecoveryBy(AccountIdentity actor) =>
      isRootRecovery &&
      isVisibleTo(actor) &&
      status == 'pending' &&
      !recoveryExpired;

  bool needsAttentionFor(AccountIdentity actor) =>
      canResolveBy(actor) ||
      canApproveAdminResetBy(actor) ||
      canApproveRootRecoveryBy(actor);
}
