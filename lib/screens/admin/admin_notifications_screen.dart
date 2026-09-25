// WEB ADMIN: Tạo, lên lịch và gửi thông báo theo phạm vi người nhận.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../models/account_identity.dart';
import '../../services/nghiep_vu/learning_service.dart';
import '../../widgets/learning_widgets.dart';
import '../../widgets/admin_ui.dart';
import 'admin_responsive_shell.dart';

/// Tạo, lên lịch và gửi thông báo theo phạm vi người nhận.
class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key, this.service});
  final LearningService? service;
  @override
  State<AdminNotificationsScreen> createState() => _TrangThaiThongBaoQuanTri();
}

class _TrangThaiThongBaoQuanTri extends State<AdminNotificationsScreen> {
  late final service = widget.service ?? LearningService();
  late final stream = service.db
      .collection('learning_notifications')
      .orderBy('sendAt', descending: true)
      .snapshots();
  Future<void> edit([
    QueryDocumentSnapshot<Map<String, dynamic>>? banGhi,
  ]) async {
    if (AccountSession.current?.isRoot != true) return;
    final d = banGhi?.data() ?? {};
    final existingAudience = d['audience'] as String? ?? 'all';
    final audiences = <String, String>{
      'Tất cả': 'all',
      'Quản lý': 'managers',
      if (!['all', 'managers'].contains(existingAudience))
        'Giữ người nhận hiện tại ($existingAudience)': existingAudience,
    };
    await editLearningRecord(
      context,
      title: 'Thông báo trong ứng dụng',
      fields: {
        'Tiêu đề': d['title'] ?? '',
        'Nội dung': d['body'] ?? '',
        'Người nhận': audiences.entries
            .firstWhere((capDuLieu) => capDuLieu.value == existingAudience)
            .key,
        'Ngày giờ gửi (YYYY-MM-DD HH:mm)':
            (d['sendAt'] as Timestamp?)?.toDate().toString().substring(0, 16) ??
            DateTime.now().toString().substring(0, 16),
      },
      labels: {'Người nhận': 'Đối tượng nhận thông báo'},
      selectFields: {'Người nhận': audiences.keys.toList()},
      dateTimeFields: {'Ngày giờ gửi (YYYY-MM-DD HH:mm)'},
      save: (v) async {
        final at = DateTime.tryParse(v['Ngày giờ gửi (YYYY-MM-DD HH:mm)']!);
        final audience = audiences[v['Người nhận']]!;
        if (at == null) {
          throw ArgumentError('Ngày giờ gửi không hợp lệ.');
        }
        await service.saveContent(
          AccountSession.current!.id,
          banGhi?.reference ??
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

  String audienceLabel(String giaTri) => switch (giaTri) {
    'managers' => 'Quản lý',
    'all' => 'Tất cả',
    _ => giaTri,
  };

  Future<void> deleteNotification(
    QueryDocumentSnapshot<Map<String, dynamic>> banGhi,
  ) async {
    if (AccountSession.current?.isRoot != true) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa thông báo'),
        content: Text('Xóa thông báo "${banGhi.data()['title'] ?? ''}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await banGhi.reference.delete();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không xóa được thông báo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AdminResponsiveShell(
    selectedIndex: 0,
    activeExtra: 'Thông báo',
    onSelected: (viTri) => pushAdminPrimary(context, viTri),
    child: Scaffold(
      appBar: AdminUi.appBar('Quản lý thông báo'),
      body: LearningList(
        stream: stream,
        builder: (cacBanGhi) {
          final daLoc = cacBanGhi;
          final sent = cacBanGhi.length;
          return Column(
            children: [
              AdminPageHeading(
                title: 'Quản lý thông báo',
                subtitle: 'Tạo và quản lý thông báo gửi đến người dùng.',
                action: AccountSession.current?.isRoot == true
                    ? FilledButton.icon(
                        onPressed: edit,
                        icon: const Icon(Icons.add_alert),
                        label: const Text('Tạo thông báo'),
                      )
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 900) {
                      return const SizedBox.shrink();
                    }
                    final cards = [
                      AdminMetricCard(
                        value: '$sent',
                        label: 'tổng thông báo',
                        icon: Icons.notifications_none,
                        color: Colors.blue,
                      ),
                      AdminMetricCard(
                        value: '$sent',
                        label: 'đã gửi',
                        icon: Icons.send_outlined,
                        color: Colors.green,
                      ),
                      AdminMetricCard(
                        value: '0',
                        label: 'bản nháp',
                        icon: Icons.description_outlined,
                        color: AppTheme.red,
                      ),
                    ];
                    if (constraints.maxWidth < 720) {
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final card in cards)
                            SizedBox(width: 220, child: card),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(width: 14),
                          Expanded(child: cards[i]),
                        ],
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: daLoc.isEmpty
                    ? Center(
                        child: Text(
                          cacBanGhi.isEmpty
                              ? 'Chưa có thông báo.'
                              : 'Không tìm thấy thông báo phù hợp.',
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                        children: [
                          AdminCard(
                            child: Column(
                              children: [
                                for (final banGhi in daLoc)
                                  _DongThongBao(
                                    doc: banGhi,
                                    audienceLabel: audienceLabel,
                                    onEdit: edit,
                                    onDelete: deleteNotification,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _DongThongBao extends StatelessWidget {
  const _DongThongBao({
    required this.doc,
    required this.audienceLabel,
    required this.onEdit,
    required this.onDelete,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String Function(String) audienceLabel;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>>)
  onEdit;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>>)
  onDelete;

  @override
  Widget build(BuildContext context) {
    final duLieu = doc.data();
    final laQuanTriTong = AccountSession.current?.isRoot == true;
    final sendAt = duLieu['sendAt'] is Timestamp
        ? (duLieu['sendAt'] as Timestamp).toDate()
        : null;
    final ngay = sendAt == null
        ? ''
        : '${sendAt.day.toString().padLeft(2, '0')}/${sendAt.month.toString().padLeft(2, '0')}/${sendAt.year} ${sendAt.hour.toString().padLeft(2, '0')}:${sendAt.minute.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: laQuanTriTong ? () => onEdit(doc) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.notifications_none, color: Colors.blue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    duLieu['title'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${audienceLabel(duLieu['audience'] as String? ?? 'all')} • ${duLieu['body'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF60779A)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (ngay.isNotEmpty)
              Text(ngay, style: const TextStyle(color: Color(0xFF60779A))),
            if (laQuanTriTong) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Sửa thông báo',
                onPressed: () => onEdit(doc),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Xóa thông báo',
                onPressed: () => onDelete(doc),
                icon: const Icon(Icons.delete_outline, color: AppTheme.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
