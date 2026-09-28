// WEB ADMIN: Báo cáo khóa học đã kết thúc, thống kê hoàn thành theo đơn vị và học viên.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/dinh_danh_tai_khoan.dart';
import '../../models/bao_cao_hoan_thanh_khoa_hoc.dart';
import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../widgets/giao_dien_quan_tri.dart';
import 'khung_giao_dien_quan_tri.dart';

/// Báo cáo khóa học đã kết thúc, thống kê hoàn thành theo đơn vị và học viên.
class AdminCourseReportScreen extends StatefulWidget {
  const AdminCourseReportScreen({
    super.key,
    required this.course,
    required this.service,
  });
  final QueryDocumentSnapshot<Map<String, dynamic>> course;
  final LearningService service;
  @override
  State<AdminCourseReportScreen> createState() => _TrangThaiBaoCaoKhoaHoc();
}

class _ThongKeThiCuaKhoa extends StatelessWidget {
  const _ThongKeThiCuaKhoa({
    required this.courseId,
    required this.course,
    required this.service,
  });
  final String courseId;
  final Map<String, dynamic> course;
  final LearningService service;

  @override
  Widget build(BuildContext context) {
    final examId = course['examId']?.toString().trim() ?? '';
    if (examId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.db
          .collection('exam_attempts')
          .where('courseId', isEqualTo: courseId)
          .snapshots(),
      builder: (context, duLieuNhan) {
        if (duLieuNhan.hasError || !duLieuNhan.hasData) {
          return const SizedBox.shrink();
        }
        final cacLuotThi = duLieuNhan.data!.docs
            .where((banGhi) => banGhi.data()['examId'] == examId)
            .toList();
        final daHoanThanh = cacLuotThi
            .where((banGhi) => banGhi.data()['status'] == 'completed')
            .length;
        final scores = cacLuotThi
            .map((banGhi) => (banGhi.data()['diemSo'] as num?)?.toDouble())
            .whereType<double>()
            .toList();
        final average = scores.isEmpty
            ? null
            : scores.reduce((a, b) => a + b) / scores.length;
        return AdminCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thống kê bài kiểm tra của khóa học',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Đã nộp: $daHoanThanh/${cacLuotThi.length}'
                  '${average == null ? '' : ' • Điểm trung bình: ${average.toStringAsFixed(1)}'}',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TrangThaiBaoCaoKhoaHoc extends State<AdminCourseReportScreen> {
  late Future<CourseCompletionReport> report = load();
  String search = '';
  String? unit;
  String status = 'Tất cả';

  Future<CourseCompletionReport> load() async {
    final danhTinh = AccountSession.current;
    if (danhTinh?.isAdmin != true) {
      throw StateError('Không có quyền xem báo cáo.');
    }

    final cacDuLieuNhan = await Future.wait([
      widget.service.db.collection('users').get(),
      widget.course.reference.collection('lessons').get(),
    ]);
    final cacNguoiDung = {
      for (final d in cacDuLieuNhan[0].docs) d.id: d.data(),
    };
    final cacHocVien = cacDuLieuNhan[0].docs
        .where(
          (d) =>
              d.data()['role'] == 'user' &&
              (danhTinh!.isRoot || d.data()['createdBy'] == danhTinh.id),
        )
        .toList();
    final tienDo = <String, List<Map<String, dynamic>>>{};
    // Giới hạn số lần đọc đồng thời khi có nhiều đơn vị; không âm thầm tính lỗi là 0.
    for (var batDau = 0; batDau < cacHocVien.length; batDau += 10) {
      await Future.wait(
        cacHocVien.skip(batDau).take(10).map((hocVien) async {
          final ketQua = await hocVien.reference
              .collection('learning')
              .where('courseId', isEqualTo: widget.course.id)
              .get();
          tienDo[hocVien.id] = ketQua.docs.map((d) => d.data()).toList();
        }),
      );
    }
    return CourseCompletionReport.build(
      users: cacNguoiDung,
      lessonIds: cacDuLieuNhan[1].docs.map((d) => d.id).toSet(),
      progress: tienDo,
      courseId: widget.course.id,
      course: widget.course.data(),
      lessons: {for (final d in cacDuLieuNhan[1].docs) d.id: d.data()},
      endsAt: LearningPolicy.readDateTime(widget.course.data()['endsAt'])!,
      ownerId: danhTinh!.isRoot ? null : danhTinh.id,
    );
  }

  @override
  Widget build(BuildContext context) => AdminResponsiveShell(
    selectedIndex: 0,
    activeExtra: 'Khóa học kết thúc',
    onSelected: (viTri) => pushAdminPrimary(context, viTri),
    child: Scaffold(
      backgroundColor: AdminUi.page,
      appBar: AdminUi.appBar(
        'Kết quả khóa học',
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => report = load()),
          ),
        ],
      ),
      body: FutureBuilder<CourseCompletionReport>(
        future: report,
        builder: (context, duLieuNhan) {
          if (duLieuNhan.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Không tải được báo cáo. Vui lòng thử lại.'),
                  TextButton(
                    onPressed: () => setState(() => report = load()),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }
          if (!duLieuNhan.hasData) {
            return const AdminLoading();
          }
          final duLieu = duLieuNhan.data!;
          final cacDonVi = duLieu.rows.map((r) => r.unit).toSet().toList()
            ..sort();
          final cacDong = duLieu.rows
              .where(
                (r) =>
                    (unit == null || r.unit == unit) &&
                    (status == 'Tất cả' ||
                        (status == 'Đã hoàn thành' ? r.done : !r.done)) &&
                    '${r.name} ${r.unit} ${r.subUnit}'.toLowerCase().contains(
                      search,
                    ),
              )
              .toList();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.course.data()['title'] ?? '',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.lock_outline, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Đã triển khai • Đã kết thúc và khóa nội dung'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final capDuLieu in {
                    'Tổng học viên': duLieu.rows.length,
                    'Đã hoàn thành': duLieu.completed,
                    'Chưa hoàn thành': duLieu.incomplete,
                  }.entries)
                    SizedBox(
                      width: 210,
                      child: AdminCard(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${capDuLieu.value}',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                              Text(capDuLieu.key),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _ThongKeThiCuaKhoa(
                courseId: widget.course.id,
                course: widget.course.data(),
                service: widget.service,
              ),
              const SizedBox(height: 16),
              const Text(
                'Hoàn thành = học đủ tất cả bài trước hạn kết thúc. Chưa hoàn thành gồm chưa học và học chưa xong. Đơn vị theo phân công hiện tại; không tính tài khoản tạo sau hạn kết thúc.',
              ),
              const SizedBox(height: 20),
              Text(
                'Thống kê theo đơn vị',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (cacDonVi.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Chưa có học viên trong phạm vi báo cáo.'),
                ),
              for (final ten in cacDonVi)
                Builder(
                  builder: (context) {
                    final thanhVien = duLieu.rows
                        .where((r) => r.unit == ten)
                        .toList();
                    final daXong = thanhVien.where((r) => r.done).length;
                    return AdminCard(
                      child: ListTile(
                        selected: unit == ten,
                        leading: const Icon(Icons.groups_outlined),
                        title: Text(ten),
                        subtitle: Text(
                          'Tổng ${thanhVien.length} • Đã hoàn thành $daXong • Chưa hoàn thành ${thanhVien.length - daXong}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            setState(() => unit = unit == ten ? null : ten),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 20),
              Text(
                'Danh sách học viên${unit == null ? '' : ' • $unit'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Tìm học viên hoặc đơn vị',
                ),
                onChanged: (giaTri) =>
                    setState(() => search = giaTri.trim().toLowerCase()),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (unit != null)
                    InputChip(
                      label: Text(unit!),
                      onDeleted: () => setState(() => unit = null),
                    ),
                  for (final nhan in [
                    'Tất cả',
                    'Đã hoàn thành',
                    'Chưa hoàn thành',
                  ])
                    ChoiceChip(
                      label: Text(nhan),
                      selected: status == nhan,
                      onSelected: (_) => setState(() => status = nhan),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (cacDong.isEmpty) const Text('Không có học viên phù hợp.'),
              for (final dong in cacDong)
                AdminCard(
                  child: ListTile(
                    leading: Icon(
                      dong.done ? Icons.check_circle : Icons.pending_outlined,
                      color: dong.done
                          ? Colors.green.shade700
                          : Colors.orange.shade800,
                    ),
                    title: Text(dong.name),
                    subtitle: Text(
                      '${dong.subUnit.isEmpty ? '' : '${dong.subUnit}-'}${dong.unit}\n${dong.status} • ${dong.completed}/${dong.total} bài',
                    ),
                    isThreeLine: true,
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
