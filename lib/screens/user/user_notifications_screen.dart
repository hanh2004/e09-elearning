import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/learning_service.dart';
import '../../widgets/learning_widgets.dart';

class UserNotificationsScreen extends StatefulWidget {
  const UserNotificationsScreen({super.key, required this.uid, this.service});
  final String uid;
  final LearningService? service;
  @override
  State<UserNotificationsScreen> createState() =>
      _UserNotificationsScreenState();
}

class _UserNotificationsScreenState extends State<UserNotificationsScreen> {
  late final service = widget.service ?? LearningService();
  late final reads = service.notificationReads(widget.uid);
  bool unreadOnly = false;
  final pending = <String>{};
  Future<void> markRead(String id) async {
    if (!pending.add(id)) return;
    try {
      await service.markNotificationRead(widget.uid, id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa lưu được trạng thái đã đọc. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      pending.remove(id);
    }
  }

  late final profile = service.db
      .collection('users')
      .doc(widget.uid)
      .snapshots();
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thông báo hệ thống')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: profile,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Không tải được hồ sơ.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return LearningList(
          stream: service.notifications(
            widget.uid,
            snapshot.data!.data()?['classId'] ?? '',
          ),
          builder: (docs) {
            final sorted = docs.toList()
              ..sort(
                (a, b) => (b.data()['sendAt'] as Timestamp).compareTo(
                  a.data()['sendAt'] as Timestamp,
                ),
              );
            if (sorted.isEmpty) {
              return const Center(child: Text('Bạn chưa có thông báo mới.'));
            }
            return LearningList(
              stream: reads,
              builder: (receipts) {
                final readIds = receipts.map((r) => r.id).toSet();
                final unread = sorted
                    .where((d) => !readIds.contains(d.id))
                    .toList();
                final visible = unreadOnly ? unread : sorted;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text('Tất cả (${sorted.length})'),
                          selected: !unreadOnly,
                          onSelected: (_) => setState(() => unreadOnly = false),
                        ),
                        ChoiceChip(
                          label: Text('Chưa đọc (${unread.length})'),
                          selected: unreadOnly,
                          onSelected: (_) => setState(() => unreadOnly = true),
                        ),
                      ],
                    ),
                    if (visible.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Bạn đã đọc tất cả thông báo.'),
                      ),
                    for (final doc in visible)
                      Card(
                        color: readIds.contains(doc.id)
                            ? Colors.white
                            : const Color(0xFFF0F4FC),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doc.data()['title'] ?? '',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${(doc.data()['sendAt'] as Timestamp).toDate()}',
                              ),
                              const SizedBox(height: 12),
                              SelectableText(doc.data()['body'] ?? ''),
                              if (!readIds.contains(doc.id))
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => markRead(doc.id),
                                    icon: const Icon(Icons.done, size: 18),
                                    label: const Text('Đánh dấu đã đọc'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    ),
  );
}
