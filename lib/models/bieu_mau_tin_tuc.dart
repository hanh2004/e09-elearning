import 'bai_viet_tin_tuc.dart';

class NewsForm {
  static const draft = 'Bản nháp';
  static const published = 'Đăng tin';
  static const customCategorySelection = '__custom_news_category__';

  static Map<String, dynamic> toFirestore(
    Map<String, String> cacGiaTri, {
    Iterable<String> knownCategories = NewsArticle.categories,
  }) {
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
    if (category == customCategorySelection) {
      category = (cacGiaTri['categoryCustom'] ?? '').trim();
      if (category.isEmpty) {
        throw ArgumentError('Vui lòng nhập danh mục tin tức.');
      }
    }
    if (!knownCategories.contains(category) &&
        cacGiaTri['category'] != customCategorySelection) {
      throw ArgumentError('Danh mục tin tức không hợp lệ.');
    }
    if (category.length > 100) {
      throw ArgumentError('Danh mục tin tức tối đa 100 ký tự.');
    }
    if (category == 'Tất cả' || category == customCategorySelection) {
      throw ArgumentError('Tên loại tin này đã được dành riêng.');
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
      'showCategoryTab': cacGiaTri['showCategoryTab'] == 'Có',
      'featured': cacGiaTri['featured'] == 'Có',
      'homeBanner': homeBanner,
    };
  }
}
