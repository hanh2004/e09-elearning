import 'package:flutter/widgets.dart';

enum AppPortal {
  user,
  admin;

  String get title => this == user ? 'Học tập số E09' : 'Quản trị E09';
  String get loginLabel => this == user
      ? 'Ứng dụng dành cho học viên'
      : 'Cổng quản trị dành cho Admin';

  bool acceptsRole(Object? role) {
    final value = role?.toString().trim().toLowerCase();
    return this == admin
        ? value == 'admin' || value == 'super_admin'
        : value == 'user' || value == 'học viên';
  }
}

/// Each entry point supplies only its own screen builder. Shared UI never
/// imports either portal's screens, including after logout.
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
