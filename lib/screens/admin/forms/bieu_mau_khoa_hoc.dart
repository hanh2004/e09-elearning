// WEB ADMIN: Form tạo/sửa khóa học theo thiết kế modal quản trị.
// Quy tắc dữ liệu vẫn dùng CourseForm để không làm thay đổi dữ liệu đang có.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../app/chu_de_ung_dung.dart';
import '../../../models/dinh_danh_tai_khoan.dart';
import '../../../models/bieu_mau_khoa_hoc.dart';
import '../../../services/tep/dich_vu_tai_anh.dart';
import '../../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../../widgets/giao_dien_quan_tri.dart';
import '../../../widgets/tien_ich_giao_dien_hoc_tap.dart';

/// Form tạo/sửa khóa học. [fixedLearningMode] dùng cho hai trang danh sách
/// Khóa học không kiểm tra và Khóa học có kiểm tra.
Future<void> showCourseEditor(
  BuildContext context, {
  required LearningService service,
  QueryDocumentSnapshot<Map<String, dynamic>>? course,
  String? fixedLearningMode,
}) async {
  final taiKhoan = AccountSession.current;
  if (taiKhoan?.isRoot != true) return;
  final duLieu = course?.data() ?? <String, dynamic>{};
  if (LearningPolicy.hasEnded(duLieu) || !context.mounted) return;

  final fixedMode = switch (fixedLearningMode) {
    'study_only' => CourseForm.studyOnlyLabel,
    'study_exam' => CourseForm.studyExamLabel,
    _ => fixedLearningMode,
  };
  final mode = fixedMode ?? CourseForm.modeLabel(duLieu);

  await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _HopThoaiSuaKhoaHoc(
      mode: mode,
      initialData: duLieu,
      onSave: (cacGiaTri) async {
        final examId = mode == CourseForm.studyExamLabel
            ? (duLieu['examId'] ?? '').toString()
            : '';
        final duLieuGui = CourseForm.toFirestore(
          {...cacGiaTri, 'learningMode': mode, 'examId': examId},
          published: duLieu['published'] == true,
          allowPendingExam: mode == CourseForm.studyExamLabel && examId.isEmpty,
          previousCourse: course?.data(),
        );
        if ((duLieuGui['examId'] as String? ?? '').isNotEmpty) {
          final baiThi = await service.db
              .collection('exams')
              .doc(duLieuGui['examId'])
              .get();
          if (!baiThi.exists || baiThi.data()?['deleting'] == true) {
            throw ArgumentError('Bài kiểm tra của khóa học không còn tồn tại.');
          }
          final chuSoHuu = (baiThi.data()?['courseId'] ?? '').toString();
          if (chuSoHuu.isNotEmpty && chuSoHuu != course?.id) {
            throw ArgumentError('Bài kiểm tra đã thuộc một khóa học khác.');
          }
        }
        final courseRef =
            course?.reference ?? service.db.collection('courses').doc();
        await service.saveContent(taiKhoan!.id, courseRef, duLieuGui);
        final linkedExamId = duLieuGui['examId']?.toString() ?? '';
        if (linkedExamId.isNotEmpty) {
          await service.db.collection('exams').doc(linkedExamId).set({
            'courseId': courseRef.id,
            'courseEndsAt': duLieuGui['endsAt'],
          }, SetOptions(merge: true));
        }
      },
    ),
  );
}

class _HopThoaiSuaKhoaHoc extends StatefulWidget {
  const _HopThoaiSuaKhoaHoc({
    required this.mode,
    required this.initialData,
    required this.onSave,
  });

  final String mode;
  final Map<String, dynamic> initialData;
  final Future<void> Function(Map<String, String>) onSave;

  @override
  State<_HopThoaiSuaKhoaHoc> createState() => _TrangThaiHopThoaiSuaKhoaHoc();
}

class _TrangThaiHopThoaiSuaKhoaHoc extends State<_HopThoaiSuaKhoaHoc> {
  static const _cacBieuTuong = <String, IconData>{
    'book': Icons.menu_book_rounded,
    'math': Icons.calculate_rounded,
    'computer': Icons.laptop_mac_rounded,
    'science': Icons.science_rounded,
    'language': Icons.translate_rounded,
    'safety': Icons.shield_rounded,
  };

