// WEB ADMIN: Quản lý tổng duyệt hoặc từ chối yêu cầu tạo quản lý.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../models/account_identity.dart';
import '../../services/du_lieu/firestore_service.dart';
import '../../widgets/admin_ui.dart';
import 'admin_responsive_shell.dart';

/// Quản lý tổng duyệt hoặc từ chối yêu cầu tạo quản lý.
class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key, required this.service});
  final FirestoreService service;
  @override
  State<AdminRequestsScreen> createState() => _TrangThaiYeuCauQuanTri();
}

class _TrangThaiYeuCauQuanTri extends State<AdminRequestsScreen> {
  bool _dangXuLy = false;
  Future<void> _xuLyQuyetDinh(String ma, bool approve) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Đồng ý tạo Quản lý?' : 'Từ chối yêu cầu?'),
        content: const Text(
          'Quản lý được thêm, sửa, xóa học viên do mình tạo và xem báo cáo. Nội dung học tập, đề thi và phân quyền do quản lý tổng quản lý.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _dangXuLy = true);
    try {
      await widget.service.decideAdmin(ma, approve);
    } catch (loi) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loi is FirebaseFunctionsException
                  ? loi.message ?? 'Chưa hoàn tất.'
                  : 'Chưa hoàn tất. Thử lại hoặc bấm đồng bộ lại.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final danhTinh = AccountSession.current;
    if (danhTinh?.isRoot != true) {
      return const Scaffold(
        body: Center(child: Text('Chỉ dành cho quản lý tổng.')),
      );
    }
    return AdminResponsiveShell(
      selectedIndex: 0,
      activeExtra: 'Tài khoản',
      onSelected: (viTri) => pushAdminPrimary(context, viTri),
      child: Scaffold(
        appBar: AdminUi.appBar('Duyệt Quản lý'),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: widget.service.getAdminRequestsStream(),
          builder: (context, duLieuNhan) {
            if (duLieuNhan.hasError) {
              return const Center(child: Text('Không tải được yêu cầu.'));
            }
            if (!duLieuNhan.hasData) {
              return const AdminLoading();
            }
            final cacBanGhi = duLieuNhan.data!.docs.toList()
              ..sort(
                (a, b) =>
                    ((b.data()['createdAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0)
                        .compareTo(
                          (a.data()['createdAt'] as Timestamp?)
                                  ?.millisecondsSinceEpoch ??
                              0,
                        ),
              );
            if (cacBanGhi.isEmpty) {
              return const Center(child: Text('Chưa có yêu cầu tạo quản lý.'));
            }
            return ListView(
              children: cacBanGhi.map((banGhi) {
                final duLieu = banGhi.data();
                final own = duLieu['createdBy'] == danhTinh!.id;
                final state = duLieu['status'];
                final status = switch (state) {
                  'pending' => 'Chờ duyệt',
                  'approved' => 'Đã đồng ý',
                  'rejected' => 'Đã từ chối',
                  _ => 'Đang khởi tạo',
                };
                return Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${duLieu['name']} (${duLieu['username']})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$status • ${own ? 'Bạn đề xuất' : 'Quản lý tổng còn lại đề xuất'}',
                        ),
                        if (own && state == 'pending')
                          const Text(
                            'Bạn không được tự duyệt. Cần quản lý tổng còn lại đồng ý.',
                          ),
                        if (!own && state == 'pending')
                          Wrap(
                            spacing: 12,
                            children: [
                              FilledButton(
                                onPressed: _dangXuLy
                                    ? null
                                    : () => _xuLyQuyetDinh(banGhi.id, true),
                                child: const Text('Đồng ý'),
                              ),
                              OutlinedButton(
                                onPressed: _dangXuLy
                                    ? null
                                    : () => _xuLyQuyetDinh(banGhi.id, false),
                                child: const Text('Từ chối'),
                              ),
                            ],
                          ),
                        if (!own && ['approved', 'rejected'].contains(state))
                          TextButton(
                            onPressed: _dangXuLy
                                ? null
                                : () => _xuLyQuyetDinh(
                                    banGhi.id,
                                    state == 'approved',
                                  ),
                            child: const Text(
                              'Đồng bộ lại trạng thái đăng nhập',
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}
