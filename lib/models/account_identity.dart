class AccountIdentity {
  const AccountIdentity({required this.id, required this.role});
  final String id;
  final String role;
  bool get isRoot => role == 'super_admin';
  bool get isAdmin => isRoot || role == 'admin';
  bool canDelete(String targetId, Map<String, dynamic> target) =>
      target['role'] != 'super_admin' &&
      target['status'] == 'active' &&
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

// UI hint only. Server authorization always reloads the authenticated profile.
class AccountSession {
  static AccountIdentity? current;
}
