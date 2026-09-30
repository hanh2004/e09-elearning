import 'package:cloud_firestore/cloud_firestore.dart';

class HomeBanner {
  const HomeBanner(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;

  String get imageUrl => data['imageUrl'] as String? ?? '';
  String get title => data['title'] as String? ?? '';
  int get order => data['order'] is int ? data['order'] as int : 0;
  String? get newsId => data['newsId'] as String?;

  static HomeBanner fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> banGhi,
  ) => HomeBanner(banGhi.id, banGhi.data());
}
