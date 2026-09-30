import 'package:cloud_firestore/cloud_firestore.dart';

class NewsArticle {
  const NewsArticle(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
  static const categories = [
    'Điểm tin',
    'Chủ trương chính sách',
    'Thông tin học tập',
  ];
  String get title => data['title'] as String? ?? '';
  String get summary => data['summary'] as String? ?? '';
  String get content => data['content'] as String? ?? '';
  String get coverUrl => data['coverUrl'] as String? ?? '';
  String get category => data['category'] as String? ?? categories.first;
  bool get featured => data['featured'] == true;
  DateTime? get publishedAt {
    final giaTri = data['publishedAt'] ?? data['updatedAt'];
    return giaTri is Timestamp ? giaTri.toDate() : null;
  }

  static String normalize(String vanBan) {
    var ketQua = vanBan.toLowerCase();
    const groups = {
      'a': 'àáảãạăằắẳẵặâầấẩẫậ',
      'e': 'èéẻẽẹêềếểễệ',
      'i': 'ìíỉĩị',
      'o': 'òóỏõọôồốổỗộơờớởỡợ',
      'u': 'ùúủũụưừứửữự',
      'y': 'ỳýỷỹỵ',
      'd': 'đ',
    };
    for (final capDuLieu in groups.entries) {
      ketQua = ketQua.replaceAll(RegExp('[${capDuLieu.value}]'), capDuLieu.key);
    }
    return ketQua.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool matches(String timKiem) =>
      normalize('$title $summary $content').contains(normalize(timKiem));

  String timeLabel({DateTime? now}) {
    final ngay = publishedAt;
    if (ngay == null) return 'Vừa cập nhật';
    final age = (now ?? DateTime.now()).difference(ngay);
    if (age.inMinutes < 1) return 'Vừa đăng';
    if (age.inHours < 1) return '${age.inMinutes} phút trước';
    if (age.inDays < 1) return '${age.inHours} giờ trước';
    if (age.inDays < 7) return '${age.inDays} ngày trước';
    return '${ngay.day.toString().padLeft(2, '0')}/${ngay.month.toString().padLeft(2, '0')}/${ngay.year}';
  }
}
