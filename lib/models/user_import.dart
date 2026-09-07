class UserImportRow {
  const UserImportRow({
    required this.rowNumber,
    required this.name,
    required this.username,
    required this.password,
    this.errors = const [],
  });

  final int rowNumber;
  final String name;
  final String username;
  final String password;
  final List<String> errors;

  UserImportRow withError(String message) => UserImportRow(
    rowNumber: rowNumber,
    name: name,
    username: username,
    password: password,
    errors: [...errors, message],
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
      rows.every((row) => row.errors.isEmpty);

  UserImportPreview checkExisting(Iterable<String> usernames) {
    final existing = usernames.map((name) => name.trim().toLowerCase()).toSet();
    return UserImportPreview(
      errors: errors,
      rows: rows
          .map(
            (row) => existing.contains(row.username.toLowerCase())
                ? row.withError('Tên đăng nhập đã tồn tại.')
                : row,
          )
          .toList(),
    );
  }
}
