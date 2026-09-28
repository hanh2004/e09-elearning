import 'package:flutter/material.dart';

import '../app/chu_de_ung_dung.dart';
import '../models/bai_viet_tin_tuc.dart';
import 'anh_bia_khoa_hoc.dart';

class NewsCategories extends StatelessWidget {
  const NewsCategories({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final category in ['Tất cả', ...NewsArticle.categories])
          InkWell(
            onTap: () => onSelected(category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    width: 3,
                    color: selected == category
                        ? AppTheme.red
                        : Colors.transparent,
                  ),
                ),
              ),
              child: Text(
                category,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected == category ? AppTheme.red : AppTheme.navy,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class NewsTile extends StatelessWidget {
  const NewsTile({
    super.key,
    required this.article,
    required this.onTap,
    this.large = false,
  });
  final NewsArticle article;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final tieuDe = Text(
      article.title,
      maxLines: large ? 3 : 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: large ? 19 : 15,
        height: 1.4,
        fontWeight: large ? FontWeight.w800 : FontWeight.w600,
      ),
    );
    final ngay = Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Icon(
          Icons.calendar_today_outlined,
          size: 14,
          color: Colors.blueGrey,
        ),
        Text(
          article.timeLabel(),
          style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
        ),
      ],
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: large
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CourseCover(
                      url: article.coverUrl,
                      width: double.infinity,
                    ),
                  ),
                  const SizedBox(height: 12),
                  tieuDe,
                  if (article.summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      article.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF596271),
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ngay,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CourseCover(
                    url: article.coverUrl,
                    width: MediaQuery.sizeOf(context).width < 360 ? 86 : 116,
                    height: 86,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [tieuDe, const SizedBox(height: 12), ngay],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
