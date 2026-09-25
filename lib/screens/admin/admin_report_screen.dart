// WEB ADMIN: Báo cáo tổng hợp điểm và kết quả theo đề thi, học viên và đơn vị.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/admin_report.dart';
import '../../models/course_completion_report.dart';
import '../../models/learning_policy.dart';
import '../../app/app_theme.dart';
import '../../widgets/admin_ui.dart';

import '../../services/du_lieu/firestore_service.dart';
import '../../services/admin_report_excel_export.dart';
import '../../services/admin_report_attempts.dart';
import 'admin_responsive_shell.dart';

part "admin_report_table.dart";
part "admin_report_export.dart";

/// Báo cáo tổng hợp điểm và kết quả theo đề thi, học viên và đơn vị.
class AdminReportScreen extends StatefulWidget {
  const AdminReportScreen({super.key, this.service});
  final FirestoreService? service;

  @override
  State<AdminReportScreen> createState() => _TrangThaiBaoCaoQuanTri();
}

class _TrangThaiBaoCaoQuanTri extends State<AdminReportScreen> {
  static const _mauChuDao = Color(0xFFB51F24);
  late final FirestoreService _dichVuFirestore =
      widget.service ?? FirestoreService();
  late final examStream = _dichVuFirestore.getExamsStream();
  late final attemptStream = _dichVuFirestore.getExamAttemptsStream();
  late final userStream = _dichVuFirestore.getUsersStream();
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

  void _chonMuc(int viTri) {
    if (viTri == _viTriDaChon) return;
    pushAdminPrimary(context, viTri);
  }

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
    final laMayTinh = AdminResponsiveShell.isDesktop(context);
    return AdminResponsiveShell(
      selectedIndex: _viTriDaChon,
      onSelected: _chonMuc,
      activeExtra: 'Báo cáo tổng hợp',
      child: Scaffold(
        backgroundColor: AdminUi.page,
        appBar: AdminUi.appBar('Báo cáo tổng hợp'),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: examStream,
          builder: (context, examSnapshot) {
            if (examSnapshot.hasError) {
              return _dungThongBaoLoi('Không tải được danh sách bài thi.');
            }
            if (!examSnapshot.hasData) {
              return const AdminLoading();
            }
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: attemptStream,
              builder: (context, attemptSnapshot) {
                if (attemptSnapshot.hasError) {
                  return _dungThongBaoLoi('Không tải được kết quả làm bài.');
                }
                if (!attemptSnapshot.hasData) {
                  return const AdminLoading();
                }
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: userStream,
                  builder: (context, userSnapshot) {
                    if (userSnapshot.hasError) {
                      return _dungThongBaoLoi(
                        'Không tải được tài khoản người dùng.',
                      );
                    }
                    if (!userSnapshot.hasData) {
                      return const AdminLoading();
                    }
                    return _dungBaoCao(
                      examSnapshot.data!.docs,
                      attemptSnapshot.data!.docs,
                      userSnapshot.data!.docs,
                    );
                  },
                );
              },
            );
          },
        ),
        bottomNavigationBar: laMayTinh
            ? null
            : BottomNavigationBar(
                currentIndex: _viTriDaChon,
                onTap: _chonMuc,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: _mauChuDao,
                unselectedItemColor: Colors.grey,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: 'Trang chủ',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.assignment),
                    label: 'Quản lý khóa học',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.bar_chart),
                    label: 'Báo cáo',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings),
                    label: 'Cài đặt',
                  ),
                ],
              ),
      ),
    );
  }
}
