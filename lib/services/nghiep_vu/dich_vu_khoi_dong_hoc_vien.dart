// XỬ LÝ DỮ LIỆU: Tải trước dữ liệu học viên sau khi đăng nhập.

import 'package:cloud_firestore/cloud_firestore.dart';

class UserStartupService {
  UserStartupService({FirebaseFirestore? db})
    : db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore db;

  Future<void> preload(String maNguoiDung) async {
    final cacKhoaHoc = await _docTruyVan(
      db.collection('courses').where('published', isEqualTo: true),
    );
    final cacLuotThi = await _docTruyVan(
      db.collection('exam_attempts').where('userId', isEqualTo: maNguoiDung),
    );
    final requests = <Future<Object?>>[
      _docTruyVan(db.collection('news').where('published', isEqualTo: true)),
      _docBanGhi(db.collection('users').doc(maNguoiDung)),
      _docTruyVan(
        db.collection('users').doc(maNguoiDung).collection('learning'),
      ),
      _docTruyVan(
        db
            .collection('users')
            .doc(maNguoiDung)
            .collection('notification_reads'),
      ),
    ];
    for (final khoaHoc in cacKhoaHoc?.docs ?? const []) {
      requests.add(_docTruyVan(khoaHoc.reference.collection('lessons')));
    }
    for (final luotThi in cacLuotThi?.docs ?? const []) {
      requests.add(_docTruyVan(luotThi.reference.collection('runs')));
    }
    await Future.wait(requests);
  }

  Future<QuerySnapshot<Map<String, dynamic>>?> _docTruyVan(
    Query<Map<String, dynamic>> truyVan,
  ) => _docDuLieu(truyVan.get);

  Future<DocumentSnapshot<Map<String, dynamic>>?> _docBanGhi(
    DocumentReference<Map<String, dynamic>> thamChieu,
  ) => _docDuLieu(thamChieu.get);

  Future<T?> _docDuLieu<T>(Future<T> Function(GetOptions) doc) async {
    try {
      return await doc(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      try {
        return await doc(const GetOptions(source: Source.cache))
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        return null;
      }
    }
  }
}
