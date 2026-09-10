import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';
import 'admin_question_bank_screen.dart';
import 'admin_home_screen.dart';
import 'admin_report_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_responsive_shell.dart';
import '../../models/question_bank_arguments.dart';
import '../../models/account_identity.dart';

class AdminExamScreen extends StatefulWidget {
  const AdminExamScreen({super.key, this.service});
  final FirestoreService? service;

  @override
  State<AdminExamScreen> createState() => _AdminExamScreenState();
}

class _AdminExamScreenState extends State<AdminExamScreen> {
  late final FirestoreService _firestoreService =
      widget.service ?? FirestoreService();
  final Color primaryColor = const Color(0xFF6B0000);
  String _searchQuery = '';
  final int _selectedIndex = 1;

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    switch (index) {
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

  void _showAddExamDialog() {
    final titleController = TextEditingController();
    final durationController = TextEditingController();
    final maxAttemptsController = TextEditingController(text: '1');
    bool isOpen = true;
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
                    onChanged: (value) =>
                        setModalState(() => unlimitedAttempts = value),
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
                            final now = DateTime.now();
                            final initial =
                                closesAt ?? now.add(const Duration(days: 1));
                            final date = await showDatePicker(
                              context: context,
                              initialDate: initial,
                              firstDate: now,
                              lastDate: now.add(const Duration(days: 3650)),
                            );
                            if (date == null || !context.mounted) return;
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(initial),
                            );
                            if (time == null) return;
                            setModalState(() {
                              closesAt = DateTime(
                                date.year,
                                date.month,
                                date.day,
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
                  final maxAttempts = unlimitedAttempts
                      ? null
                      : int.tryParse(maxAttemptsController.text.trim());
                  final durationMinutes = int.tryParse(
                    durationController.text.trim(),
                  );
                  if (titleController.text.isNotEmpty &&
                      durationMinutes != null &&
                      durationMinutes > 0 &&
                      durationMinutes <= 1440 &&
                      (closesAt == null || closesAt!.isAfter(DateTime.now())) &&
                      (unlimitedAttempts ||
                          (maxAttempts != null && maxAttempts > 0))) {
                    await _firestoreService.addExam(
                      title: titleController.text.trim(),
                      durationMinutes: durationMinutes,
                      isOpen: isOpen,
                      maxAttempts: maxAttempts,
                      closesAt: closesAt,
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
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
    final isDesktop = AdminResponsiveShell.isDesktop(context);
    return AdminResponsiveShell(
      selectedIndex: _selectedIndex,
      onSelected: _onItemTapped,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: primaryColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Quản lý Kiểm tra',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
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
                            setState(() => _searchQuery = val.toLowerCase()),
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
                stream: _firestoreService.getExamsStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Lỗi tải dữ liệu'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs.where((doc) {
                    final title =
                        doc.data()['title']?.toString().toLowerCase() ?? '';
                    return title.contains(_searchQuery);
                  }).toList();

                  if (docs.isEmpty) {
                    return const Center(child: Text('Chưa có bài thi nào'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final exam = doc.data();
                      return _buildExamCard(doc.id, exam);
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
                      ? _showAddExamDialog
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
                        : 'Chỉ Admin tổng được tạo bài thi',
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
        bottomNavigationBar: isDesktop
            ? null
            : BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
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

  Widget _buildExamCard(String docId, Map<String, dynamic> exam) {
    final bool isOpen = exam['isOpen'] ?? false;
    final canManageExam = AccountSession.current?.isRoot == true;
    final rawClosing = exam['closesAt'];
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
                        exam['title'] ?? 'Chưa có tên',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: canManageExam
                          ? () => _firestoreService.updateExamStatus(
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
                    _buildInfoChip(
                      Icons.access_time,
                      exam['duration'] ?? 'N/A',
                    ),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _firestoreService.getQuestionsStream(docId),
                      builder: (context, snapshot) => _buildInfoChip(
                        Icons.format_list_bulleted,
                        '${snapshot.data?.docs.length ?? 0} câu thực tế',
                      ),
                    ),
                    _buildInfoChip(
                      Icons.replay,
                      exam['maxAttempts'] == null
                          ? 'Không giới hạn'
                          : '${exam['maxAttempts']} lượt',
                    ),
                    _buildInfoChip(
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
                            examTitle: exam['title'] ?? 'Bài thi',
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
                          await _firestoreService.deleteExam(docId);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Đã xóa bài thi và toàn bộ lịch sử liên quan.',
                              ),
                            ),
                          );
                        } catch (error) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Không thể xóa bài thi: $error'),
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

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
