// GIAO DIỆN DÙNG CHUNG: Danh sách Firebase và hộp chỉnh sửa dùng chung; cấu hình trường qua tham số.
// Các màn hình import tệp này sẽ dùng chung thay đổi.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/quy_tac_hoc_tap.dart';
import '../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../services/tep/dich_vu_tai_anh.dart';
import '../services/thong_bao_loi_ung_dung.dart';
import 'bo_soan_thao_bai_hoc.dart';
import 'anh_bia_khoa_hoc.dart';
import 'dau_trang_hoc_vien.dart';
import 'thong_bao_loi.dart';

/// Bộ chọn ngày giờ dùng chung cho lịch khóa học, đề thi và thông báo.
Future<DateTime?> pickLearningDateTime(
  BuildContext context, {
  DateTime? initialDateTime,
  bool futureOnly = false,
}) async {
  final now = DateTime.now();
  final requestedInitial =
      initialDateTime ??
      (futureOnly ? LearningPolicy.nextFutureMinute(now: now) : now);
  final initial = futureOnly && !requestedInitial.isAfter(now)
      ? LearningPolicy.nextFutureMinute(now: now)
      : requestedInitial;
  final firstDate = futureOnly
      ? DateTime(now.year, now.month, now.day)
      : DateTime(2000);
  final lastDate = DateTime(2100);
  final initialDate = DateTime(initial.year, initial.month, initial.day);
  final safeInitialDate = initialDate.isBefore(firstDate)
      ? firstDate
      : initialDate.isAfter(lastDate)
      ? lastDate
      : initialDate;
  final selectedDate = await showDatePicker(
    context: context,
    initialDate: safeInitialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  );
  if (selectedDate == null || !context.mounted) return null;
  final selectedTime = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (selectedTime == null || !context.mounted) return null;
  return DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    selectedTime.hour,
    selectedTime.minute,
  );
}

/// Trường nhập ngày giờ chỉ nhận chọn lịch, có thể yêu cầu thời điểm tương lai.
class LearningDateTimeField extends StatefulWidget {
  const LearningDateTimeField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.label,
    this.optional = false,
    this.mustBeFuture = false,
  });

  final TextEditingController controller;
  final bool enabled;
  final String label;
  final bool optional;
  final bool mustBeFuture;

  @override
  State<LearningDateTimeField> createState() => _LearningDateTimeFieldState();
}

class _LearningDateTimeFieldState extends State<LearningDateTimeField> {
  DateTime? _read() => LearningPolicy.readDateTime(widget.controller.text);

  String _format(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Future<void> _pick() async {
    final selected = await pickLearningDateTime(
      context,
      initialDateTime:
          _read() ??
          (widget.mustBeFuture ? LearningPolicy.nextFutureMinute() : null),
      futureOnly: widget.mustBeFuture,
    );
    if (selected == null || !mounted) return;
    setState(() => widget.controller.text = _format(selected));
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    enabled: widget.enabled,
    readOnly: true,
    onTap: widget.enabled ? _pick : null,
    decoration: InputDecoration(
      labelText: widget.label,
      border: const OutlineInputBorder(),
      prefixIcon: const Icon(Icons.calendar_month_outlined),
      suffixIcon: widget.controller.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Xóa ngày giờ',
              onPressed: widget.enabled
                  ? () => setState(widget.controller.clear)
                  : null,
              icon: const Icon(Icons.clear),
            ),
    ),
    validator: (value) {
      if (!widget.optional && (value == null || value.trim().isEmpty)) {
        return 'Vui lòng chọn ngày giờ';
      }
      if (value == null || value.trim().isEmpty) return null;
      final parsed = LearningPolicy.readDateTime(value);
      if (parsed == null) return 'Ngày giờ không hợp lệ.';
      if (widget.mustBeFuture && !parsed.isAfter(DateTime.now())) {
        return '${widget.label} phải sau thời điểm hiện tại.';
      }
      return null;
    },
  );
}

