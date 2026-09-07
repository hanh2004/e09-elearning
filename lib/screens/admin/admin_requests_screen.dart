import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../models/account_identity.dart';
import '../../services/firestore_service.dart';

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key, required this.service});
  final FirestoreService service;
  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  bool _busy = false;
  Future<void> _decide(String id, bool approve) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Đồng ý tạo Admin phụ?' : 'Từ chối yêu cầu?'),
        content: const Text(
          'Admin phụ có các chức năng quản trị và quản lý User, nhưng chỉ xóa được User do mình tạo; không được tạo bài thi/câu hỏi hoặc quản lý Admin.',
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
    setState(() => _busy = true);
    try {
      await widget.service.decideAdmin(id, approve);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FirebaseFunctionsException
                  ? error.message ?? 'Chưa hoàn tất.'
                  : 'Chưa hoàn tất. Thử lại hoặc bấm đồng bộ lại.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = AccountSession.current;
    if (identity?.isRoot != true) {
      return const Scaffold(
        body: Center(child: Text('Chỉ dành cho admin tổng.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Duyệt Admin phụ')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.service.getAdminRequestsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Không tải được yêu cầu.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs.toList()
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
          if (docs.isEmpty) {
            return const Center(child: Text('Chưa có yêu cầu tạo Admin phụ.'));
          }
          return ListView(
            children: docs.map((doc) {
              final data = doc.data();
              final own = data['createdBy'] == identity!.id;
              final state = data['status'];
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
                        '${data['name']} (${data['username']})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$status • ${own ? 'Bạn đề xuất' : 'Admin tổng còn lại đề xuất'}',
                      ),
                      if (own && state == 'pending')
                        const Text(
                          'Bạn không được tự duyệt. Cần admin tổng còn lại đồng ý.',
                        ),
                      if (!own && state == 'pending')
                        Wrap(
                          spacing: 12,
                          children: [
                            FilledButton(
                              onPressed: _busy
                                  ? null
                                  : () => _decide(doc.id, true),
                              child: const Text('Đồng ý'),
                            ),
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _decide(doc.id, false),
                              child: const Text('Từ chối'),
                            ),
                          ],
                        ),
                      if (!own && ['approved', 'rejected'].contains(state))
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _decide(doc.id, state == 'approved'),
                          child: const Text('Đồng bộ lại trạng thái đăng nhập'),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
