import 'news_article.dart';

class NewsForm {
  static const draft = 'Bản nháp';
  static const published = 'Đăng tin';

  static Map<String, dynamic> toFirestore(Map<String, String> cacGiaTri) {
    final tieuDe = (cacGiaTri['title'] ?? '').trim();
    final noiDung = (cacGiaTri['content'] ?? '').trim();
    final summary = (cacGiaTri['summary'] ?? '').trim();
    if (tieuDe.isEmpty || tieuDe.length > 200) {
      throw ArgumentError('Tiêu đề cần từ 1 đến 200 ký tự.');
    }
    if (noiDung.isEmpty || noiDung.length > 50000) {
      throw ArgumentError('Nội dung cần từ 1 đến 50.000 ký tự.');
    }
    if (summary.length > 500) {
      throw ArgumentError('Tóm tắt tối đa 500 ký tự.');
    }
    var category = cacGiaTri['category'] ?? NewsArticle.categories.first;
    if (category == 'Tự nhập') {
      category = (cacGiaTri['categoryCustom'] ?? '').trim();
      if (category.isEmpty) {
        throw ArgumentError('Vui lòng nhập danh mục tin tức.');
      }
    }
    if (!NewsArticle.categories.contains(category) &&
        cacGiaTri['category'] != 'Tự nhập') {
      throw ArgumentError('Danh mục tin tức không hợp lệ.');
    }
    if (category.length > 100) {
      throw ArgumentError('Danh mục tin tức tối đa 100 ký tự.');
    }
    final homeBanner = cacGiaTri['homeBanner'] == 'Có';
    if (homeBanner && (cacGiaTri['imageUrl'] ?? '').isEmpty) {
      throw ArgumentError('Vui lòng chọn ảnh cho banner trang chủ.');
    }
    return {
      'title': tieuDe,
      'summary': summary,
      'content': noiDung,
      'contentFormat': 'rich_text_v1',
      'coverUrl': cacGiaTri['imageUrl'] ?? '',
      'published': cacGiaTri['status'] == published,
      'category': category,
      'featured': cacGiaTri['featured'] == 'Có',
      'homeBanner': homeBanner,
    };
  }
}
