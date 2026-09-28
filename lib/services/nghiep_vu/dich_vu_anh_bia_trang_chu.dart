import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/anh_bia_trang_chu.dart';

class HomeBannerService {
  const HomeBannerService(this.db);
  final FirebaseFirestore db;

  Stream<List<HomeBanner>> active() => db
      .collection('home_banners')
      .where('active', isEqualTo: true)
      .snapshots()
      .map((duLieuNhan) {
        final ketQua = duLieuNhan.docs.map(HomeBanner.fromDoc).toList();
        ketQua.sort((a, b) {
          final byOrder = a.order.compareTo(b.order);
          return byOrder == 0 ? a.id.compareTo(b.id) : byOrder;
        });
        return ketQua.take(5).toList();
      });
}
