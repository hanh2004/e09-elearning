// Đọc từng lượt nộp để báo cáo theo ngày không lấy nhầm tổng điểm toàn thời gian.
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminReportAttempts {
  static DateTime? _ngay(Object? giaTri) => giaTri is Timestamp
      ? giaTri.toDate()
      : giaTri is DateTime
      ? giaTri
      : null;

  static bool _trongKhoang(
    DateTime? giaTri,
    DateTime tuNgay,
    DateTime truocNgay,
  ) => giaTri != null && !giaTri.isBefore(tuNgay) && giaTri.isBefore(truocNgay);

  static Future<List<Map<String, dynamic>>> trongKhoang({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> summaries,
    required Set<String> userIds,
    String? examId,
    required DateTime from,
    required DateTime until,
    required FirebaseFirestore db,
  }) async {
    final ketQua = <Map<String, dynamic>>[];
    for (final summary in summaries) {
      final duLieu = summary.data();
      final userId = duLieu['userId']?.toString() ?? '';
      final idBaiThi = duLieu['examId']?.toString() ?? '';
      if (!userIds.contains(userId) ||
          idBaiThi.isEmpty ||
          (examId != null && idBaiThi != examId)) {
        continue;
      }
      final secure = summary.id.startsWith('secure_');
      final cacLanThi =
          await (secure
                  ? db.doc('exam_sessions/${summary.id.substring(7)}')
                  : summary.reference)
              .collection('runs')
              .get();
      if (cacLanThi.docs.isEmpty) {
        final soLuong =
            (duLieu['attemptCount'] as num?)?.toInt() ??
            (duLieu['status'] == 'completed' ? 1 : 0);
        if (soLuong > 1) {
          throw StateError(
            'Kết quả $userId/$idBaiThi có nhiều lượt thi nhưng thiếu dữ liệu từng lượt; không thể xuất chính xác theo ngày.',
          );
        }
        final completedAt = _ngay(
          duLieu['lastAttemptAt'] ?? duLieu['completedAt'],
        );
        if (soLuong == 1 && _trongKhoang(completedAt, from, until)) {
          ketQua.add({
            ...duLieu,
            'attemptCount': 1,
            'reportLastAt': completedAt,
            'reportBestAt': completedAt,
          });
        }
        continue;
      }
      for (final lanThi in cacLanThi.docs) {
        final muc = lanThi.data();
        if (muc['status'] != null && muc['status'] != 'completed') continue;
        final completedAt = _ngay(muc['completedAt']);
        if (!_trongKhoang(completedAt, from, until)) continue;
        ketQua.add({
          'userId': userId,
          'examId': idBaiThi,
          'examTitle': muc['examTitle'] ?? muc['title'] ?? duLieu['examTitle'],
          'attemptCount': 1,
          'status': 'completed',
          'score': muc['score'],
          'passed': muc['passed'],
          'passScore': muc['passScore'] ?? duLieu['passScore'],
          'reportLastAt': completedAt,
          'reportBestAt': completedAt,
        });
      }
    }
    return ketQua;
  }
}
