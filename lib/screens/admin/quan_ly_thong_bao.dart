// WEB ADMIN: Tạo, lên lịch và gửi thông báo theo phạm vi người nhận.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../models/dinh_danh_tai_khoan.dart';
import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../services/thong_bao_loi_ung_dung.dart';
import '../../widgets/tien_ich_giao_dien_hoc_tap.dart';
import '../../widgets/giao_dien_quan_tri.dart';
import 'khung_giao_dien_quan_tri.dart';

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
  Future<void> edit({
    QueryDocumentSnapshot<Map<String, dynamic>>? notification,
    bool resend = false,
  }) async {
    if (AccountSession.current?.isRoot != true) return;
    final d = notification?.data() ?? {};
    final taoMoi = notification == null || resend;
    final existingAudience = d['audience'] as String? ?? 'all';
    const sendAtField = 'Ngày giờ gửi (YYYY-MM-DD HH:mm)';
    final nextSendAt = LearningPolicy.nextFutureMinute();
    final sendAt = d['sendAt'] is Timestamp
        ? (d['sendAt'] as Timestamp).toDate()
        : nextSendAt;
    final initialSendAt = resend ? nextSendAt : sendAt;
    final audiences = <String, String>{
      'Tất cả': 'all',
      'Quản lý': 'managers',
      if (!['all', 'managers'].contains(existingAudience))
        'Giữ người nhận hiện tại ($existingAudience)': existingAudience,
    };
    await editLearningRecord(
      context,
      title: resend
          ? 'Tạo bản gửi lại'
          : taoMoi
          ? 'Tạo thông báo trong ứng dụng'
          : 'Sửa nội dung thông báo',
      fields: {
        'Tiêu đề': d['title'] ?? '',
        'Nội dung': d['body'] ?? '',
        'Người nhận': audiences.entries
            .firstWhere((capDuLieu) => capDuLieu.value == existingAudience)
            .key,
        if (taoMoi) sendAtField: initialSendAt.toString().substring(0, 16),
      },
      labels: {'Người nhận': 'Đối tượng nhận thông báo'},
      selectFields: {'Người nhận': audiences.keys.toList()},
      dateTimeFields: taoMoi ? {sendAtField} : const {},
      futureDateTimeFields: taoMoi ? {sendAtField} : const {},
      note: taoMoi
          ? 'Chọn thời gian gửi trước khi tạo. Sau khi tạo thông báo, thời gian gửi sẽ được khóa.'
          : 'Thời gian gửi đã khóa sau khi tạo. Muốn gửi lại, hãy tạo bản mới bằng nút Gửi lại.',
      save: (v) async {
        final at = taoMoi
            ? LearningPolicy.requireFutureDateTime(
                v[sendAtField],
                'Ngày giờ gửi',
              )
            : null;
        final audience = audiences[v['Người nhận']]!;
        final reference = taoMoi
            ? service.db.collection('learning_notifications').doc()
            : notification.reference;
        await service.saveContent(AccountSession.current!.id, reference, {
          'title': v['Tiêu đề'],
          'body': v['Nội dung'],
          'audience': audience,
          if (at != null) 'sendAt': Timestamp.fromDate(at),
        });
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
    } catch (loi) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppErrorMessage.from(
                loi,
                feature: 'Xóa thông báo',
                fallbackAction:
                    'Kiểm tra quyền quản trị và kết nối máy chủ rồi thử lại.',
              ),
            ),
          ),
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
        errorTitle: 'Tải danh sách thông báo',
        builder: (cacBanGhi) {
          final sent = cacBanGhi.length;
          final sentCount = cacBanGhi.where((record) {
            final time = record.data()['sendAt'];
            return time is! Timestamp || !time.toDate().isAfter(DateTime.now());
          }).length;
          final scheduledCount = sent - sentCount;
          return Column(
            children: [
              AdminPageHeading(
                title: 'Quản lý thông báo',
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
                        value: '$sentCount',
                        label: 'đã gửi',
                        icon: Icons.send_outlined,
                        color: Colors.green,
                      ),
                      AdminMetricCard(
                        value: '$scheduledCount',
                        label: 'đã lên lịch',
                        icon: Icons.schedule_outlined,
                        color: AppTheme.red,
                      ),
                    ];
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
                child: cacBanGhi.isEmpty
                    ? Center(child: Text('Chưa có thông báo.'))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                        children: [
                          AdminCard(
                            child: Column(
                              children: [
                                for (final banGhi in cacBanGhi)
                                  _DongThongBao(
                                    doc: banGhi,
                                    audienceLabel: audienceLabel,
                                    onEdit: (doc) => edit(notification: doc),
                                    onResend: (doc) =>
                                        edit(notification: doc, resend: true),
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
    required this.onResend,
    required this.onDelete,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String Function(String) audienceLabel;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>>)
  onEdit;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>>)
  onResend;
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
    final daGui = sendAt == null || !sendAt.isAfter(DateTime.now());
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
                    '${audienceLabel(duLieu['audience'] as String? ?? 'all')} • ${daGui ? 'Đã gửi' : 'Đã lên lịch'} • ${duLieu['body'] ?? ''}',
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
              if (daGui)
                IconButton(
                  tooltip: 'Gửi lại bằng một thông báo mới',
                  onPressed: () => onResend(doc),
                  icon: const Icon(Icons.send_outlined),
                ),
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
