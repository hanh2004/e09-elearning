// DỮ LIỆU: Một dòng Excel và kết quả xem trước danh sách tài khoản nhập.
// Giữ tên trường Firebase khi đổi cách hiển thị để đọc được dữ liệu đã lưu.

class UserImportRow {
  const UserImportRow({
    required this.rowNumber,
    required this.name,
    required this.username,
    required this.password,
    this.userCodeSuffix,
    this.errors = const [],
  });

  final int rowNumber;
  final String name;
  final String username;
  final String password;
  final String? userCodeSuffix;
  final List<String> errors;

  UserImportRow withError(String thongDiep) => UserImportRow(
    rowNumber: rowNumber,
    name: name,
    username: username,
    password: password,
    userCodeSuffix: userCodeSuffix,
    errors: [...errors, thongDiep],
  );
}

class UserImportPreview {
  const UserImportPreview({this.rows = const [], this.errors = const []});

  static const maxUsers = 200;
  final List<UserImportRow> rows;
  final List<String> errors;
  bool get canImport =>
      rows.isNotEmpty &&
      errors.isEmpty &&
      rows.every((dong) => dong.errors.isEmpty);

  UserImportPreview checkExisting(Iterable<String> usernames) {
    final existing = usernames.map((ten) => ten.trim().toLowerCase()).toSet();
    return UserImportPreview(
      errors: errors,
      rows: rows
          .map(
            (dong) => existing.contains(dong.username.toLowerCase())
                ? dong.withError('Tên đăng nhập đã tồn tại.')
                : dong,
          )
          .toList(),
    );
  }
}