  final _bieuMau = GlobalKey<FormState>();
  final _boTaiTepLen = ImageUploadService();
  late final _cacGiaTri = CourseForm.initialValues(widget.initialData);
  late final _tieuDe = TextEditingController(text: _cacGiaTri['title']);
  late final _monHoc = TextEditingController(text: _cacGiaTri['subject']);
  late final _moTa = TextEditingController(text: _cacGiaTri['description']);
  late final _giangVien = TextEditingController(text: _cacGiaTri['instructor']);
  late final _mucTieu = TextEditingController(text: _cacGiaTri['objectives']);
  late final _thoiDiemBatDau = TextEditingController(
    text: _cacGiaTri['startsAt'],
  );
  late final _thoiDiemKetThuc = TextEditingController(
    text: _cacGiaTri['endsAt'],
  );
  late String _cheDoTrienKhai = _cacGiaTri['deploymentMode']!;
  late String _duongDanAnh =
      widget.initialData['coverUrl']?.toString().isNotEmpty == true
      ? widget.initialData['coverUrl'].toString()
      : 'icon:book';
  SelectedUploadImage? _anhDaChon;
  double? _tienDoTaiLen;
  bool _dangMoNangCao = false;
  bool _dangXuLy = false;
  String? _loi;

  bool get _coBaiThi => widget.mode == CourseForm.studyExamLabel;

  String get _chuTieuDe {
    final action = widget.initialData.isEmpty ? 'Tạo' : 'Sửa';
    return '$action khóa học ${_coBaiThi ? 'có kiểm tra' : 'không kiểm tra'}';
  }

  String get _ghiChu => _coBaiThi
      ? 'Khóa học này có nội dung ôn tập và bài kiểm tra. Sau khi lưu, bạn có thể thêm bài kiểm tra trong trang chi tiết khóa học.'
      : 'Khóa học này chỉ dùng để học, không có bài kiểm tra.';

  @override
  void dispose() {
    _tieuDe.dispose();
    _monHoc.dispose();
    _moTa.dispose();
    _giangVien.dispose();
    _mucTieu.dispose();
    _thoiDiemBatDau.dispose();
    _thoiDiemKetThuc.dispose();
    super.dispose();
  }

