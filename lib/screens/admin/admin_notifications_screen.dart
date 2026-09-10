import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/account_identity.dart';
import '../../services/learning_service.dart';
import '../../widgets/learning_widgets.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});
  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final service = LearningService();
  late final stream = service.db
      .collection('learning_notifications')
      .orderBy('sendAt', descending: true)
      .snapshots();
  Future<void> edit([QueryDocumentSnapshot<Map<String, dynamic>>? doc]) async {
    if (AccountSession.current?.isRoot != true) return;
    final d = doc?.data() ?? {};
    await editLearningRecord(
      context,
      title: 'Thông báo trong ứng dụng',
      fields: {
        'Tiêu đề': d['title'] ?? '',
        'Nội dung': d['body'] ?? '',
        'Người nhận (all / user:UID)':
            (d['audience'] as String? ?? '').startsWith('user:')
            ? d['audience']
            : 'all',
        'Ngày giờ gửi (YYYY-MM-DD HH:mm)':
            (d['sendAt'] as Timestamp?)?.toDate().toString().substring(0, 16) ??
            DateTime.now().toString().substring(0, 16),
      },
      save: (v) async {
        final at = DateTime.tryParse(v['Ngày giờ gửi (YYYY-MM-DD HH:mm)']!);
        final audience = v['Người nhận (all / user:UID)']!;
        if (at == null || !RegExp(r'^(all|user:.+)$').hasMatch(audience)) {
          throw ArgumentError('Không hợp lệ');
        }
        await service.saveContent(
          AccountSession.current!.id,
          doc?.reference ??
              service.db.collection('learning_notifications').doc(),
          {
            'title': v['Tiêu đề'],
            'body': v['Nội dung'],
            'audience': audience,
            'sendAt': Timestamp.fromDate(at),
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản lý thông báo')),
    floatingActionButton: AccountSession.current?.isRoot != true
        ? null
        : FloatingActionButton.extended(
            onPressed: edit,
            icon: const Icon(Icons.add_alert),
            label: const Text('Tạo thông báo'),
          ),
    body: LearningList(
      stream: stream,
      builder: (docs) => docs.isEmpty
          ? const Center(child: Text('Chưa có thông báo.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                for (final doc in docs)
                  Card(
                    child: ListTile(
                      title: Text(doc.data()['title'] ?? ''),
                      subtitle: Text(
                        '${doc.data()['audience']} • ${(doc.data()['sendAt'] as Timestamp).toDate()}\n${doc.data()['body']}',
                      ),
                      isThreeLine: true,
                      trailing: AccountSession.current?.isRoot == true
                          ? const Icon(Icons.edit)
                          : null,
                      onTap: AccountSession.current?.isRoot == true
                          ? () => edit(doc)
                          : null,
                    ),
                  ),
              ],
            ),
    ),
  );
}
