// APP HỌC VIÊN: Khối tin tức xem nhanh trên trang chủ và nút mở danh sách tin.

import 'package:flutter/material.dart';

import '../../app/chu_de_ung_dung.dart';
import '../../models/bai_viet_tin_tuc.dart';
import '../../services/nghiep_vu/dich_vu_hoc_tap.dart';
import '../../services/nghiep_vu/dich_vu_tin_tuc.dart';
import '../../widgets/tien_ich_tin_tuc.dart';
import '../../widgets/thong_bao_loi.dart';
import 'chi_tiet_tin_tuc.dart';
import 'danh_sach_tin_tuc.dart';

/// Khối xem nhanh tin tức trên trang chủ.
class UserNews extends StatefulWidget {
  const UserNews({super.key, required this.service, this.onViewAll});
  final LearningService service;
  final VoidCallback? onViewAll;
  @override
  State<UserNews> createState() => _TrangThaiTinTucHocVien();
}

class _TrangThaiTinTucHocVien extends State<UserNews> {
  late final news = NewsService(widget.service.db);
  String category = 'Tất cả';
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Tin tức',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          TextButton.icon(
            onPressed:
                widget.onViewAll ??
                () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => NewsScreen(service: widget.service),
                  ),
                ),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Xem tất cả'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.red),
          ),
        ],
      ),
      ReloadableStreamBuilder<List<NewsArticle>>(
        streamFactory: news.published,
        feature: 'Tải tin tức trang chủ',
        builder: (context, duLieuNhan) {
          if (!duLieuNhan.hasData) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            );
          }
          final all = duLieuNhan.data!;
          final visible = all
              .where((a) => category == 'Tất cả' || a.category == category)
              .take(3)
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NewsCategories(
                selected: category,
                categories: NewsArticle.quickCategoriesFor(all),
                onSelected: (giaTri) => setState(() => category = giaTri),
              ),
              const Divider(height: 1),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Chưa có tin tức mới.'),
                )
              else
                for (final baiViet in visible) ...[
                  NewsTile(
                    article: baiViet,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            NewsDetailScreen(id: baiViet.id, service: news),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                ],
            ],
          );
        },
      ),
    ],
  );
}
