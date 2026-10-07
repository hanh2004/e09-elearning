// APP HỌC VIÊN: Danh sách thông báo và trạng thái đã đọc của học viên.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import '../../widgets/dau_trang_hoc_vien.dart';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../services/thong_bao_loi_ung_dung.dart';
import '../../widgets/thong_bao_loi.dart';
import '../../widgets/tien_ich_giao_dien_hoc_tap.dart';

/// Danh sách thông báo và trạng thái đã đọc của học viên.
class UserNotificationsScreen extends StatefulWidget {
  const UserNotificationsScreen({super.key, required this.uid, this.service});
  final String uid;
  final LearningService? service;
  @override
  State<UserNotificationsScreen> createState() => _TrangThaiThongBaoHocVien();
}

class _TrangThaiThongBaoHocVien extends State<UserNotificationsScreen> {
  late final service = widget.service ?? LearningService();
  late final reads = service.notificationReads(widget.uid);
  bool unreadOnly = false;
  final pending = <String>{};
  Future<void> markRead(String ma) async {
    if (!pending.add(ma)) return;
    try {
      await service.markNotificationRead(widget.uid, ma);
    } catch (loi) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppErrorMessage.from(
                loi,
                feature: 'Đánh dấu thông báo đã đọc',
                fallbackAction:
                    'Kiểm tra kết nối và cấu hình máy chủ rồi thử lại.',
              ),
            ),
          ),
        );
      }
    } finally {
      pending.remove(ma);
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
    appBar: LearnerHeader(title: const Text('Thông báo hệ thống')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: profile,
      builder: (context, duLieuNhan) {
        if (duLieuNhan.hasError) {
          return AppErrorNotice(
            error: duLieuNhan.error!,
            feature: 'Tải hồ sơ để nhận thông báo',
            fallbackAction: 'Kiểm tra phiên đăng nhập, quyền tài khoản và máy chủ rồi thử lại.',
          );
        }
        if (!duLieuNhan.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return LearningList(
          stream: service.notifications(
            widget.uid,
            duLieuNhan.data!.data()?['classId'] ?? '',
          ),
          errorTitle: 'Tải thông báo học viên',
          builder: (cacBanGhi) {
            final daSapXep = cacBanGhi.toList()
              ..sort(
                (a, b) => (b.data()['sendAt'] as Timestamp).compareTo(
                  a.data()['sendAt'] as Timestamp,
                ),
              );
            if (daSapXep.isEmpty) {
              return const Center(child: Text('Bạn chưa có thông báo mới.'));
            }
            return LearningList(
              stream: reads,
              errorTitle: 'Tải trạng thái đã đọc',
              builder: (receipts) {
                final readIds = receipts.map((r) => r.id).toSet();
                final unread = daSapXep
                    .where((d) => !readIds.contains(d.id))
                    .toList();
                final visible = unreadOnly ? unread : daSapXep;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text('Tất cả (${daSapXep.length})'),
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
                    for (final banGhi in visible)
                      Card(
                        color: readIds.contains(banGhi.id)
                            ? Colors.white
                            : const Color(0xFFF0F4FC),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                banGhi.data()['title'] ?? '',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${(banGhi.data()['sendAt'] as Timestamp).toDate()}',
                              ),
                              const SizedBox(height: 12),
                              SelectableText(banGhi.data()['body'] ?? ''),
                              if (!readIds.contains(banGhi.id))
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => markRead(banGhi.id),
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
