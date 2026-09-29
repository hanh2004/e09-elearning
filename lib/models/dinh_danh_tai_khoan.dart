// DỮ LIỆU: Thông tin tài khoản hiện tại và các điều kiện kiểm tra vai trò trong giao diện.
// Giữ tên trường Firebase khi đổi cách hiển thị để đọc được dữ liệu đã lưu.

class AccountIdentity {
  const AccountIdentity({required this.id, required this.role});

  static final RegExp _usernamePattern = RegExp(r'^[A-Za-z0-9_.@-]{3,64}$');
  static bool isValidUsername(String value) => _usernamePattern.hasMatch(value);

  final String id;
  final String role;
  bool get isRoot => role == 'super_admin';
  bool get isAdmin => isRoot || role == 'admin';
  bool canDelete(String targetId, Map<String, dynamic> target) =>
      target['role'] != 'super_admin' &&
      const ['active', 'blocked', 'deleting'].contains(target['status']) &&
      (isRoot ||
          (role == 'admin' &&
              target['role'] == 'user' &&
              target['createdBy'] == id));
  bool canEdit(String targetId, Map<String, dynamic> target) =>
      target['role'] != 'super_admin' &&
      (isRoot ||
          (role == 'admin' &&
              target['role'] == 'user' &&
              target['createdBy'] == id)) &&
      target['status'] == 'active';
}

// Chỉ là gợi ý cho giao diện. Máy chủ luôn đọc lại hồ sơ của phiên đăng nhập.
class AccountSession {
  static AccountIdentity? current;
}
