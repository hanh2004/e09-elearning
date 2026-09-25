// WEB ADMIN: Quản lý đề kiểm tra, chính sách làm bài và thời gian mở/đóng đề.
// Sửa giao diện trong build(); tìm hàm xử lý tương ứng để sửa thao tác.

import '../../widgets/learning_widgets.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/du_lieu/firestore_service.dart';
import 'admin_question_bank_screen.dart';
import 'admin_home_screen.dart';
import 'admin_report_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_responsive_shell.dart';
import '../../models/question_bank_arguments.dart';
import '../../models/account_identity.dart';
import '../../widgets/admin_ui.dart';

/// Quản lý đề kiểm tra, chính sách làm bài và thời gian mở/đóng đề.
class AdminExamScreen extends StatefulWidget {
  const AdminExamScreen({super.key, this.service});
  final FirestoreService? service;

  @override
  State<AdminExamScreen> createState() => _TrangThaiBaiThiQuanTri();
}

class _TrangThaiBaiThiQuanTri extends State<AdminExamScreen> {
  late final FirestoreService _dichVuFirestore =
      widget.service ?? FirestoreService();
  final Color primaryColor = const Color(0xFFB51F24);
  String _tuKhoaTimKiem = '';
  final int _viTriDaChon = 1;

  void _chonMuc(int viTri) {
    if (viTri == _viTriDaChon) return;

    switch (viTri) {
      case 0:
        Navigator.pushReplacement(
          context,
          adminTabRoute(const AdminHomeScreen()),
        );
        break;
      case 1:
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          adminTabRoute(const AdminReportScreen()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          adminTabRoute(const AdminSettingsScreen()),
        );
        break;
    }
  }

