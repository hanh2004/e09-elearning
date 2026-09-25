// KHỞI TẠO / GIAO DIỆN: Phân biệt cổng Admin/Học viên và truyền cách mở trang chủ sau đăng nhập.
// Các màn hình import tệp này sẽ dùng chung thay đổi.

import 'package:flutter/widgets.dart';

enum AppPortal {
  user,
  admin;

  String get title => this == user ? 'Học tập số E09' : 'Quản trị E09';
  // Cổng học viên đã có tiêu đề thương hiệu phía trên; không lặp lại dòng
  // mô tả cổng bên dưới biểu trưng.
  // Dùng một khoảng trắng vô hình làm giá trị tương thích cho các tích hợp
  // cũ; giao diện không còn hiển thị dòng mô tả cổng học viên.
  String get loginLabel => this == user ? ' ' : 'Cổng dành cho quản lý';

  bool acceptsRole(Object? vaiTro) {
    final giaTri = vaiTro?.toString().trim().toLowerCase();
    return this == admin
        ? giaTri == 'admin' || giaTri == 'super_admin'
        : giaTri == 'user' || giaTri == 'học viên';
  }
}

/// Mỗi cổng chỉ cung cấp bộ dựng màn hình của mình. Giao diện dùng chung không
/// import màn hình của cổng còn lại, kể cả sau khi đăng xuất.
class PortalScope extends InheritedWidget {
  const PortalScope({
    super.key,
    required this.portal,
    required this.homeBuilder,
    required super.child,
  });

  final AppPortal portal;
  final Widget Function(Map<String, dynamic>) homeBuilder;

  static PortalScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PortalScope>();
    assert(scope != null, 'LoginScreen must run inside an application portal.');
    return scope!;
  }

  @override
  bool updateShouldNotify(PortalScope oldWidget) =>
      portal != oldWidget.portal || homeBuilder != oldWidget.homeBuilder;
}
