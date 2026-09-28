import 'package:cloud_firestore/cloud_firestore.dart';

class HomeBanner {
  const HomeBanner(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;

  String get imageUrl => data['imageUrl'] as String? ?? '';
  String get title => data['title'] as String? ?? '';
  int get order => data['order'] is int ? data['order'] as int : 0;
  bool get active => data['active'] != false;
  String? get newsId => data['newsId'] as String?;

  static HomeBanner fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> banGhi,
  ) => HomeBanner(banGhi.id, banGhi.data());

  static Map<String, dynamic> toFirestore(Map<String, String> cacGiaTri) {
    final imageUrl = (cacGiaTri['imageUrl'] ?? '').trim();
    if (imageUrl.isEmpty) throw ArgumentError('Vui lòng chọn ảnh banner.');
    final order = int.tryParse(cacGiaTri['order'] ?? '');
    if (order == null || order < 1 || order > 5) {
      throw ArgumentError('Vị trí banner phải từ 1 đến 5.');
    }
    return {
      'imageUrl': imageUrl,
      'title': (cacGiaTri['title'] ?? '').trim(),
      'order': order,
      'active': cacGiaTri['active'] == 'Có',
    };
  }
}
