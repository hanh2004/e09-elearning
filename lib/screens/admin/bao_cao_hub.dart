// Trang tổng hợp các báo cáo quản trị và điều hướng giữa những tab báo cáo.
// Dữ liệu báo cáo được lấy từ các màn hình con và nguồn dữ liệu quản trị.

// Trang tổng hợp các báo cáo quản trị và điều hướng giữa những tab báo cáo.
// Dữ liệu báo cáo được lấy từ các màn hình con và nguồn dữ liệu quản trị.

import 'package:flutter/material.dart';

import '../../services/du_lieu/dich_vu_firestore.dart';
import '../../widgets/giao_dien_quan_tri.dart';
import '../../services/nguon_du_lieu_bao_cao_quan_tri.dart';
import 'bao_cao_thong_ke.dart';
import 'khung_giao_dien_quan_tri.dart';
import 'theo_doi_tien_do_hoc_tap.dart';
import 'tong_quan_hoc_tap.dart';

/// Không gian báo cáo chung, mỗi tab giữ nguyên bộ lọc và dữ liệu riêng.
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
              Tab(text: 'Tiến độ học'),
              Tab(text: 'Kết quả thi'),
              Tab(text: 'Báo cáo tổng hợp'),
            ],
          ),
        ),
        body: StreamBuilder<AdminReportData>(
          stream: _reportStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Không tải được dữ liệu báo cáo: ${snapshot.error}',
                ),
              );
            }
            if (!snapshot.hasData) return const AdminLoading();
            final data = snapshot.data!;
            return TabBarView(
              children: [
                AdminLearningDashboard(
                  reportData: data,
                ),
                AdminProgressScreen(
                  reportData: data,
                ),
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
