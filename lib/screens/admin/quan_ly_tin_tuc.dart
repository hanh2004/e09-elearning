// WEB ADMIN: Tạo, sửa, đăng/ẩn và xóa tin tức; form chi tiết nằm ở forms/truong_tin_tuc.dart.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../models/dinh_danh_tai_khoan.dart';
import '../../models/bieu_mau_tin_tuc.dart';
import '../../models/bai_viet_tin_tuc.dart';
import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../services/thong_bao_loi_ung_dung.dart';
import '../../services/tep/dich_vu_tai_anh.dart';
import '../../widgets/giao_dien_quan_tri.dart';
import '../../widgets/anh_bia_khoa_hoc.dart';
import '../../widgets/tien_ich_giao_dien_hoc_tap.dart';
import 'khung_giao_dien_quan_tri.dart';

part 'forms/truong_tin_tuc.dart';

class AdminNewsScreen extends StatefulWidget {
  const AdminNewsScreen({super.key, this.service});
  final LearningService? service;

  @override
  State<AdminNewsScreen> createState() => _TrangThaiTinTucQuanTri();
}

class _TrangThaiTinTucQuanTri extends State<AdminNewsScreen> {
  late final service = widget.service ?? LearningService();
  late final stream = service.db
      .collection('news')
      .orderBy('updatedAt', descending: true)
      .snapshots();
  final _dangXoaTinTuc = <String>{};
  final _dangXacNhanXoaTinTuc = <String>{};