class LearningList extends StatelessWidget {
  const LearningList({
    super.key,
    required this.stream,
    required this.builder,
    this.errorTitle = 'Tải dữ liệu',
  });
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final Widget Function(List<QueryDocumentSnapshot<Map<String, dynamic>>>)
  builder;
  final String errorTitle;
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: stream,
    builder: (context, duLieuNhan) {
      if (duLieuNhan.hasError) {
        return AppErrorNotice(
          error: duLieuNhan.error!,
          feature: errorTitle,
          padding: const EdgeInsets.all(24),
          fallbackAction:
              'Kiểm tra kết nối mạng và cấu hình máy chủ rồi tải lại trang.',
        );
      }
      if (!duLieuNhan.hasData) {
        return const Center(
          child: SizedBox(
            width: 220,
            child: LinearProgressIndicator(minHeight: 4),
          ),
        );
      }
      return builder(duLieuNhan.data!.docs);
    },
  );
}

/// [fields] dùng mã trường ổn định; [labels] chỉ đổi chữ hiển thị trên form.
/// Form cũ có thể bỏ [labels] để tiếp tục dùng nhãn làm mã trường.
Future<bool> editLearningRecord(
  BuildContext context, {
  required String title,
  required Map<String, String> fields,
  required Future<void> Function(Map<String, String>) save,
  Map<String, String> labels = const {},
  Set<String> optional = const {},
  Set<String> urls = const {},
  Map<String, int> maxLengths = const {},
  Map<String, List<String>> selectFields = const {},
  Map<String, bool Function(Map<String, String>)> visibleWhen = const {},
  Set<String> dateTimeFields = const {},
  Set<String> futureDateTimeFields = const {},
  Set<String> richTextFields = const {},
  String? imageFolder,
  Map<String, IconData>? iconChoices,
  String initialImage = '',
  bool imageRequired = false,
  bool fullPage = false,
  String? note,
  ImageUploadService? imageService,
}) async {
  var imageUrl = initialImage;
  final uploader = imageService ?? ImageUploadService();
  SelectedUploadImage? selectedImage;
  double? uploadProgress;

  void showErrorNotification(String thongDiep) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null || thongDiep.trim().isEmpty) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(thongDiep),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String errorMessage(Object loi) {
    if (loi is ImageUploadException) return loi.message;
    return AppErrorMessage.from(
      loi,
      feature: title,
      fallbackAction: 'Kiểm tra thông tin đã nhập, quyền tài khoản và kết nối máy chủ rồi thử lại.',
    );
  }

  final controllers = {
    for (final e in fields.entries) e.key: TextEditingController(text: e.value),
  };
  final form = GlobalKey<FormState>();
  var busy = false;
  String? loi;
  final ketQua = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => _KhungSuaBanGhi(
        fullPage: fullPage,
        title: Text(title),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (note != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(note),
                    ),
                  if (imageFolder != null || iconChoices != null) ...[
                    _XemTruocAnhDaChon(url: imageUrl, image: selectedImage),
                    const SizedBox(height: 10),
                    if (iconChoices != null)
                      _BoChonBieuTuong(
                        choices: iconChoices,
                        selected: imageUrl.startsWith('icon:')
                            ? imageUrl.substring(5)
                            : null,
                        onSelected: busy
                            ? null
                            : (khoa) => setState(() {
                                imageUrl = 'icon:$khoa';
                                selectedImage = null;
                                loi = null;
                              }),
                      ),
                    if (imageFolder != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(
                            busy
                                ? 'Đang xử lý…'
                                : imageUrl.isEmpty
                                ? 'Chọn ảnh từ thiết bị (tối đa 20 MB)'
                                : 'Đổi ảnh từ thiết bị (tối đa 20 MB)',
                          ),
                          onPressed: busy
                              ? null
                              : () async {
                                  setState(() {
                                    busy = true;
                                    loi = null;
                                  });
                                  try {
                                    final picked = await uploader.pick();
                                    if (context.mounted && picked != null) {
                                      setState(() {
                                        selectedImage = picked;
                                        imageUrl = '';
                                      });
                                    }
                                  } catch (errorObject) {
                                    if (context.mounted) {
                                      final thongDiep = errorMessage(
                                        errorObject,
                                      );
                                      showErrorNotification(thongDiep);
                                      setState(() => loi = thongDiep);
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setState(() => busy = false);
                                    }
                                  }
                                },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (selectedImage != null) ...[
                      Text(
                        selectedImage!.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Ảnh xem trước trên thiết bị. Bấm Lưu để tải lên.',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (uploadProgress != null) ...[
                      LinearProgressIndicator(value: uploadProgress),
                      Text('Đang tải ảnh: ${(uploadProgress! * 100).round()}%'),
                      const SizedBox(height: 12),
                    ],
                  ],
                  for (final capDuLieu in controllers.entries)
                    if (visibleWhen[capDuLieu.key]?.call({
                          for (final e in controllers.entries)
                            e.key: e.value.text,
                        }) ??
                        true)
                      Padding(
                        key: ValueKey(capDuLieu.key),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: dateTimeFields.contains(capDuLieu.key)
                            ? LearningDateTimeField(
                                controller: capDuLieu.value,
                                enabled: !busy,
                                label: labels[capDuLieu.key] ?? capDuLieu.key,
                                optional: optional.contains(capDuLieu.key),
                                mustBeFuture: futureDateTimeFields.contains(
                                  capDuLieu.key,
                                ),
                              )
                            : selectFields.containsKey(capDuLieu.key)
                            ? DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue:
                                    selectFields[capDuLieu.key]!.contains(
                                      capDuLieu.value.text,
                                    )
                                    ? capDuLieu.value.text
                                    : selectFields[capDuLieu.key]!.first,
                                decoration: InputDecoration(
                                  labelText:
                                      labels[capDuLieu.key] ?? capDuLieu.key,
                                  border: const OutlineInputBorder(),
                                ),
                                items: [
                                  for (final luaChon
                                      in selectFields[capDuLieu.key]!)
                                    DropdownMenuItem(
                                      value: luaChon,
                                      child: Text(
                                        luaChon,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: busy
                                    ? null
                                    : (giaTri) {
                                        if (giaTri != null) {
                                          setState(
                                            () => capDuLieu.value.text = giaTri,
                                          );
                                        }
                                      },
                                validator: (giaTri) =>
                                    giaTri == null || giaTri.trim().isEmpty
                                    ? 'Vui lòng chọn thông tin'
                                    : null,
                              )
                            : richTextFields.contains(capDuLieu.key)
                            ? LessonRichEditor(
                                controller: capDuLieu.value,
                                enabled: !busy,
                                label:
                                    labels[capDuLieu.key] ?? 'Nội dung bài học',
                                imageFolder: imageFolder,
                              )
                            : TextFormField(
                                controller: capDuLieu.value,
                                enabled: !busy,
                                obscureText: capDuLieu.key
                                    .toLowerCase()
                                    .contains('mật khẩu'),
                                minLines: 1,
                                maxLines:
                                    capDuLieu.key.toLowerCase().contains(
                                      'mật khẩu',
                                    )
                                    ? 1
                                    : capDuLieu.key.contains('Nội dung')
                                    ? 8
                                    : 2,
                                decoration: InputDecoration(
                                  labelText:
                                      labels[capDuLieu.key] ?? capDuLieu.key,
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (giaTri) {
                                  final vanBan = giaTri!.trim();
                                  if (!optional.contains(capDuLieu.key) &&
                                      vanBan.isEmpty) {
                                    return 'Vui lòng nhập thông tin';
                                  }
                                  final gioiHan =
                                      maxLengths[capDuLieu.key] ?? 20000;
                                  if (vanBan.length > gioiHan) {
                                    return 'Tối đa $gioiHan ký tự.';
                                  }
                                  if (urls.contains(capDuLieu.key)) {
                                    return LearningPolicy.validateUrl(vanBan);
                                  }
                                  return null;
                                },
                              ),
                      ),
                  if (loi != null)
                    Text(loi!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    if (imageRequired &&
                        imageUrl.isEmpty &&
                        selectedImage == null) {
                      setState(
                        () => loi = iconChoices == null
                            ? 'Vui lòng chọn ảnh bìa từ thiết bị trước khi lưu.'
                            : 'Vui lòng chọn ảnh bìa hoặc biểu tượng trước khi lưu.',
                      );
                      showErrorNotification(
                        iconChoices == null
                            ? 'Vui lòng chọn ảnh bìa từ thiết bị trước khi lưu.'
                            : 'Vui lòng chọn ảnh bìa hoặc biểu tượng trước khi lưu.',
                      );
                      return;
                    }
                    setState(() {
                      busy = true;
                      loi = null;
                    });
                    try {
                      if (selectedImage != null && imageFolder != null) {
                        setState(() => uploadProgress = 0);
                        final uploadedUrl = await uploader.upload(
                          imageFolder,
                          selectedImage!,
                          onProgress: (tienDo) {
                            if (context.mounted) {
                              setState(() => uploadProgress = tienDo);
                            }
                          },
                        );
                        imageUrl = uploadedUrl;
                        if (!context.mounted) return;
                        setState(() {
                          selectedImage = null;
                          uploadProgress = null;
                        });
                      }
                      await save({
                        if (imageFolder != null || iconChoices != null)
                          'imageUrl': imageUrl,
                        for (final e in controllers.entries)
                          e.key: e.key.toLowerCase().contains('mật khẩu')
                              ? e.value.text
                              : e.value.text.trim(),
                      });
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (saveError) {
                      if (context.mounted) {
                        final thongDiep = errorMessage(saveError);
                        showErrorNotification(thongDiep);
                        setState(() {
                          busy = false;
                          uploadProgress = null;
                          loi = thongDiep;
                        });
                      }
                    }
                  },
            child: Text(busy ? 'Đang lưu…' : 'Lưu'),
          ),
        ],
      ),
    ),
  );
  // Hủy controller sau khi hiệu ứng đóng hộp thoại kết thúc.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  for (final boDieuKhien in controllers.values) {
    boDieuKhien.dispose();
  }
  return ketQua == true;
}

