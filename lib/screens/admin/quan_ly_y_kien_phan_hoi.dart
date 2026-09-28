// ADMIN TỔNG: Danh sách góp ý học viên; Firestore Rules cũng giới hạn quyền đọc.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../models/dinh_danh_tai_khoan.dart';
import 'khung_giao_dien_quan_tri.dart';

class AdminFeedbackScreen extends StatelessWidget {
  const AdminFeedbackScreen({super.key});

  static const _categoryNames = {
    'bug': 'Báo lỗi',
    'idea': 'Ý tưởng',
    'other': 'Khác',
  };

  @override
  Widget build(BuildContext context) {
    final isRoot = AccountSession.current?.isRoot == true;
    if (!isRoot) {
      return const Scaffold(body: Center(child: Text('Không tìm thấy trang.')));
    }

    return AdminResponsiveShell(
      selectedIndex: 3,
      activeExtra: 'Góp ý học viên',
      onSelected: (index) => pushAdminPrimary(context, index),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: 'Quay lại Cài đặt',
            onPressed: () => pushAdminPrimary(context, 3),
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Góp ý học viên'),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('feedback')
              .orderBy('createdAt', descending: true)
              .limit(100)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('Không tải được góp ý. Kiểm tra quyền truy cập.'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text('Chưa có góp ý nào.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: docs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final username = data['username'] as String? ?? '';
                final name = data['name'] as String? ?? 'Học viên';
                final message = data['message'] as String? ?? '';
                final category = _categoryNames[data['category']] ?? 'Khác';
                final timestamp = data['createdAt'];
                final date = timestamp is Timestamp
                    ? timestamp.toDate().toLocal().toString().substring(0, 16)
                    : 'Đang cập nhật thời gian';
                return Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: AppTheme.navy,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Chip(label: Text(category)),
                          ],
                        ),
                        if (username.isNotEmpty) Text('Tài khoản: $username'),
                        const SizedBox(height: 4),
                        Text(date, style: const TextStyle(color: Colors.grey)),
                        const Divider(height: 20),
                        SelectableText(message),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
