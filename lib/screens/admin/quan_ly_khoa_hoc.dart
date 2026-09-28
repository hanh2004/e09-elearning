// WEB ADMIN: Danh sách khóa học: tìm kiếm, lọc khóa đã kết thúc và mở form chỉnh sửa.
// Form: forms/bieu_mau_khoa_hoc.dart; dữ liệu nhập: ../../models/bieu_mau_khoa_hoc.dart.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../models/dinh_danh_tai_khoan.dart';
import '../../models/bieu_mau_khoa_hoc.dart';
import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../widgets/giao_dien_quan_tri.dart';
import '../../widgets/anh_bia_khoa_hoc.dart';
import '../../widgets/tien_ich_giao_dien_hoc_tap.dart';
import 'bao_cao_khoa_hoc.dart';
import 'quan_ly_bai_hoc.dart';
import 'khung_giao_dien_quan_tri.dart';
import 'forms/bieu_mau_khoa_hoc.dart';

// Các nơi import màn hình bài học từ tệp cũ vẫn tiếp tục hoạt động.
export 'quan_ly_bai_hoc.dart' show AdminLessonsScreen;

/// Danh sách khóa học: tìm kiếm, lọc khóa đã kết thúc và mở form chỉnh sửa.
class AdminCoursesScreen extends StatefulWidget {
  const AdminCoursesScreen({
    super.key,
    this.service,
    this.ended = false,
    this.initialCourseModeFilter = 'all',
  });
  final LearningService? service;
  final bool ended;
  final String initialCourseModeFilter;
  @override
  State<AdminCoursesScreen> createState() => _TrangThaiKhoaHocQuanTri();
}

class _TrangThaiKhoaHocQuanTri extends State<AdminCoursesScreen> {
  late final service = widget.service ?? LearningService();
  late final stream = service.courses();
  String search = '';
  final _cacKhoaHocDangXoa = <String>{};
  late String courseModeFilter = widget.initialCourseModeFilter;
  String dateFilter = 'all';
  DateTime dateFilterDate = DateTime.now();
  late final Timer refreshTimer;

  String get pageTitle {
    if (widget.ended) return 'Khóa học kết thúc';
    if (widget.initialCourseModeFilter == 'study_exam') {
      return 'Khóa học có kiểm tra';
    }
    if (widget.initialCourseModeFilter == 'study_only') {
      return 'Khóa học không kiểm tra';
    }
    return 'Quản lý khóa học';
  }

