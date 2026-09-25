// DỮ LIỆU: Thông tin học viên truyền giữa các màn hình.
// Giữ tên trường Firebase khi đổi cách hiển thị để đọc được dữ liệu đã lưu.

class UserArguments {
  final String userId;
  final String userName;
  final String email;

  const UserArguments({
    required this.userId,
    required this.userName,
    this.email = '',
  });
}
