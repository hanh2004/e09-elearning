// WEB ADMIN: Báo cáo tổng hợp điểm và kết quả theo đề thi, học viên và đơn vị.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/bao_cao_quan_tri.dart';
import '../../models/bao_cao_hoan_thanh_khoa_hoc.dart';
import '../../models/quy_tac_hoc_tap.dart';
import '../../app/chu_de_ung_dung.dart';
import '../../widgets/giao_dien_quan_tri.dart';
import '../../widgets/bo_loc_bao_cao_quan_tri.dart';

import '../../services/du_lieu/dich_vu_firestore.dart';
import '../../services/xuat_excel_bao_cao_quan_tri.dart';
import '../../services/lay_du_lieu_bao_cao_quan_tri.dart';
import '../../services/nguon_du_lieu_bao_cao_quan_tri.dart';
import '../../widgets/thong_bao_loi.dart';
import 'khung_giao_dien_quan_tri.dart';

part "bang_du_lieu_bao_cao.dart";
part "xuat_bao_cao.dart";

/// Báo cáo tổng hợp điểm và kết quả theo đề thi, học viên và đơn vị.
class AdminReportScreen extends StatefulWidget {
  const AdminReportScreen({
    super.key,
    this.service,
    this.embedded = false,
    this.reportData,
  });
  final FirestoreService? service;
  final bool embedded;
  final AdminReportData? reportData;

  @override
  State<AdminReportScreen> createState() => _TrangThaiBaoCaoQuanTri();
}

class _TrangThaiBaoCaoQuanTri extends State<AdminReportScreen> {
  static const _mauChuDao = Color(0xFFB51F24);
  late final FirestoreService _dichVuFirestore =
      widget.service ?? FirestoreService();
  late final _dataSource = AdminReportDataSource(service: _dichVuFirestore);
  late final _reportStream = _dataSource.watch();
  final searchController = TextEditingController();
  String? examFilter;
  String? unitFilter;
  String? subUnitFilter;
  int visibleRows = 50;
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  final int _viTriDaChon = 2;

  void _chonMuc(int viTri) => pushAdminPrimary(context, viTri);

  void _setReportState(VoidCallback update) => setState(update);

  List<Map<String, dynamic>> _luotThiBaoCao(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cacLuotThi,
  ) {
    DateTime? date(Object? giaTri) => giaTri is Timestamp
        ? giaTri.toDate()
        : giaTri is DateTime
        ? giaTri
        : null;
    return cacLuotThi
        .map(
          (banGhi) => {
            ...banGhi.data(),
            'reportLastAt': date(
              banGhi.data()['lastAttemptAt'] ?? banGhi.data()['completedAt'],
            ),
            'reportBestAt': date(
              banGhi.data()['bestCompletedAt'] ?? banGhi.data()['completedAt'],
            ),
          },
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final content = Scaffold(
      backgroundColor: AdminUi.page,
      appBar: widget.embedded ? null : AdminUi.appBar('Báo cáo tổng hợp'),
      body: widget.reportData == null
          ? StreamBuilder<AdminReportData>(
              stream: _reportStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return AppErrorNotice(
                    error: snapshot.error!,
                    feature: 'Tải báo cáo tổng hợp',
                    padding: const EdgeInsets.all(24),
                    fallbackAction: 'Kiểm tra quyền quản trị, kết nối và cấu hình máy chủ rồi tải lại.',
                  );
                }
                if (!snapshot.hasData) return const AdminLoading();
                return _dungDuLieu(snapshot.data!);
              },
            )
          : _dungDuLieu(widget.reportData!),
      bottomNavigationBar: widget.embedded
          ? null
          : adminMobileNavigationBar(
              context,
              selectedIndex: _viTriDaChon,
              onSelected: _chonMuc,
            ),
    );
    if (widget.embedded) return content;
    return AdminResponsiveShell(
      selectedIndex: _viTriDaChon,
      onSelected: _chonMuc,
      activeExtra: 'Báo cáo tổng hợp',
      child: content,
    );
  }

  Widget _dungDuLieu(AdminReportData data) =>
      _dungBaoCao(data.visibleExams, data.visibleAttempts, data.users);
}