  String? get activeMenu {
    if (widget.ended) return 'Khóa học kết thúc';
    if (widget.initialCourseModeFilter == 'study_exam') {
      return 'Khóa học có kiểm tra';
    }
    if (widget.initialCourseModeFilter == 'study_only') {
      return 'Khóa học không kiểm tra';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    refreshTimer.cancel();
    super.dispose();
  }

  Color _mauTrienKhai(String nhan) => switch (nhan) {
    'Đang triển khai' => Colors.green.shade700,
    'Đã triển khai' => Colors.blueGrey.shade700,
    _ => Colors.orange.shade800,
  };

  DateTime? _ngayBatDauKhoa(Map<String, dynamic> duLieu) {
    for (final khoa in ['startsAt', 'publishedAt', 'createdAt', 'updatedAt']) {
      final giaTri = LearningPolicy.readDateTime(duLieu[khoa]);
      if (giaTri != null) return giaTri;
    }
    return null;
  }

  DateTime? _ngayKetThucKhoa(Map<String, dynamic> duLieu) =>
      LearningPolicy.readDateTime(duLieu['endsAt']) ?? _ngayBatDauKhoa(duLieu);

  bool _khopNgay(Map<String, dynamic> duLieu) {
    if (dateFilter == 'all') return true;
    final batDau = _ngayBatDauKhoa(duLieu);
    final ketThuc = _ngayKetThucKhoa(duLieu);
    if (batDau == null && ketThuc == null) return false;
    final anchor = DateTime(
      dateFilterDate.year,
      dateFilterDate.month,
      dateFilterDate.day,
    );
    final tuNgay = switch (dateFilter) {
      'day' => anchor,
      'week' => anchor.subtract(Duration(days: anchor.weekday - 1)),
      'month' => DateTime(anchor.year, anchor.month),
      _ => anchor,
    };
    final denNgay = switch (dateFilter) {
      'day' => tuNgay.add(const Duration(days: 1)),
      'week' => tuNgay.add(const Duration(days: 7)),
      'month' => DateTime(tuNgay.year, tuNgay.month + 1),
      _ => tuNgay.add(const Duration(days: 1)),
    };
    final lower = batDau ?? ketThuc!;
    final upper = ketThuc ?? batDau!;
    return !upper.isBefore(tuNgay) && lower.isBefore(denNgay);
  }

  Future<void> _chonNgayLoc() async {
    final daChon = await showDatePicker(
      context: context,
      initialDate: dateFilterDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Chọn mốc thời gian lọc khóa học',
    );
    if (daChon != null && mounted) {
      setState(() => dateFilterDate = daChon);
    }
  }

  Future<void> edit([QueryDocumentSnapshot<Map<String, dynamic>>? banGhi]) {
    if (banGhi != null && LearningPolicy.hasEnded(banGhi.data())) {
      return Future<void>.value();
    }
    return showCourseEditor(context, service: service, course: banGhi);
  }

  Future<void> createCourse(String mode) =>
      showCourseEditor(context, service: service, fixedLearningMode: mode);

  Future<void> deleteCourse(
    QueryDocumentSnapshot<Map<String, dynamic>> banGhi,
  ) async {
    if (AccountSession.current?.isRoot != true) return;
    if (!_cacKhoaHocDangXoa.add(banGhi.id)) return;
    setState(() {});
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xóa vĩnh viễn khóa học'),
          content: Text(
            'Xóa vĩnh viễn khóa học "${banGhi.data()['title'] ?? ''}" cùng toàn bộ bài học, tiến độ và dữ liệu liên quan? Không thể hoàn tác.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa vĩnh viễn'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await service.deleteCourse(banGhi.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa vĩnh viễn khóa học và dữ liệu liên quan.'),
          ),
        );
      }
    } catch (loi) {
      debugPrint('Xóa khóa học ${banGhi.id} thất bại: $loi');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              service.deletionErrorMessage(loi, itemName: 'khóa học'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cacKhoaHocDangXoa.remove(banGhi.id));
      } else {
        _cacKhoaHocDangXoa.remove(banGhi.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AdminResponsiveShell(
    selectedIndex: 0,
    activeExtra: activeMenu,
    onSelected: (viTri) => pushAdminPrimary(context, viTri),
    child: Scaffold(
      appBar: AdminUi.appBar(pageTitle),
      body: LearningList(
        stream: stream,
        builder: (cacBanGhi) {
          final daLoc = cacBanGhi
              .where(
                (banGhi) =>
                    LearningPolicy.hasEnded(banGhi.data()) == widget.ended,
              )
              .where(
                (banGhi) =>
                    '${banGhi.data()['title']} ${banGhi.data()['subject']}'
                        .toLowerCase()
                        .contains(search),
              )
              .where(
                (banGhi) =>
                    courseModeFilter == 'all' ||
                    CourseForm.hasExam(banGhi.data()) ==
                        (courseModeFilter == 'study_exam'),
              )
              .where((banGhi) => _khopNgay(banGhi.data()))
              .toList();
          final soKhoaDaTrienKhai = daLoc
              .where((banGhi) => !LearningPolicy.isNotLaunched(banGhi.data()))
              .length;
          final dangHoatDong = daLoc
              .where(
                (banGhi) =>
                    LearningPolicy.deploymentLabel(banGhi.data()) ==
                    'Đang triển khai',
              )
              .length;
          final draft = daLoc
              .where((banGhi) => LearningPolicy.isNotLaunched(banGhi.data()))
              .length;
          final createActions =
              AccountSession.current?.isRoot != true || widget.ended
              ? null
              : Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (widget.initialCourseModeFilter != 'study_exam')
                      FilledButton.icon(
                        onPressed: () =>
                            createCourse(CourseForm.studyOnlyLabel),
                        icon: const Icon(Icons.add),
                        label: const Text('Tạo khóa học không kiểm tra'),
                      ),
                    if (widget.initialCourseModeFilter != 'study_only')
                      FilledButton.icon(
                        onPressed: () =>
                            createCourse(CourseForm.studyExamLabel),
                        icon: const Icon(Icons.add),
                        label: const Text('Tạo khóa học có kiểm tra'),
                      ),
                  ],
                );
          return Column(
            children: [
              AdminPageHeading(
                title: pageTitle,
                subtitle: widget.ended
                    ? 'Tra cứu và quản lý các khóa học đã kết thúc.'
                    : 'Quản lý các khóa học và nội dung học tập trên hệ thống.',
                action: createActions,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Tìm theo tên hoặc môn học',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (giaTri) =>
                      setState(() => search = giaTri.toLowerCase()),
                ),
              ),
              if (MediaQuery.sizeOf(context).width >= 900)
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final soLuong = constraints.maxWidth >= 600 ? 3 : 1;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: soLuong == 3
                                ? (constraints.maxWidth - 24) / 3
                                : constraints.maxWidth,
                            child: AdminMetricCard(
                              value: '$soKhoaDaTrienKhai',
                              label: widget.ended
                                  ? 'khóa học đã kết thúc'
                                  : 'khóa học đã triển khai',
                              icon: widget.ended
                                  ? Icons.inventory_2_outlined
                                  : Icons.menu_book_outlined,
                              color: AppTheme.red,
                            ),
                          ),
                          if (!widget.ended)
                            SizedBox(
                              width: soLuong == 3
                                  ? (constraints.maxWidth - 24) / 3
                                  : constraints.maxWidth,
                              child: AdminMetricCard(
                                value: '$dangHoatDong',
                                label: 'đang triển khai',
                                icon: Icons.play_circle_outline,
                                color: Colors.green.shade700,
                              ),
                            ),
                          if (!widget.ended)
                            SizedBox(
                              width: soLuong == 3
                                  ? (constraints.maxWidth - 24) / 3
                                  : constraints.maxWidth,
                              child: AdminMetricCard(
                                value: '$draft',
                                label: 'chưa triển khai',
                                icon: Icons.schedule_outlined,
                                color: Colors.orange.shade700,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              if (widget.initialCourseModeFilter == 'all')
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 4, 28, 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: 'all',
                          label: Text('Tất cả'),
                        ),
                        ButtonSegment<String>(
                          value: 'study_only',
                          label: Text('Học để biết'),
                        ),
                        ButtonSegment<String>(
                          value: 'study_exam',
                          label: Text('Học để làm bài kiểm tra'),
                        ),
                      ],
                      selected: {courseModeFilter},
                      onSelectionChanged: (giaTri) =>
                          setState(() => courseModeFilter = giaTri.first),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final dateSelector = SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value: 'all',
                            label: Text('Mọi thời gian'),
                          ),
                          ButtonSegment<String>(
                            value: 'day',
                            label: Text('Ngày'),
                          ),
                          ButtonSegment<String>(
                            value: 'week',
                            label: Text('Tuần'),
                          ),
                          ButtonSegment<String>(
                            value: 'month',
                            label: Text('Tháng'),
                          ),
                        ],
                        selected: {dateFilter},
                        onSelectionChanged: (giaTri) =>
                            setState(() => dateFilter = giaTri.first),
                      ),
                    );
                    final dateButton = OutlinedButton.icon(
                      onPressed: _chonNgayLoc,
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(
                        '${dateFilterDate.day.toString().padLeft(2, '0')}/${dateFilterDate.month.toString().padLeft(2, '0')}/${dateFilterDate.year}',
                      ),
                    );
                    if (constraints.maxWidth < 1000) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: constraints.maxWidth,
                            child: dateSelector,
                          ),
                          dateButton,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: dateSelector),
                        const SizedBox(width: 8),
                        dateButton,
                      ],
                    );
                  },
                ),
              ),
              Expanded(
                child: daLoc.isEmpty
                    ? const Center(child: Text('Chưa có khóa học phù hợp.'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 96),
                        itemCount: daLoc.length,
                        itemBuilder: (context, viTri) {
                          final banGhi = daLoc[viTri];
                          final d = banGhi.data();
                          final status = LearningPolicy.deploymentLabel(d);
                          final publishedAt = CourseForm.formatReleaseDateTime(
                            d['publishedAt'],
                          );
                          final dangXoa = _cacKhoaHocDangXoa.contains(
                            banGhi.id,
                          );
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: CourseCover(
                                url: d['coverUrl'] ?? '',
                                width: 64,
                                height: 56,
                              ),
                              title: Text(
                                d['title'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${d['subject']} • ${CourseForm.modeLabel(d)} • ${CourseForm.formatDateTime(d['startsAt'])} - ${CourseForm.formatDateTime(d['endsAt'])} • ${publishedAt.isEmpty ? 'Chưa ghi nhận ngày phát hành' : 'Phát hành: $publishedAt'}${(d['coverUrl'] as String? ?? '').isEmpty ? ' • Cần thêm ảnh bìa' : ''}',
                                style: TextStyle(color: _mauTrienKhai(status)),
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => widget.ended
                                      ? AdminCourseReportScreen(
                                          course: banGhi,
                                          service: service,
                                        )
                                      : AdminLessonsScreen(
                                          course: banGhi,
                                          service: service,
                                        ),
                                ),
                              ),
                              trailing: AccountSession.current?.isRoot != true
                                  ? null
                                  : Wrap(
                                      spacing: 4,
                                      children: [
                                        if (!LearningPolicy.hasEnded(d))
                                          IconButton(
                                            tooltip: 'Sửa khóa học',
                                            icon: const Icon(Icons.edit),
                                            onPressed: () => edit(banGhi),
                                          ),
                                        IconButton(
                                          tooltip: 'Xóa vĩnh viễn khóa học',
                                          icon: dangXoa
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.delete_outline,
                                                ),
                                          onPressed: dangXoa
                                              ? null
                                              : () => deleteCourse(banGhi),
                                        ),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
