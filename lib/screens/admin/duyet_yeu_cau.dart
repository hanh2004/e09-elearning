// WEB ADMIN: Admin tổng duyệt tạo quản lý, xử lý xóa quản lý hai bước và xem học viên liên quan.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../models/dinh_danh_tai_khoan.dart';
import '../../services/du_lieu/dich_vu_firestore.dart';
import '../../widgets/giao_dien_quan_tri.dart';
import '../../widgets/thong_bao_loi.dart';
import 'khung_giao_dien_quan_tri.dart';

/// Quản lý tổng duyệt tạo, xóa Quản lý và xem trước học viên liên quan.
class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({
    super.key,
    required this.service,
    this.embedded = false,
  });

  final FirestoreService service;
  final bool embedded;

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
        content: Text(
          approve
              ? 'Quản lý được thêm, sửa, xóa học viên do mình quản lý và xem báo cáo. Nội dung học tập, đề thi và phân quyền do quản lý tổng quản lý.'
              : 'Yêu cầu tạo tài khoản quản lý sẽ bị từ chối và tài khoản đó không được kích hoạt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(approve ? 'Đồng ý' : 'Từ chối'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _dangXuLy = true);
    try {
      await widget.service.decideAdmin(ma, approve);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve ? 'Đã duyệt yêu cầu.' : 'Đã từ chối yêu cầu.',
            ),
          ),
        );
      }
    } catch (loi) {
      if (mounted) {
        final thongDiep = loi is FirebaseFunctionsException
            ? loi.message ?? 'Chưa hoàn tất.'
            : loi.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(thongDiep)));
      }
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  Future<void> _xuLyDuyetXoaQuanLy(
    String requestId,
    bool approve, {
    required bool resume,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          approve
              ? resume
                    ? 'Tiếp tục xóa tài khoản?'
                    : 'Duyệt xóa Quản lý?'
              : 'Từ chối yêu cầu xóa?',
        ),
        content: SizedBox(
          width: 460,
          child: Text(
            approve
                ? 'Nếu duyệt, tài khoản Quản lý và tất cả học viên còn đang do họ quản lý, kể cả học viên được chuyển qua, sẽ bị xóa. Trong lúc chờ duyệt, các tài khoản vẫn hoạt động và có thể chuyển học viên đi.'
                : 'Từ chối đề xuất xóa tài khoản Quản lý.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              approve
                  ? resume
                        ? 'Tiếp tục xóa'
                        : 'Duyệt và xóa'
                  : 'Từ chối',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _dangXuLy = true);
    try {
      await widget.service.decideAdminDeletion(requestId, approve);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve
                  ? 'Đã xóa Quản lý và hoàn tất yêu cầu.'
                  : 'Đã từ chối yêu cầu xóa.',
            ),
          ),
        );
      }
    } catch (loi) {
      if (mounted) {
        final thongDiep = loi is FirebaseFunctionsException
            ? loi.message ?? 'Chưa hoàn tất.'
            : loi.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(thongDiep)));
      }
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  Future<void> _tiepTucChuanBiYeuCauXoa(String userId) async {
    setState(() => _dangXuLy = true);
    try {
      await widget.service.requestAdminDeletion(userId: userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yêu cầu đang chờ quản lý tổng còn lại duyệt.'),
          ),
        );
      }
    } catch (loi) {
      if (mounted) {
        final thongDiep = loi is FirebaseFunctionsException
            ? loi.message ?? 'Chưa hoàn tất.'
            : loi.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(thongDiep)));
      }
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  Widget _theYeuCau(
    QueryDocumentSnapshot<Map<String, dynamic>> banGhi,
    AccountIdentity danhTinh,
  ) {
    final duLieu = banGhi.data();
    final own = duLieu['createdBy'] == danhTinh.id;
    final state = duLieu['status']?.toString();
    final canDecide = !own && state == 'pending';
    final canSync =
        !own &&
        ['approved', 'rejected'].contains(state) &&
        duLieu['decidedBy'] == danhTinh.id;
    final (trangThai, mau, icon) = switch (state) {
      'pending' => (
        'Chờ quản lý tổng duyệt',
        const Color(0xFFF57C00),
        Icons.hourglass_empty,
      ),
      'approved' => (
        'Đã đồng ý tạo quản lý',
        const Color(0xFF2E9B43),
        Icons.check_circle_outline,
      ),
      'rejected' => (
        'Đã từ chối',
        const Color(0xFFC62828),
        Icons.cancel_outlined,
      ),
      'provisioning' => (
        'Đang tạo tài khoản…',
        const Color(0xFF60779A),
        Icons.sync,
      ),
      _ => ('Đang khởi tạo', const Color(0xFF60779A), Icons.hourglass_empty),
    };
    final moTa = own && state == 'pending'
        ? 'Bạn đã đề xuất — chờ quản lý tổng còn lại duyệt'
        : !own && state == 'pending'
        ? 'Yêu cầu tạo tài khoản quản lý'
        : own
        ? trangThai
        : '$trangThai${duLieu['decidedBy'] == danhTinh.id ? ' — bạn đã xử lý' : ''}';

    final actions = <Widget>[
      if (canDecide) ...[
        FilledButton.icon(
          onPressed: _dangXuLy ? null : () => _xuLyQuyetDinh(banGhi.id, true),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Duyệt'),
        ),
        OutlinedButton.icon(
          onPressed: _dangXuLy ? null : () => _xuLyQuyetDinh(banGhi.id, false),
          icon: const Icon(Icons.close, size: 18),
          label: const Text('Từ chối'),
        ),
      ] else if (canSync)
        TextButton.icon(
          onPressed: _dangXuLy
              ? null
              : () => _xuLyQuyetDinh(banGhi.id, state == 'approved'),
          icon: const Icon(Icons.sync, size: 18),
          label: const Text('Đồng bộ trạng thái'),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final thongTin = Row(
              children: [
                CircleAvatar(
                  backgroundColor: mau.withValues(alpha: 0.12),
                  foregroundColor: mau,
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${duLieu['name'] ?? 'Quản lý'} (${duLieu['username'] ?? ''})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(moTa, style: TextStyle(color: mau)),
                    ],
                  ),
                ),
              ],
            );

            if (actions.isEmpty || constraints.maxWidth >= 620) {
              return Row(
                children: [
                  Expanded(child: thongTin),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Wrap(spacing: 8, children: actions),
                  ],
                ],
              );
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: thongTin,
                  ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 4,
                    children: actions,
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _theYeuCauXoaQuanLy(
    QueryDocumentSnapshot<Map<String, dynamic>> request,
    AccountIdentity danhTinh,
  ) {
    final duLieu = request.data();
    final state = duLieu['status']?.toString();
    final own = duLieu['createdBy'] == danhTinh.id;
    final canDecide = !own && state == 'pending';
    final canResume = state == 'processing';
    final color = switch (state) {
      'pending' => const Color(0xFFF57C00),
      'processing' || 'provisioning' => const Color(0xFF60779A),
      'approved' => const Color(0xFF2E9B43),
      _ => const Color(0xFFC62828),
    };
    final label = switch (state) {
      'pending' =>
        own
            ? 'Bạn đã đề xuất — chờ quản lý tổng còn lại duyệt'
            : 'Chờ quản lý tổng còn lại duyệt',
      'processing' => 'Đã duyệt — đang xóa, có thể tiếp tục nếu bị gián đoạn',
      'provisioning' => 'Yêu cầu cũ đang chờ cập nhật',
      'approved' => 'Đã hoàn tất yêu cầu xóa Quản lý',
      'rejected' => 'Đã từ chối — không xóa tài khoản',
      _ => 'Trạng thái yêu cầu không xác định',
    };
    final notice = state == 'pending'
        ? 'Trong lúc chờ duyệt, tài khoản vẫn hoạt động và có thể chuyển học viên đi. Nếu duyệt, tất cả học viên còn đang do quản lý này phụ trách, kể cả học viên được chuyển qua, sẽ bị xóa.'
        : state == 'processing'
        ? 'Đang xóa Quản lý và các học viên hiện còn do họ phụ trách.'
        : '';
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              foregroundColor: color,
              child: const Icon(Icons.delete_outline),
            ),
            title: Text(
              '${duLieu['name'] ?? 'Quản lý'} (${duLieu['username'] ?? ''})',
            ),
            subtitle: Text(
              notice.isEmpty ? label : '$label\n$notice',
              style: TextStyle(color: color),
            ),
          ),
          if (canDecide || canResume)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canDecide)
                    OutlinedButton.icon(
                      onPressed: _dangXuLy
                          ? null
                          : () => _xuLyDuyetXoaQuanLy(
                              request.id,
                              false,
                              resume: false,
                            ),
                      icon: const Icon(Icons.close),
                      label: const Text('Từ chối'),
                    ),
                  FilledButton.icon(
                    onPressed: _dangXuLy
                        ? null
                        : () => _xuLyDuyetXoaQuanLy(
                            request.id,
                            true,
                            resume: canResume,
                          ),
                    icon: Icon(canResume ? Icons.refresh : Icons.delete),
                    label: Text(canResume ? 'Tiếp tục xóa' : 'Duyệt và xóa'),
                  ),
                ],
              ),
            ),
          if (own && state == 'provisioning')
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _dangXuLy
                      ? null
                      : () => _tiepTucChuanBiYeuCauXoa(request.id),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Cập nhật yêu cầu cũ'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final danhTinh = AccountSession.current;
    if (danhTinh?.isRoot != true) {
      return const Center(child: Text('Chỉ dành cho quản lý tổng.'));
    }

    final noiDung = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.service.getAdminRequestsStream(),
      builder: (context, adminRequests) {
        if (adminRequests.hasError) {
          return AppErrorNotice(
            error: adminRequests.error!,
            feature: 'Tải yêu cầu duyệt quản lý',
            fallbackAction:
                'Kiểm tra quyền Admin tổng và kết nối máy chủ rồi tải lại.',
          );
        }
        if (!adminRequests.hasData) return const AdminLoading();
        final adminDocs = adminRequests.data!.docs.toList()
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
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: widget.service.getAdminDeletionRequestsStream(),
          builder: (context, deletionRequests) {
            if (deletionRequests.hasError) {
              return AppErrorNotice(
                error: deletionRequests.error!,
                feature: 'Tải yêu cầu xóa quản lý',
                fallbackAction: 'Kiểm tra quyền Admin tổng và cấu hình máy chủ rồi tải lại.',
              );
            }
            if (!deletionRequests.hasData) return const AdminLoading();
            final deletionDocs = deletionRequests.data!.docs.toList()
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
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Yêu cầu tạo Quản lý',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (adminDocs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Chưa có yêu cầu tạo Quản lý.'),
                  ),
                for (final request in adminDocs) _theYeuCau(request, danhTinh!),
                const SizedBox(height: 20),
                Text(
                  'Yêu cầu xóa Quản lý',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (deletionDocs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Chưa có yêu cầu xóa Quản lý.'),
                  ),
                for (final request in deletionDocs)
                  _theYeuCauXoaQuanLy(request, danhTinh!),
              ],
            );
          },
        );
      },
    );

    if (widget.embedded) return noiDung;
    return AdminResponsiveShell(
      selectedIndex: 0,
      activeExtra: 'Tài khoản',
      onSelected: (viTri) => pushAdminPrimary(context, viTri),
      child: Scaffold(
        backgroundColor: AdminUi.page,
        appBar: AdminUi.appBar('Duyệt Quản lý'),
        body: noiDung,
      ),
    );
  }
}