  Future<void> edit({
    QueryDocumentSnapshot<Map<String, dynamic>>? banGhi,
    List<String> categoryOptions = const [],
    List<String> enabledCategories = const [],
  }) async {
    final taiKhoan = AccountSession.current;
    if (taiKhoan?.isRoot != true) return;
    final duLieu = banGhi?.data() ?? <String, dynamic>{};
    final existingCategory = duLieu['category']?.toString() ?? '';
    final availableCategories = <String>{
      ...NewsArticle.categories,
      ...categoryOptions,
      if (existingCategory.isNotEmpty) existingCategory,
    }.toList(growable: false);
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _HopThoaiSuaTinTuc(
        title: banGhi == null ? 'Thêm tin tức' : 'Sửa tin tức',
        initialData: duLieu,
        categoryOptions: availableCategories,
        enabledCategories: enabledCategories,
        initialCategory: existingCategory.isEmpty
            ? NewsArticle.categories.first
            : existingCategory,
        onSave: (cacGiaTri) => service.saveContent(
          taiKhoan!.id,
          banGhi?.reference ?? service.db.collection('news').doc(),
          NewsForm.toFirestore(cacGiaTri, knownCategories: availableCategories),
        ),
      ),
    );
  }

  Future<void> delete(
    QueryDocumentSnapshot<Map<String, dynamic>> banGhi,
  ) async {
    if (AccountSession.current?.isRoot != true ||
        !_dangXacNhanXoaTinTuc.add(banGhi.id)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa vĩnh viễn tin tức'),
        content: Text(
          'Xóa vĩnh viễn tin tức "${banGhi.data()['title'] ?? ''}"? '
          'Không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );
    _dangXacNhanXoaTinTuc.remove(banGhi.id);
    if (confirmed != true || !mounted || !_dangXoaTinTuc.add(banGhi.id)) {
      return;
    }
    setState(() {});
    try {
      await banGhi.reference.delete();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã xóa tin tức.')));
      }
    } catch (loi) {
      debugPrint('Xóa tin tức ${banGhi.id} thất bại: $loi');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppErrorMessage.from(
                loi,
                feature: 'Xóa tin tức',
                fallbackAction: 'Hãy tải lại danh sách rồi thử lại.',
              ),
            ),
          ),
        );
      }
    } finally {
      _dangXoaTinTuc.remove(banGhi.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => AdminResponsiveShell(
    selectedIndex: 0,
    activeExtra: 'Tin tức',
    onSelected: (viTri) => pushAdminPrimary(context, viTri),
    child: Scaffold(
      appBar: AdminUi.appBar('Quản lý tin tức'),
      body: LearningList(
        stream: stream,
        errorTitle: 'Tải danh sách tin tức',
        builder: (cacBanGhi) {
          final articles = cacBanGhi.map(
            (banGhi) => NewsArticle(banGhi.id, banGhi.data()),
          );
          final categoryOptions = NewsArticle.categoriesFor(articles);
          final enabledCategories = NewsArticle.enabledCategoriesFor(articles);
          final published = cacBanGhi
              .where((banGhi) => banGhi.data()['published'] == true)
              .length;
          final drafts = cacBanGhi.length - published;
          return Column(
            children: [
              AdminPageHeading(
                title: 'Danh sách tin tức',
                action: AccountSession.current?.isRoot == true
                    ? FilledButton.icon(
                        onPressed: () =>
                            edit(
                              categoryOptions: categoryOptions,
                              enabledCategories: enabledCategories,
                            ),
                        icon: const Icon(Icons.add),
                        label: const Text('Thêm tin tức'),
                      )
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 900) {
                      return const SizedBox.shrink();
                    }
                    final cards = [
                      AdminMetricCard(
                        value: '${cacBanGhi.length}',
                        label: 'bài viết',
                        icon: Icons.article_outlined,
                        color: Colors.blue,
                      ),
                      AdminMetricCard(
                        value: '$published',
                        label: 'đã đăng',
                        icon: Icons.check_circle_outline,
                        color: Colors.green,
                      ),
                      AdminMetricCard(
                        value: '$drafts',
                        label: 'bản nháp',
                        icon: Icons.description_outlined,
                        color: AppTheme.red,
                      ),
                    ];
                    return Row(
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(width: 14),
                          Expanded(child: cards[i]),
                        ],
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: cacBanGhi.isEmpty
                    ? Center(
                        child: Text(
                          'Chưa có tin tức. Thêm tin mới để gửi tới học viên.',
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                        children: [
                          for (final banGhi in cacBanGhi)
                            AdminCard(
                              key: ValueKey('news:${banGhi.id}'),
                              child: _DongTinTuc(
                                doc: banGhi,
                                onEdit: (banGhi) => edit(
                                  banGhi: banGhi,
                                  categoryOptions: categoryOptions,
                                  enabledCategories: enabledCategories,
                                ),
                                onDelete: delete,
                                deleting: _dangXoaTinTuc.contains(banGhi.id),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _DongTinTuc extends StatelessWidget {
  const _DongTinTuc({
    required this.doc,
    required this.onEdit,
    required this.onDelete,
    required this.deleting,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>>)
  onEdit;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>>)
  onDelete;
  final bool deleting;

  @override
  Widget build(BuildContext context) {
    final duLieu = doc.data();
    final laQuanTriTong = AccountSession.current?.isRoot == true;
    final thongTinTin = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          duLieu['title'] ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '${duLieu['category'] ?? NewsArticle.categories.first} • ${duLieu['summary'] ?? ''}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF60779A)),
        ),
      ],
    );
    final nutThaoTac = <Widget>[
      if (laQuanTriTong) ...[
        IconButton(
          tooltip: 'Sửa tin tức',
          onPressed: () => onEdit(doc),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Xóa tin tức',
          onPressed: deleting ? null : () => onDelete(doc),
          icon: deleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline),
        ),
      ],
    ];
    final trangThai = _TrangThaiTinTuc(published: duLieu['published'] == true);
    return InkWell(
      onTap: laQuanTriTong ? () => onEdit(doc) : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final noiDung = constraints.maxWidth < 560
              ? Column(
                  children: [
                    Row(
                      children: [
                        CourseCover(
                          url: duLieu['coverUrl'] ?? '',
                          width: 64,
                          height: 56,
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: thongTinTin),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(children: [trangThai, const Spacer(), ...nutThaoTac]),
                  ],
                )
              : Row(
                  children: [
                    CourseCover(
                      url: duLieu['coverUrl'] ?? '',
                      width: 64,
                      height: 56,
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: thongTinTin),
                    const SizedBox(width: 12),
                    trangThai,
                    ...nutThaoTac,
                  ],
                );
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: noiDung,
          );
        },
      ),
    );
  }
}

class _TrangThaiTinTuc extends StatelessWidget {
  const _TrangThaiTinTuc({required this.published});
  final bool published;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: published ? const Color(0xFFE3F6E9) : const Color(0xFFFFE8E8),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      published ? 'Đã đăng' : NewsForm.draft,
      style: TextStyle(
        color: published ? const Color(0xFF087F3F) : AppTheme.red,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Biểu mẫu tin tức dành riêng cho Web Admin. Bố cục giữ các thao tác đang có
/// nhưng trình bày theo modal của bộ thiết kế quản trị.
class _HopThoaiSuaTinTuc extends StatefulWidget {
  const _HopThoaiSuaTinTuc({
    required this.title,
    required this.initialData,
    required this.categoryOptions,
    required this.enabledCategories,
    required this.initialCategory,
    required this.onSave,
  });

  final String title;
  final Map<String, dynamic> initialData;
  final List<String> categoryOptions;
  final List<String> enabledCategories;
  final String initialCategory;
  final Future<void> Function(Map<String, String>) onSave;

  @override
  State<_HopThoaiSuaTinTuc> createState() => _TrangThaiHopThoaiSuaTinTuc();
}

class _TrangThaiHopThoaiSuaTinTuc extends State<_HopThoaiSuaTinTuc> {
  final _bieuMau = GlobalKey<FormState>();
  final _boTaiTepLen = ImageUploadService();
  late final _tieuDe = TextEditingController(
    text: widget.initialData['title']?.toString() ?? '',
  );
  late final _tomTat = TextEditingController(
    text: widget.initialData['summary']?.toString() ?? '',
  );
  late final _noiDung = TextEditingController(
    text: widget.initialData['content']?.toString() ?? '',
  );
  late final _loaiTinTuNhap = TextEditingController();
  late String _loaiTin = widget.initialCategory;
  late bool _hienLoaiTinTrenThanh =
      widget.initialData['showCategoryTab'] as bool? ??
      NewsArticle.categories.contains(widget.initialCategory);
  late String _duongDanAnh = widget.initialData['coverUrl']?.toString() ?? '';
  SelectedUploadImage? _anhDaChon;
  double? _tienDoTaiLen;
  late bool _noiBat = widget.initialData['featured'] == true;
  late bool _luuBanNhap =
      widget.initialData.isNotEmpty && widget.initialData['published'] != true;
  bool _dangXuLy = false;
  String? _loi;

  @override
  void dispose() {
    _tieuDe.dispose();
    _tomTat.dispose();
    _noiDung.dispose();
    _loaiTinTuNhap.dispose();
    super.dispose();
  }

  Future<void> _chonAnh() async {
    if (_dangXuLy) return;
    setState(() {
      _dangXuLy = true;
      _loi = null;
    });
    try {
      final anh = await _boTaiTepLen.pick();
      if (!mounted || anh == null) return;
      setState(() {
        _anhDaChon = anh;
        _duongDanAnh = '';
      });
    } on ImageUploadException catch (loi) {
      if (mounted) setState(() => _loi = loi.message);
    } catch (loi) {
      if (mounted) {
        setState(
          () => _loi = AppErrorMessage.from(
            loi,
            feature: 'Chọn ảnh tin tức',
            fallbackAction:
                'Kiểm tra quyền truy cập ảnh và kết nối máy chủ rồi thử lại.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  Future<void> _luu() async {
    if (_dangXuLy || !_bieuMau.currentState!.validate()) return;
    final loaiTinDaChon = _loaiTin == NewsForm.customCategorySelection
        ? _loaiTinTuNhap.text.trim()
        : _loaiTin;
    if (_hienLoaiTinTrenThanh &&
        !widget.enabledCategories.contains(loaiTinDaChon) &&
        widget.enabledCategories.length >= 3) {
      setState(
        () => _loi = 'Thanh nhanh đã đủ 3 loại. Loại này vẫn dùng được trong bộ lọc.',
      );
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
          'news',
          _anhDaChon!,
          onProgress: (tienDo) {
            if (mounted) setState(() => _tienDoTaiLen = tienDo);
          },
        );
      }
      await widget.onSave({
        'title': _tieuDe.text.trim(),
        'summary': _tomTat.text.trim(),
        'content': _noiDung.text.trim(),
        'category': _loaiTin,
        'categoryCustom': _loaiTinTuNhap.text.trim(),
        'showCategoryTab': _hienLoaiTinTrenThanh ? 'Có' : 'Không',
        'featured': _noiBat ? 'Có' : 'Không',
        'status': _luuBanNhap ? NewsForm.draft : NewsForm.published,
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
    } catch (loi) {
      if (mounted) {
        setState(() {
          _loi = AppErrorMessage.from(
            loi,
            feature: 'Lưu tin tức',
            fallbackAction: 'Kiểm tra quyền quản trị, nội dung và kết nối máy chủ rồi thử lại.',
          );
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
    final narrow = screen.width < 620;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? 16 : 28,
        vertical: narrow ? 16 : 34,
      ),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 670,
          maxHeight: screen.height - (narrow ? 32 : 68),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 20, 18, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
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
            const Divider(height: 1, color: AdminUi.border),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 18, 32, 12),
                child: Form(
                  key: _bieuMau,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Ảnh tiêu đề của tin đã đăng sẽ tự động chạy trên banner trang chủ (tối đa 5 tin mới nhất).\nTin nổi bật được ưu tiên trong danh sách Tin tức. Bản nháp chỉ hiển thị trong quản trị.',
                        style: TextStyle(
                          color: Color(0xFF60779A),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _NhanTrinhSua('Ảnh tiêu đề'),
                      const SizedBox(height: 7),
                      _VungChonAnhBia(
                        imageUrl: _duongDanAnh,
                        selectedImage: _anhDaChon,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 40,
                        child: OutlinedButton.icon(
                          onPressed: _dangXuLy ? null : _chonAnh,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(
                            _dangXuLy && _tienDoTaiLen == null
                                ? 'Đang xử lý…'
                                : _anhDaChon == null && _duongDanAnh.isEmpty
                            ? 'Chọn ảnh từ thiết bị'
                            : 'Đổi ảnh từ thiết bị',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.red,
                            side: const BorderSide(color: Color(0xFFB77878)),
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
                      const SizedBox(height: 18),
                      const _NhanTrinhSua('Tiêu đề tin tức'),
                      const SizedBox(height: 7),
                      _TruongNhapTinTuc(
                        controller: _tieuDe,
                        hint: 'Nhập tiêu đề tin tức...',
                        maxLength: 200,
                        validator: (vanBan) =>
                            vanBan == null || vanBan.trim().isEmpty
                            ? 'Vui lòng nhập tiêu đề tin tức.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _loaiTin,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Loại tin tức',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final category in widget.categoryOptions)
                            DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          const DropdownMenuItem(
                            value: NewsForm.customCategorySelection,
                            child: Text('＋ Thêm loại mới'),
                          ),
                        ],
                        validator: (value) => value == null || value.isEmpty
                            ? 'Vui lòng chọn loại tin tức.'
                            : null,
                        onChanged: _dangXuLy
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() {
                                    _loaiTin = value;
                                    _hienLoaiTinTrenThanh = value !=
                                            NewsForm.customCategorySelection &&
                                        widget.enabledCategories.contains(value);
                                  });
                                }
                              },
                      ),
                      if (_loaiTin == NewsForm.customCategorySelection) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _loaiTinTuNhap,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Tên loại mới',
                            hintText: 'Ví dụ: Hoạt động đơn vị',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (_loaiTin != NewsForm.customCategorySelection) {
                              return null;
                            }
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui lòng nhập tên loại tin.';
                            }
                            return null;
                          },
                        ),
                      ],
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Hiện loại này trên thanh nhanh'),
                        subtitle: const Text(
                          'Tối đa 3 loại bên cạnh “Tất cả”. Loại khác vẫn có trong bộ lọc.',
                        ),
                        value: _hienLoaiTinTrenThanh,
                        onChanged: _dangXuLy
                            ? null
                            : (value) => setState(() {
                                _hienLoaiTinTrenThanh = value;
                                _loi = null;
                              }),
                      ),
                      const SizedBox(height: 16),
                      const _NhanTrinhSua('Tóm tắt'),
                      const SizedBox(height: 7),
                      _TruongNhapTinTuc(
                        controller: _tomTat,
                        hint: 'Nhập tóm tắt tin tức...',
                        minLines: 3,
                        maxLines: 3,
                        maxLength: 500,
                      ),
                      const SizedBox(height: 16),
                      const _NhanTrinhSua('Nội dung'),
                      const SizedBox(height: 7),
                      _TruongNhapTinTuc(
                        controller: _noiDung,
                        hint: 'Nhập nội dung tin tức...',
                        minLines: 4,
                        maxLines: 7,
                        maxLength: 50000,
                        displayLimit: 5000,
                        validator: (vanBan) =>
                            vanBan == null || vanBan.trim().isEmpty
                            ? 'Vui lòng nhập nội dung tin tức.'
                            : null,
                      ),
                      if (_tienDoTaiLen != null) ...[
                        const SizedBox(height: 10),
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
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 26,
                        runSpacing: 4,
                        children: [
                          _CongTacCaiDat(
                            label: 'Tin nổi bật',
                            value: _noiBat,
                            onChanged: _dangXuLy
                                ? null
                                : (giaTri) => setState(() => _noiBat = giaTri),
                            hint: 'Ưu tiên hiển thị trong danh sách tin tức.',
                          ),
                          _CongTacCaiDat(
                            label: 'Lưu bản nháp',
                            value: _luuBanNhap,
                            onChanged: _dangXuLy
                                ? null
                                : (giaTri) =>
                                      setState(() => _luuBanNhap = giaTri),
                            hint: 'Tin nháp chỉ hiển thị trong trang quản trị.',
                          ),
                        ],
                      ),
                      if (_loi != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _loi!,
                          style: const TextStyle(
                            color: Color(0xFFB51F24),
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
              padding: const EdgeInsets.fromLTRB(32, 12, 32, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _dangXuLy
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.navy,
                      minimumSize: const Size(78, 46),
                      side: const BorderSide(color: Color(0xFF9DABC1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _dangXuLy ? null : _luu,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.red,
                      minimumSize: const Size(78, 46),
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
