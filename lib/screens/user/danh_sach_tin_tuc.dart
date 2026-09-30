// APP HỌC VIÊN: Danh sách tin tức, tìm tin và mở màn hình chi tiết.

import 'package:flutter/material.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../models/bai_viet_tin_tuc.dart';
import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../services/nghiep_vu/dich_vu_tin_tuc.dart';
import '../../widgets/dau_trang_hoc_vien.dart';
import '../../widgets/tien_ich_tin_tuc.dart';
import 'chi_tiet_tin_tuc.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key, required this.service});
  final LearningService service;
  @override
  State<NewsScreen> createState() => _TrangThaiTinTuc();
}

class _TrangThaiTinTuc extends State<NewsScreen> {
  late final news = NewsService(widget.service.db);
  late final articles = news.published();
  final search = TextEditingController();
  String category = 'Tất cả';
  int days = 0;
  bool oldest = false;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> filter() async {
    final daChon = await showModalBottomSheet<(int, bool)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        var selectedDays = days;
        var selectedOldest = oldest;
        return StatefulBuilder(
          builder: (context, setSheetState) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Lọc tin tức',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<int>(
                  initialValue: selectedDays,
                  decoration: const InputDecoration(
                    labelText: 'Thời gian đăng',
                  ),
                  items: [
                    for (final capDuLieu in const {
                      0: 'Mọi thời gian',
                      1: '24 giờ qua',
                      7: '7 ngày qua',
                      30: '30 ngày qua',
                    }.entries)
                      DropdownMenuItem(
                        value: capDuLieu.key,
                        child: Text(capDuLieu.value),
                      ),
                  ],
                  onChanged: (giaTri) =>
                      setSheetState(() => selectedDays = giaTri!),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tin cũ trước'),
                  value: selectedOldest,
                  onChanged: (giaTri) =>
                      setSheetState(() => selectedOldest = giaTri),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, (selectedDays, selectedOldest)),
                  child: const Text('Áp dụng'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, (0, false)),
                  child: const Text('Xóa bộ lọc'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (daChon != null) {
      setState(() {
        days = daChon.$1;
        oldest = daChon.$2;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: LearnerHeader(
      title: const Text('Tin tức'),
      backgroundColor: AppTheme.red,
    ),
    body: Column(
      children: [
        NewsCategories(
          selected: category,
          onSelected: (giaTri) => setState(() => category = giaTri),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm tin tức',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: const Color(0xFFF4F3F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(32),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Xóa tìm kiếm',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(search.clear),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Lọc tin tức',
                onPressed: filter,
                icon: Icon(
                  days > 0 || oldest
                      ? Icons.filter_alt
                      : Icons.filter_alt_outlined,
                ),
              ),
            ],
          ),
        ),
        if (days > 0 || oldest)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${days > 0 ? '$days ngày gần đây' : 'Mọi thời gian'} • ${oldest ? 'Tin cũ trước' : 'Tin mới trước'}',
                style: const TextStyle(color: AppTheme.red, fontSize: 12),
              ),
            ),
          ),
        Expanded(
          child: StreamBuilder<List<NewsArticle>>(
            stream: articles,
            builder: (context, duLieuNhan) {
              if (duLieuNhan.hasError) {
                return const Center(
                  child: Text('Không tải được tin tức. Kiểm tra kết nối.'),
                );
              }
              if (!duLieuNhan.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _danhSach(duLieuNhan.data!);
            },
          ),
        ),
      ],
    ),
  );

  Widget _danhSach(List<NewsArticle> all) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    var daLoc = all
        .where(
          (baiViet) =>
              (category == 'Tất cả' || baiViet.category == category) &&
              baiViet.matches(search.text) &&
              (days == 0 ||
                  (baiViet.publishedAt != null &&
                      !baiViet.publishedAt!.isBefore(cutoff))),
        )
        .toList();
    if (oldest) daLoc = daLoc.reversed.toList();
    if (daLoc.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Không có tin tức phù hợp.'),
        ),
      );
    }
    final featured = search.text.isEmpty && days == 0 && !oldest
        ? daLoc.firstWhere((a) => a.featured, orElse: () => daLoc.first)
        : null;
    final ordered = [?featured, ...daLoc.where((a) => a.id != featured?.id)];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: ordered.length + 1,
      separatorBuilder: (_, viTri) =>
          viTri == 0 ? const SizedBox(height: 4) : const Divider(height: 1),
      itemBuilder: (context, viTri) {
        if (viTri == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              search.text.isEmpty ? 'Tin mới' : 'Kết quả (${ordered.length})',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          );
        }
        final baiViet = ordered[viTri - 1];
        return NewsTile(
          article: baiViet,
          large: baiViet.id == featured?.id,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => NewsDetailScreen(id: baiViet.id, service: news),
            ),
          ),
        );
      },
    );
  }
}
