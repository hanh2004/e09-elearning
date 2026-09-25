import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/news_article.dart';

class NewsService {
  const NewsService(this.db);
  final FirebaseFirestore db;

  Stream<List<NewsArticle>> published() => db
      .collection('news')
      .where('published', isEqualTo: true)
      .snapshots()
      .map((duLieuNhan) {
        final cacBaiViet = duLieuNhan.docs
            .map((banGhi) => NewsArticle(banGhi.id, banGhi.data()))
            .toList();
        cacBaiViet.sort((a, b) {
          final comparison = (b.publishedAt ?? DateTime(2000)).compareTo(
            a.publishedAt ?? DateTime(2000),
          );
          return comparison == 0 ? a.id.compareTo(b.id) : comparison;
        });
        return cacBaiViet;
      });
}
