import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../models/news_article.dart';
import '../../services/nghiep_vu/learning_service.dart';
import '../../services/nghiep_vu/news_service.dart';
import '../../widgets/news_widgets.dart';
import 'news_detail_screen.dart';
import 'news_screen.dart';

/// Khối xem nhanh tin tức trên trang chủ.
class UserNews extends StatefulWidget {
  const UserNews({super.key, required this.service, this.uid, this.onViewAll});
  final LearningService service;
  final String? uid;
  final VoidCallback? onViewAll;
  @override
  State<UserNews> createState() => _TrangThaiTinTucHocVien();
}

class _TrangThaiTinTucHocVien extends State<UserNews> {
  late final news = NewsService(widget.service.db);
  late final articles = news.published();
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
      NewsCategories(
        selected: category,
        onSelected: (giaTri) => setState(() => category = giaTri),
      ),
      const Divider(height: 1),
      StreamBuilder<List<NewsArticle>>(
        stream: articles,
        builder: (context, duLieuNhan) {
          if (duLieuNhan.hasError) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Không tải được tin tức. Kiểm tra kết nối.'),
            );
          }
          if (!duLieuNhan.hasData) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            );
          }
          final visible = duLieuNhan.data!
              .where((a) => category == 'Tất cả' || a.category == category)
              .take(3)
              .toList();
          if (visible.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Chưa có tin tức mới.'),
            );
          }
          return Column(
            children: [
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
