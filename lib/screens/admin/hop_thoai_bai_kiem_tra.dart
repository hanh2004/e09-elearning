part of "quan_ly_bai_kiem_tra.dart";

extension _AdminExamDialogs on _TrangThaiBaiThiQuanTri {
  void _moHopThoaiThemBaiThi() {
    if (AccountSession.current?.isRoot != true) return;
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
                            final picked = await pickLearningDateTime(
                              context,
                              initialDateTime:
                                  closesAt ??
                                  LearningPolicy.nextFutureMinute().add(
                                    const Duration(days: 1),
                                  ),
                              futureOnly: true,
                            );
                            if (picked == null || !context.mounted) return;
                            setModalState(() {
                              closesAt = picked;
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
                      (unlimitedAttempts ||
                          (maxAttempts != null && maxAttempts > 0))) {
                    setModalState(() => busy = true);
                    try {
                      if (closesAt != null) {
                        LearningPolicy.requireFutureDateTime(
                          closesAt,
                          'Thời gian đóng đề',
                        );
                      }
                      await _dichVuFirestore.addExam(
                        title: titleController.text.trim(),
                        durationMinutes: durationMinutes,
                        isOpen: isOpen,
                        maxAttempts: maxAttempts,
                        closesAt: closesAt,
                      );
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    } catch (error) {
                      if (context.mounted) {
                        setModalState(() => busy = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error is ArgumentError
                                  ? error.message.toString()
                                  : 'Không tạo được bài thi. Vui lòng kiểm tra thời gian và thử lại.',
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

  Future<void> _suaQuyTac(String ma, Map<String, dynamic> baiThi) async {
    if (AccountSession.current?.isRoot != true) return;
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
        final batDau = LearningPolicy.readDateTime(startText);
        final ketThuc = LearningPolicy.readDateTime(endText);
        final previousStart = LearningPolicy.readDateTime(baiThi['opensAt']);
        final previousEnd = LearningPolicy.readDateTime(baiThi['closesAt']);
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
        if (startText.isNotEmpty &&
            !LearningPolicy.sameMinute(previousStart, batDau)) {
          LearningPolicy.requireFutureDateTime(batDau, 'Thời gian mở đề');
        }
        if (endText.isNotEmpty &&
            !LearningPolicy.sameMinute(previousEnd, ketThuc)) {
          LearningPolicy.requireFutureDateTime(ketThuc, 'Thời gian đóng đề');
        }
        final openToSave = LearningPolicy.sameMinute(previousStart, batDau)
            ? previousStart
            : batDau;
        final closeToSave = LearningPolicy.sameMinute(previousEnd, ketThuc)
            ? previousEnd
            : ketThuc;
        await _dichVuFirestore.updateExamPolicy(ma, {
          'passScore': diem,
          'showSolutions': show == 'có',
          'shuffleQuestions': shuffleQuestions == 'có',
          'shuffleAnswers': shuffleAnswers == 'có',
          'opensAt': openToSave == null ? null : Timestamp.fromDate(openToSave),
          'closesAt': closeToSave == null
              ? null
              : Timestamp.fromDate(closeToSave),
        });
      },
    );
  }
}
