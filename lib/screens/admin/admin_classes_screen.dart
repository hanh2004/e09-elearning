// WEB ADMIN: Màn hình tra cứu cũ học viên theo đơn vị; không còn nằm trong menu chính.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import '../../models/unit_label.dart';

import 'package:flutter/material.dart';

import '../../services/nghiep_vu/learning_service.dart';
import '../../widgets/learning_widgets.dart';
import '../../widgets/admin_ui.dart';
import 'admin_responsive_shell.dart';

// Màn hình cũ được giữ lại cho test và liên kết đã lưu.
// Màn hình này không còn trong menu quản trị; đơn vị được quản lý ở trang tài khoản.

/// Màn hình tra cứu cũ học viên theo đơn vị; không còn nằm trong menu chính.
class AdminClassesScreen extends StatefulWidget {
  const AdminClassesScreen({super.key, this.service});
  final LearningService? service;
  @override
  State<AdminClassesScreen> createState() => _TrangThaiLopHocQuanTri();
}

class _TrangThaiLopHocQuanTri extends State<AdminClassesScreen> {
  late final service = widget.service ?? LearningService();
  late final stream = service.db
      .collection('users')
      .where('role', isEqualTo: 'user')
      .snapshots();
  String search = '';
  @override
  Widget build(BuildContext context) => AdminResponsiveShell(
    selectedIndex: 0,
    activeExtra: 'Đơn vị học viên',
    onSelected: (viTri) => pushAdminPrimary(context, viTri),
    child: Scaffold(
      appBar: AdminUi.appBar('Đơn vị học viên'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Tìm học viên hoặc đơn vị',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => search = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: LearningList(
              stream: stream,
              builder: (cacBanGhi) => ListView(
                children: [
                  for (final banGhi in cacBanGhi.where(
                    (d) =>
                        '${d.data()['name']} ${d.data()['classId']} ${d.data()['unit']} ${d.data()['subUnit'] ?? ''}'
                            .toLowerCase()
                            .contains(search),
                  ))
                    ListTile(
                      title: Text(banGhi.data()['name'] ?? ''),
                      subtitle: Text('Đơn vị: ${unitLabel(banGhi.data())}'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
