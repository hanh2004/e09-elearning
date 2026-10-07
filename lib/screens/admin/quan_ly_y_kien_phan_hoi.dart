// ADMIN TỔNG: Danh sách góp ý học viên; Firestore Rules cũng giới hạn quyền đọc.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../app/cau_hinh_ung_dung.dart';
import '../../app/chu_de_ung_dung.dart';
import '../../models/dinh_danh_tai_khoan.dart';
import '../../services/tai_khoan/phien_dang_nhap_quan_tri_web.dart';
import '../../widgets/thong_bao_loi.dart';
import 'khung_giao_dien_quan_tri.dart';

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  final Set<String> _deletingFeedback = {};

  static const _categoryNames = {
    'bug': 'Báo lỗi',
    'idea': 'Ý tưởng',
    'other': 'Khác',
  };

  Future<void> _confirmAndDelete(String feedbackId, String studentName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa góp ý'),
        content: Text(
          'Xóa vĩnh viễn góp ý của $studentName? Không thể khôi phục.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_deletingFeedback.add(feedbackId)) {
      return;
    }
    setState(() {});
    try {
      await FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion)
          .httpsCallable('feedbackDelete')
          .call(AdminWebSession.addToken({'feedbackId': feedbackId}));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã xóa góp ý.')));
      }
    } on FirebaseFunctionsException catch (error) {
      debugPrint('Xóa góp ý thất bại: ${error.code}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Không thể xóa góp ý. Hãy thử lại.'),
          ),
        );
      }
    } catch (error) {
      debugPrint('Xóa góp ý thất bại: ${error.runtimeType}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể xóa góp ý. Hãy thử lại.')),
        );
      }
    } finally {
      _deletingFeedback.remove(feedbackId);
      if (mounted) setState(() {});
    }
  }

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
              return AppErrorNotice(
                error: snapshot.error!,
                feature: 'Tải góp ý của học viên',
                fallbackAction:
                    'Kiểm tra quyền Admin tổng và kết nối máy chủ rồi tải lại.',
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
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Xóa góp ý',
                              onPressed:
                                  _deletingFeedback.contains(docs[index].id)
                                  ? null
                                  : () =>
                                        _confirmAndDelete(docs[index].id, name),
                              icon: _deletingFeedback.contains(docs[index].id)
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.delete_outline),
                            ),
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