class _KhungSuaBanGhi extends StatelessWidget {
  const _KhungSuaBanGhi({
    required this.fullPage,
    required this.title,
    required this.content,
    required this.actions,
  });

  final bool fullPage;
  final Widget title, content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (!fullPage) {
      return AlertDialog(title: title, content: content, actions: actions);
    }
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: LearnerHeader(title: title, automaticallyImplyLeading: false),
        body: Center(
          child: Padding(padding: const EdgeInsets.all(20), child: content),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions,
            ),
          ),
        ),
      ),
    );
  }
}

class _XemTruocAnhDaChon extends StatelessWidget {
  const _XemTruocAnhDaChon({required this.url, this.image});

  final String url;
  final SelectedUploadImage? image;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: const Color(0xFFF6E9E7),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE4C9C5)),
    ),
    clipBehavior: Clip.antiAlias,
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: image != null
          ? Image.memory(
              image!.bytes,
              fit: BoxFit.contain,
              cacheWidth: 1000,
              errorBuilder: (_, _, _) => const Center(
                child: Text('Không đọc được ảnh. Hãy chọn lại.'),
              ),
            )
          : url.startsWith('icon:')
          ? CourseCover(url: url, height: 160)
          : url.isEmpty
          ? const Center(
              child: Icon(
                Icons.image_outlined,
                size: 36,
                color: Color(0xFF5A2F2F),
              ),
            )
          : Image.network(
              url,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loading) => loading == null
                  ? child
                  : const Center(
                      child: SizedBox(
                        width: 180,
                        child: LinearProgressIndicator(minHeight: 4),
                      ),
                    ),
              errorBuilder: (_, _, _) => const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 36,
                  color: Color(0xFF5A2F2F),
                ),
              ),
            ),
    ),
  );
}

class _BoChonBieuTuong extends StatelessWidget {
  const _BoChonBieuTuong({
    required this.choices,
    required this.selected,
    required this.onSelected,
  });
  final Map<String, IconData> choices;
  final String? selected;
  final ValueChanged<String>? onSelected;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: choices.entries
        .map(
          (capDuLieu) => InkWell(
            onTap: onSelected == null ? null : () => onSelected!(capDuLieu.key),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: selected == capDuLieu.key
                    ? const Color(0xFFFFE0E0)
                    : const Color(0xFFF6E9E7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected == capDuLieu.key
                      ? const Color(0xFFC51F2B)
                      : const Color(0xFFE4C9C5),
                  width: selected == capDuLieu.key ? 2 : 1,
                ),
              ),
              child: Icon(
                capDuLieu.value,
                color: const Color(0xFFC51F2B),
                size: 30,
              ),
            ),
          ),
        )
        .toList(),
  );
}