  void _moHopThoaiThemBaiThi() {
    final titleController = TextEditingController();
    final durationController = TextEditingController();
    final maxAttemptsController = TextEditingController(text: '1');
    bool isOpen = true;
    bool busy = false;
    bool unlimitedAttempts = true;
    DateTime? closesAt;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('Tạo Bài Thi Mới'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Tên bài thi'),
                  ),
                  TextField(
                    controller: durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Thời gian làm bài (phút)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Không giới hạn lượt làm'),
                    value: unlimitedAttempts,
                    activeThumbColor: primaryColor,
                    onChanged: (giaTri) =>
                        setModalState(() => unlimitedAttempts = giaTri),
                  ),
                  if (!unlimitedAttempts)
                    TextField(
                      controller: maxAttemptsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Số lượt làm tối đa',
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Trạng thái mở đề:'),
                      Switch(
                        value: isOpen,
                        activeThumbColor: primaryColor,
                        onChanged: (val) => setModalState(() => isOpen = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available_outlined),
                    title: Text(
                      closesAt == null
                          ? 'Không đặt ngày tự đóng'
                          : 'Tự đóng: ${closesAt!.day.toString().padLeft(2, '0')}/'
                                '${closesAt!.month.toString().padLeft(2, '0')}/'
                                '${closesAt!.year} '
                                '${closesAt!.hour.toString().padLeft(2, '0')}:'
                                '${closesAt!.minute.toString().padLeft(2, '0')}',
                    ),
                    subtitle: const Text('Vẫn có thể đóng/mở thủ công'),
                    trailing: Wrap(
                      children: [
                        if (closesAt != null)
                          IconButton(
                            tooltip: 'Bỏ ngày đóng',
                            onPressed: () =>
                                setModalState(() => closesAt = null),
                            icon: const Icon(Icons.close),
                          ),
                        IconButton(
                          tooltip: 'Chọn ngày giờ đóng',
                          onPressed: () async {
                            final hienTai = DateTime.now();
                            final initial =
                                closesAt ??
                                hienTai.add(const Duration(days: 1));
                            final ngay = await showDatePicker(
                              context: context,
                              initialDate: initial,
                              firstDate: hienTai,
                              lastDate: hienTai.add(const Duration(days: 3650)),
                            );
                            if (ngay == null || !context.mounted) return;
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(initial),
                            );
                            if (time == null || !context.mounted) return;
                            setModalState(() {
                              closesAt = DateTime(
                                ngay.year,
                                ngay.month,
                                ngay.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          },
                          icon: const Icon(Icons.edit_calendar_outlined),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                onPressed: () async {
                  if (busy) return;
                  final maxAttempts = unlimitedAttempts
                      ? null
                      : int.tryParse(maxAttemptsController.text.trim());
                  final durationMinutes = int.tryParse(
                    durationController.text.trim(),
                  );
                  if (titleController.text.trim().isNotEmpty &&
                      durationMinutes != null &&
                      durationMinutes > 0 &&
                      durationMinutes <= 1440 &&
                      (closesAt == null || closesAt!.isAfter(DateTime.now())) &&
                      (unlimitedAttempts ||
                          (maxAttempts != null && maxAttempts > 0))) {
                    setModalState(() => busy = true);
                    try {
                      await _dichVuFirestore.addExam(
                        title: titleController.text.trim(),
                        durationMinutes: durationMinutes,
                        isOpen: isOpen,
                        maxAttempts: maxAttempts,
                        closesAt: closesAt,
                      );
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    } catch (_) {
                      if (context.mounted) {
                        setModalState(() => busy = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Không tạo được bài thi. Vui lòng thử lại.',
                            ),
                          ),
                        );
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng nhập đầy đủ thông tin!'),
                      ),
                    );
                  }
                },
                child: const Text('Tạo', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final laMayTinh = AdminResponsiveShell.isDesktop(context);
    return AdminResponsiveShell(
      selectedIndex: _viTriDaChon,
      onSelected: _chonMuc,
      child: Scaffold(
        backgroundColor: AdminUi.page,
        appBar: AdminUi.appBar('Quản lý Kiểm tra'),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey[400]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (val) =>
                            setState(() => _tuKhoaTimKiem = val.toLowerCase()),
                        decoration: const InputDecoration(
                          hintText: 'Tìm kiếm tên bài thi...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _dichVuFirestore.getExamsStream(),
                builder: (context, duLieuNhan) {
                  if (duLieuNhan.hasError) {
                    return const Center(child: Text('Lỗi tải dữ liệu'));
                  }
                  if (duLieuNhan.connectionState == ConnectionState.waiting) {
                    return const AdminLoading();
                  }

                  final cacBanGhi = duLieuNhan.data!.docs.where((banGhi) {
                    final tieuDe =
                        banGhi.data()['title']?.toString().toLowerCase() ?? '';
                    return tieuDe.contains(_tuKhoaTimKiem);
                  }).toList();

                  if (cacBanGhi.isEmpty) {
                    return const Center(child: Text('Chưa có bài thi nào'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: cacBanGhi.length,
                    itemBuilder: (context, viTri) {
                      final banGhi = cacBanGhi[viTri];
                      final baiThi = banGhi.data();
                      return _dungTheBaiThi(banGhi.id, baiThi);
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: AccountSession.current?.isRoot == true
                      ? _moHopThoaiThemBaiThi
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(
                    AccountSession.current?.isRoot == true
                        ? 'Tạo bài thi mới'
                        : 'Chỉ quản lý tổng được tạo bài thi',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: laMayTinh
            ? null
            : BottomNavigationBar(
                currentIndex: _viTriDaChon,
                onTap: _chonMuc,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: primaryColor,
                unselectedItemColor: Colors.grey,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: 'Trang chủ',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.assignment),
                    label: 'Bài thi',
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

  Future<void> _suaQuyTac(String ma, Map<String, dynamic> baiThi) async {
    String date(Object? giaTri) =>
        giaTri is Timestamp ? giaTri.toDate().toString().substring(0, 16) : '';
    await editLearningRecord(
      context,
      title: 'Cài đặt bài thi',
      fields: {
        'Điểm đạt (0–10)': '${baiThi['passScore'] ?? 5}',
        'Trộn câu hỏi (có/không)': baiThi['shuffleQuestions'] == true
            ? 'có'
            : 'không',
        'Trộn đáp án (có/không)': baiThi['shuffleAnswers'] == true
            ? 'có'
            : 'không',
        'Cho xem lời giải (có/không)': baiThi['showSolutions'] == true
            ? 'có'
            : 'không',
        'Mở đề lúc (YYYY-MM-DD HH:mm)': date(baiThi['opensAt']),
        'Đóng đề lúc (YYYY-MM-DD HH:mm)': date(baiThi['closesAt']),
      },
      optional: {
        'Mở đề lúc (YYYY-MM-DD HH:mm)',
        'Đóng đề lúc (YYYY-MM-DD HH:mm)',
      },
      labels: {
        'Trộn câu hỏi (có/không)': 'Trộn câu hỏi',
        'Trộn đáp án (có/không)': 'Trộn đáp án',
        'Cho xem lời giải (có/không)': 'Cho xem lời giải',
      },
      selectFields: {
        'Trộn câu hỏi (có/không)': ['có', 'không'],
        'Trộn đáp án (có/không)': ['có', 'không'],
        'Cho xem lời giải (có/không)': ['có', 'không'],
      },
      dateTimeFields: {
        'Mở đề lúc (YYYY-MM-DD HH:mm)',
        'Đóng đề lúc (YYYY-MM-DD HH:mm)',
      },
      save: (cacGiaTri) async {
        final diem = double.tryParse(cacGiaTri['Điểm đạt (0–10)']!);
        final show = cacGiaTri['Cho xem lời giải (có/không)']!.toLowerCase();
        final shuffleQuestions = cacGiaTri['Trộn câu hỏi (có/không)']!
            .toLowerCase();
        final shuffleAnswers = cacGiaTri['Trộn đáp án (có/không)']!
            .toLowerCase();
        final startText = cacGiaTri['Mở đề lúc (YYYY-MM-DD HH:mm)']!;
        final endText = cacGiaTri['Đóng đề lúc (YYYY-MM-DD HH:mm)']!;
        final batDau = DateTime.tryParse(startText);
        final ketThuc = DateTime.tryParse(endText);
        if (diem == null ||
            !diem.isFinite ||
            diem < 0 ||
            diem > 10 ||
            !['có', 'không'].contains(show) ||
            !['có', 'không'].contains(shuffleQuestions) ||
            !['có', 'không'].contains(shuffleAnswers) ||
            (startText.isNotEmpty && batDau == null) ||
            (endText.isNotEmpty && ketThuc == null) ||
            (batDau != null && ketThuc != null && !ketThuc.isAfter(batDau))) {
          throw ArgumentError('Cài đặt chưa hợp lệ.');
        }
        await _dichVuFirestore.updateExamPolicy(ma, {
          'passScore': diem,
          'showSolutions': show == 'có',
          'shuffleQuestions': shuffleQuestions == 'có',
          'shuffleAnswers': shuffleAnswers == 'có',
          'opensAt': batDau == null ? null : Timestamp.fromDate(batDau),
          'closesAt': ketThuc == null ? null : Timestamp.fromDate(ketThuc),
        });
      },
    );
  }

  Widget _dungTheBaiThi(String docId, Map<String, dynamic> baiThi) {
    final bool isOpen = baiThi['isOpen'] ?? false;
    final canManageExam = AccountSession.current?.isRoot == true;
    final rawClosing = baiThi['closesAt'];
    final closing = rawClosing is Timestamp ? rawClosing.toDate() : null;
    final hasExpired = closing != null && !closing.isAfter(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        baiThi['title'] ?? 'Chưa có tên',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: canManageExam
                          ? () => _dichVuFirestore.updateExamStatus(
                              docId,
                              !isOpen,
                            )
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isOpen ? Colors.green[50] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          hasExpired
                              ? 'Đã hết hạn'
                              : isOpen
                              ? 'Đang mở'
                              : 'Đã đóng',
                          style: TextStyle(
                            color: isOpen
                                ? Colors.green[700]
                                : Colors.grey[600],
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _dungNhanThongTin(
                      Icons.access_time,
                      baiThi['duration'] ?? 'N/A',
                    ),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _dichVuFirestore.getQuestionsStream(docId),
                      builder: (context, duLieuNhan) => _dungNhanThongTin(
                        Icons.format_list_bulleted,
                        '${duLieuNhan.data?.docs.length ?? 0} câu thực tế',
                      ),
                    ),
                    _dungNhanThongTin(
                      Icons.replay,
                      baiThi['maxAttempts'] == null
                          ? 'Không giới hạn'
                          : '${baiThi['maxAttempts']} lượt',
                    ),
                    _dungNhanThongTin(
                      Icons.event_outlined,
                      closing == null
                          ? 'Không có ngày đóng'
                          : 'Tự đóng ${closing.day.toString().padLeft(2, '0')}/'
                                '${closing.month.toString().padLeft(2, '0')}/'
                                '${closing.year} '
                                '${closing.hour.toString().padLeft(2, '0')}:'
                                '${closing.minute.toString().padLeft(2, '0')}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[200]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminQuestionBankScreen(
                          args: QuestionBankArguments(
                            examId: docId,
                            examTitle: baiThi['title'] ?? 'Bài thi',
                          ),
                        ),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.quiz_outlined,
                    size: 18,
                    color: primaryColor,
                  ),
                  label: Text(
                    canManageExam ? 'Quản lý câu hỏi' : 'Xem câu hỏi',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (canManageExam)
                  IconButton(
                    tooltip: 'Điểm đạt, lời giải và lịch mở đề',
                    icon: const Icon(Icons.tune),
                    onPressed: () => _suaQuyTac(docId, baiThi),
                  ),
                if (canManageExam)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.red[400],
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Xác nhận xóa'),
                          content: const Text(
                            'Bài thi, toàn bộ câu hỏi và lịch sử làm bài của '
                            'người dùng sẽ bị xóa. Bạn có chắc chắn?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Hủy'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                'Xóa',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          await _dichVuFirestore.deleteExam(docId);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Đã xóa bài thi và toàn bộ lịch sử liên quan.',
                              ),
                            ),
                          );
                        } catch (loi) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Không thể xóa bài thi: $loi'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dungNhanThongTin(IconData bieuTuong, String nhan) {
    return Row(
      children: [
        Icon(bieuTuong, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(nhan, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
