// DỮ LIỆU: Một dòng Excel và kết quả xem trước danh sách tài khoản nhập.
// Giữ tên trường Firebase khi đổi cách hiển thị để đọc được dữ liệu đã lưu.

class UserImportRow {
  const UserImportRow({
    required this.rowNumber,
    this.serialNumber,
    required this.name,
    required this.username,
    required this.password,
    this.errors = const [],
  });

  final int rowNumber;
  final int? serialNumber;
  final String name;
  final String username;
  final String password;
  final List<String> errors;

  UserImportRow withError(String thongDiep) => UserImportRow(
    rowNumber: rowNumber,
    serialNumber: serialNumber,
    name: name,
    username: username,
    password: password,
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
    final firstExisting = rows.indexWhere(
      (dong) => existing.contains(dong.username.toLowerCase()),
    );
    if (firstExisting < 0) return UserImportPreview(errors: errors, rows: rows);
    return UserImportPreview(
      errors: errors,
      rows: [
        ...rows.take(firstExisting),
        rows[firstExisting].withError('Tên đăng nhập đã tồn tại.'),
      ],
    );
  }

  UserImportPreview stopAtSerial(int serialNumber, String message) {
    final failedRow = rows.indexWhere(
      (dong) => dong.serialNumber == serialNumber,
    );
    if (failedRow < 0) return UserImportPreview(errors: [message], rows: rows);
    return UserImportPreview(
      errors: errors,
      rows: [
        ...rows.take(failedRow),
        rows[failedRow].withError(message),
      ],
    );
  }
}
