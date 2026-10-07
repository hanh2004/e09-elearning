// Trang tổng hợp các báo cáo quản trị và điều hướng giữa những tab báo cáo.
// Nguồn dữ liệu chung được cấp cho các tab; mỗi tab giữ bộ lọc riêng.
import 'package:flutter/material.dart';

import '../../services/du_lieu/dich_vu_firestore.dart';
import '../../widgets/giao_dien_quan_tri.dart';
import '../../widgets/thong_bao_loi.dart';
import '../../services/nguon_du_lieu_bao_cao_quan_tri.dart';
import 'bao_cao_thong_ke.dart';
import 'khung_giao_dien_quan_tri.dart';
import 'theo_doi_tien_do_hoc_tap.dart';
import 'tong_quan_hoc_tap.dart';

/// Các tab dùng chung nguồn dữ liệu báo cáo nhưng giữ bộ lọc riêng.
class AdminReportsHubScreen extends StatefulWidget {
  const AdminReportsHubScreen({super.key, this.service});

  final FirestoreService? service;

  @override
  State<AdminReportsHubScreen> createState() => _AdminReportsHubScreenState();
}

class _AdminReportsHubScreenState extends State<AdminReportsHubScreen> {
  late final _dataSource = AdminReportDataSource(service: widget.service);
  late final _reportStream = _dataSource.watch();

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: AdminResponsiveShell(
      selectedIndex: 2,
      activeExtra: 'Báo cáo',
      onSelected: (index) => pushAdminPrimary(context, index),
      child: Scaffold(
        backgroundColor: AdminUi.page,
        appBar: AdminUi.appBar(
          'Báo cáo',
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Tổng quan học tập'),
              Tab(text: 'Kết quả thi'),
              Tab(text: 'Báo cáo tổng hợp'),
            ],
          ),
        ),
        body: StreamBuilder<AdminReportData>(
          stream: _reportStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AppErrorNotice(
                error: snapshot.error!,
                feature: 'Tải dữ liệu báo cáo',
                fallbackAction: 'Kiểm tra kết nối, quyền tài khoản và cấu hình máy chủ rồi tải lại.',
              );
            }
            if (!snapshot.hasData) return const AdminLoading();
            final data = snapshot.data!;
            return TabBarView(
              children: [
                AdminLearningDashboard(reportData: data),
                AdminProgressScreen(reportData: data),
                AdminReportScreen(
                  embedded: true,
                  service: _dataSource.service,
                  reportData: data,
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: adminMobileNavigationBar(
          context,
          selectedIndex: 2,
          onSelected: (index) => pushAdminPrimary(context, index),
        ),
      ),
    ),
  );
}