  Future<void> _chonAnh() async {
    if (_dangXuLy) return;
    setState(() {
      _dangXuLy = true;
      _loi = null;
    });
    try {
      final picked = await _boTaiTepLen.pick();
      if (!mounted || picked == null) return;
      setState(() {
        _anhDaChon = picked;
        _duongDanAnh = '';
      });
    } on ImageUploadException catch (loi) {
      if (mounted) setState(() => _loi = loi.message);
    } catch (_) {
      if (mounted) {
        setState(() => _loi = 'Không thể chọn ảnh. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  Future<void> _luu() async {
    if (_dangXuLy || !_bieuMau.currentState!.validate()) return;
    if (_duongDanAnh.isEmpty && _anhDaChon == null) {
      setState(() => _loi = 'Vui lòng chọn ảnh bìa hoặc biểu tượng khóa học.');
      return;
    }
    setState(() {
      _dangXuLy = true;
      _loi = null;
    });
    try {
      if (_anhDaChon != null) {
        setState(() => _tienDoTaiLen = 0);
        _duongDanAnh = await _boTaiTepLen.upload(
          'courses',
          _anhDaChon!,
          onProgress: (tienDo) {
            if (mounted) setState(() => _tienDoTaiLen = tienDo);
          },
        );
      }
      await widget.onSave({
        'title': _tieuDe.text.trim(),
        'subject': _monHoc.text.trim(),
        'description': _moTa.text.trim(),
        'instructor': _giangVien.text.trim(),
        'objectives': _mucTieu.text.trim(),
        'deploymentMode': _cheDoTrienKhai,
        'startsAt': _thoiDiemBatDau.text.trim(),
        'endsAt': _thoiDiemKetThuc.text.trim(),
        'imageUrl': _duongDanAnh,
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ImageUploadException catch (loi) {
      if (mounted) {
        setState(() {
          _loi = loi.message;
          _tienDoTaiLen = null;
        });
      }
    } on ArgumentError catch (loi) {
      if (mounted) {
        setState(() {
          _loi = loi.message?.toString() ?? 'Dữ liệu chưa hợp lệ.';
          _tienDoTaiLen = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loi = 'Không thể lưu khóa học. Kiểm tra kết nối rồi thử lại.';
          _tienDoTaiLen = null;
        });
      }
    } finally {
      if (mounted && _loi != null) setState(() => _dangXuLy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final narrow = screen.width < 660;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? 16 : 30,
        vertical: narrow ? 16 : 38,
      ),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 740,
          maxHeight: screen.height - (narrow ? 32 : 76),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 22, 18, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _chuTieuDe,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: _dangXuLy
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close, size: 29),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 0, 34, 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _ghiChu,
                  style: const TextStyle(
                    color: Color(0xFF60779A),
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: AdminUi.border),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(34, 18, 34, 12),
                child: Form(
                  key: _bieuMau,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _KhungAnhBiaKhoaHoc(
                        icon: _duongDanAnh.startsWith('icon:')
                            ? _cacBieuTuong[_duongDanAnh.substring(5)] ??
                                  Icons.menu_book_rounded
                            : null,
                        imageUrl: _duongDanAnh,
                        selectedImage: _anhDaChon,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: _dangXuLy ? null : _chonAnh,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(
                            _dangXuLy && _tienDoTaiLen == null
                                ? 'Đang xử lý…'
                                : _anhDaChon == null &&
                                      _duongDanAnh.startsWith('icon:')
                                ? 'Chọn ảnh từ thiết bị (tối đa 20 MB)'
                                : 'Đổi ảnh từ thiết bị (tối đa 20 MB)',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.red,
                            side: const BorderSide(color: AppTheme.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      if (_anhDaChon != null) ...[
                        const SizedBox(height: 7),
                        Text(
                          _anhDaChon!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF60779A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      const _NhanKhoaHoc('Tên khóa học'),
                      const SizedBox(height: 7),
                      _TruongKhoaHoc(
                        controller: _tieuDe,
                        hint: 'Nhập tên khóa học',
                        validator: (giaTri) =>
                            giaTri == null || giaTri.trim().isEmpty
                            ? 'Vui lòng nhập tên khóa học.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const _NhanKhoaHoc('Môn học'),
                      const SizedBox(height: 7),
                      _TruongKhoaHoc(
                        controller: _monHoc,
                        hint: 'Chọn môn học',
                        suffix: const Icon(Icons.keyboard_arrow_down_rounded),
                        validator: (giaTri) =>
                            giaTri == null || giaTri.trim().isEmpty
                            ? 'Vui lòng nhập môn học.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const _NhanKhoaHoc('Chọn biểu tượng khóa học'),
                      const SizedBox(height: 10),
                      _BoChonBieuTuongKhoaHoc(
                        icons: _cacBieuTuong,
                        selected: _duongDanAnh.startsWith('icon:')
                            ? _duongDanAnh.substring(5)
                            : null,
                        enabled: !_dangXuLy,
                        onSelected: (khoa) => setState(() {
                          _duongDanAnh = 'icon:$khoa';
                          _anhDaChon = null;
                          _loi = null;
                        }),
                      ),
                      const SizedBox(height: 10),
                      _CaiDatKhoaHocNangCao(
                        open: _dangMoNangCao,
                        onToggle: () =>
                            setState(() => _dangMoNangCao = !_dangMoNangCao),
                        description: _moTa,
                        instructor: _giangVien,
                        objectives: _mucTieu,
                        deploymentMode: _cheDoTrienKhai,
                        startsAt: _thoiDiemBatDau,
                        endsAt: _thoiDiemKetThuc,
                        enabled: !_dangXuLy,
                        futureOnly: widget.initialData.isEmpty,
                        onDeploymentChanged: (giaTri) =>
                            setState(() => _cheDoTrienKhai = giaTri),
                      ),
                      if (_tienDoTaiLen != null) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(value: _tienDoTaiLen),
                        const SizedBox(height: 5),
                        Text(
                          'Đang tải ảnh: ${(_tienDoTaiLen! * 100).round()}%',
                          style: const TextStyle(
                            color: Color(0xFF60779A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (_loi != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _loi!,
                          style: const TextStyle(
                            color: AppTheme.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: AdminUi.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 12, 34, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _dangXuLy
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.red,
                      minimumSize: const Size(96, 48),
                      side: const BorderSide(color: AppTheme.red),
                    ),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 14),
                  FilledButton(
                    onPressed: _dangXuLy ? null : _luu,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.red,
                      minimumSize: const Size(98, 48),
                    ),
                    child: Text(_dangXuLy ? 'Đang lưu…' : 'Lưu'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KhungAnhBiaKhoaHoc extends StatelessWidget {
  const _KhungAnhBiaKhoaHoc({
    required this.icon,
    required this.imageUrl,
    required this.selectedImage,
  });

  final IconData? icon;
  final String imageUrl;
  final SelectedUploadImage? selectedImage;

  @override
  Widget build(BuildContext context) => Container(
    height: 190,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xFFF9FBFF),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFC8D9F1)),
    ),
    child: selectedImage != null
        ? Image.memory(
            selectedImage!.bytes,
            width: double.infinity,
            fit: BoxFit.cover,
          )
        : icon != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppTheme.red, size: 62),
                const SizedBox(height: 9),
                const Text(
                  'Ảnh bìa khóa học',
                  style: TextStyle(color: Color(0xFF365078), fontSize: 16),
                ),
              ],
            ),
          )
        : Image.network(
            imageUrl,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: AppTheme.red,
                size: 52,
              ),
            ),
          ),
  );
}

class _NhanKhoaHoc extends StatelessWidget {
  const _NhanKhoaHoc(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: AppTheme.navy, fontWeight: FontWeight.w700),
  );
}

class _TruongKhoaHoc extends StatelessWidget {
  const _TruongKhoaHoc({
    required this.controller,
    required this.hint,
    this.suffix,
    this.validator,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    minLines: minLines,
    maxLines: maxLines,
    validator: validator,
    decoration: InputDecoration(
      hintText: hint,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminUi.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminUi.border),
      ),
    ),
  );
}

class _BoChonBieuTuongKhoaHoc extends StatelessWidget {
  const _BoChonBieuTuongKhoaHoc({
    required this.icons,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final Map<String, IconData> icons;
  final String? selected;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 18,
    runSpacing: 12,
    children: [
      for (final capDuLieu in icons.entries)
        InkWell(
          onTap: enabled ? () => onSelected(capDuLieu.key) : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 78,
            height: 68,
            decoration: BoxDecoration(
              color: selected == capDuLieu.key
                  ? const Color(0xFFFFF1F1)
                  : const Color(0xFFF8FAFD),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected == capDuLieu.key
                    ? AppTheme.red
                    : AdminUi.border,
                width: selected == capDuLieu.key ? 2 : 1,
              ),
            ),
            child: Icon(capDuLieu.value, color: AppTheme.red, size: 33),
          ),
        ),
    ],
  );
}

class _CaiDatKhoaHocNangCao extends StatelessWidget {
  const _CaiDatKhoaHocNangCao({
    required this.open,
    required this.onToggle,
    required this.description,
    required this.instructor,
    required this.objectives,
    required this.deploymentMode,
    required this.startsAt,
    required this.endsAt,
    required this.enabled,
    required this.futureOnly,
    required this.onDeploymentChanged,
  });

  final bool open;
  final VoidCallback onToggle;
  final TextEditingController description;
  final TextEditingController instructor;
  final TextEditingController objectives;
  final String deploymentMode;
  final TextEditingController startsAt;
  final TextEditingController endsAt;
  final bool enabled;
  final bool futureOnly;
  final ValueChanged<String> onDeploymentChanged;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xFFF8FAFD),
    ),
    child: Column(
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppTheme.navy, size: 19),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Thiết lập nâng cao',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(open ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                const _NhanKhoaHoc('Mô tả'),
                const SizedBox(height: 6),
                _TruongKhoaHoc(
                  controller: description,
                  hint: 'Nhập mô tả khóa học',
                  minLines: 2,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                const _NhanKhoaHoc('Giảng viên'),
                const SizedBox(height: 6),
                _TruongKhoaHoc(controller: instructor, hint: 'Nhập giảng viên'),
                const SizedBox(height: 12),
                const _NhanKhoaHoc('Mục tiêu học tập'),
                const SizedBox(height: 6),
                _TruongKhoaHoc(
                  controller: objectives,
                  hint: 'Mỗi dòng một mục tiêu',
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: deploymentMode,
                  decoration: const InputDecoration(
                    labelText: 'Cách triển khai',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: CourseForm.manualLabel,
                      child: Text(CourseForm.manualLabel),
                    ),
                    DropdownMenuItem(
                      value: CourseForm.scheduledLabel,
                      child: Text(CourseForm.scheduledLabel),
                    ),
                  ],
                  onChanged: (giaTri) {
                    if (giaTri != null) onDeploymentChanged(giaTri);
                  },
                ),
                if (deploymentMode == CourseForm.scheduledLabel) ...[
                  const SizedBox(height: 12),
                  LearningDateTimeField(
                    controller: startsAt,
                    label: 'Thời gian bắt đầu',
                    enabled: enabled,
                    mustBeFuture: futureOnly,
                  ),
                  const SizedBox(height: 12),
                  LearningDateTimeField(
                    controller: endsAt,
                    label: 'Thời gian kết thúc',
                    enabled: enabled,
                    mustBeFuture: futureOnly,
                  ),
                ],
              ],
            ),
          ),
      ],
    ),
  );
}
