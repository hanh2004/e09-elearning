// XỬ LÝ DỮ LIỆU / API: Đọc/ghi khóa học, bài học, tiến độ, thông báo và lịch sử thay đổi.
// Các màn hình gọi mã ở đây; quyền truy cập cuối cùng do Firebase/API kiểm tra.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../models/dinh_danh_tai_khoan.dart';
import '../../models/quy_tac_hoc_tap.dart';
import '../ket_noi_api/api_tai_khoan.dart';
import '../du_lieu/lo_ghi_firestore.dart';

// Giữ tương thích cho các màn hình đang import LearningPolicy từ service này.
export '../../models/quy_tac_hoc_tap.dart';

class LearningService {
  LearningService({FirebaseFirestore? db, AccountApi? api})
    : db = db ?? FirebaseFirestore.instance,
      _ketNoiApi = api ?? AccountApi(useBackend: db == null);
  final FirebaseFirestore db;
  final AccountApi _ketNoiApi;

  // Cache rỗng chưa chứng minh máy chủ không có dữ liệu. Chờ xác nhận từ
  // Firebase; cache có nội dung vẫn dùng được khi mạng tạm thời gián đoạn.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchQuery(
    Query<Map<String, dynamic>> query,
  ) => query
      .snapshots(includeMetadataChanges: true)
      .where(
        (snapshot) =>
            snapshot.docs.isNotEmpty || !snapshot.metadata.isFromCache,
      );

  // Chỉ fallback khi endpoint chưa được triển khai. Lỗi mạng hoặc lỗi nội bộ
  // có thể xảy ra sau khi backend đã bắt đầu xóa, nên không chạy xóa lần hai.
  static const _maLoiThuTrucTiep = {'not-found', 'unimplemented'};

  /// Chuyển lỗi xóa thành thông báo có thể xử lý được ở màn hình Admin.
  String deletionErrorMessage(Object error, {required String itemName}) {
    if (error is StateError) return error.message.toString();
    if (error is FirebaseFunctionsException) {
      final message = error.message?.trim();
      if (message != null &&
          message.isNotEmpty &&
          error.code != 'internal' &&
          error.code != 'unavailable') {
        return message;
      }
      if (error.code == 'permission-denied' ||
          error.code == 'unauthenticated') {
        return 'Tài khoản hiện tại không có quyền xóa $itemName. Hãy đăng nhập bằng tài khoản Admin tổng.';
      }
      return 'Không nhận được kết quả xóa $itemName từ máy chủ. Hãy tải lại danh sách trước khi thử lại để tránh xóa lặp.';
    }
    return 'Không thể xóa $itemName. Hãy kiểm tra kết nối và quyền Admin tổng, rồi tải lại danh sách.';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> notificationReads(
    String maNguoiDung,
  ) => watchQuery(
    db.collection('users').doc(maNguoiDung).collection('notification_reads'),
  );

  Future<void> markNotificationRead(
    String maNguoiDung,
    String notificationId,
  ) => db
      .collection('users')
      .doc(maNguoiDung)
      .collection('notification_reads')
      .doc(notificationId)
      .set({'readAt': FieldValue.serverTimestamp()});

  Stream<QuerySnapshot<Map<String, dynamic>>> courses({
    bool publishedOnly = false,
  }) {
    Query<Map<String, dynamic>> truyVan = db.collection('courses');
    if (publishedOnly) {
      truyVan = truyVan.where('published', isEqualTo: true);
    }
    return watchQuery(truyVan);
  }

  /// Fetch all lessons and sort them in the UI. Firestore `orderBy('order')`
  /// silently omits older lesson documents that do not have the order field.
  Stream<QuerySnapshot<Map<String, dynamic>>> lessons(String courseId) =>
      watchQuery(db.collection('courses').doc(courseId).collection('lessons'));

  Stream<QuerySnapshot<Map<String, dynamic>>> progress(
    String maNguoiDung,
    String courseId,
  ) => watchQuery(
    db
        .collection('users')
        .doc(maNguoiDung)
        .collection('learning')
        .where('courseId', isEqualTo: courseId),
  );

  /// Xóa vĩnh viễn khóa học và toàn bộ dữ liệu con đã biết của khóa học.
  /// Các lô ghi nhỏ hơn giới hạn Firestore để xử lý khóa học có nhiều học viên.
  Future<void> deleteCourse(String courseId) => _xoaVoiDuongDuPhong(
    'courseDelete',
    {'courseId': courseId},
    () => _xoaKhoaHocTrucTiep(courseId),
  );

  /// Xóa vĩnh viễn một bài học và các bản ghi tiến độ của bài đó.
  /// Dùng backend khi có thể; đường trực tiếp giữ cho emulator và bản cài
  /// chưa triển khai Functions vẫn hoạt động như các thao tác quản trị khác.
  Future<void> deleteLesson(String courseId, String lessonId) =>
      _xoaVoiDuongDuPhong('courseDeleteLesson', {
        'courseId': courseId,
        'lessonId': lessonId,
      }, () => _xoaBaiHocTrucTiep(courseId, lessonId));

  /// Ưu tiên backend; dùng đường trực tiếp khi Functions chưa triển khai.
  Future<void> _xoaVoiDuongDuPhong(
    String tenHam,
    Map<String, dynamic> thamSo,
    Future<void> Function() xoaTrucTiep,
  ) async {
    if (_ketNoiApi.hasTransport) {
      try {
        await _ketNoiApi.call(tenHam, thamSo);
        return;
      } on FirebaseFunctionsException catch (loi) {
        if (!_maLoiThuTrucTiep.contains(loi.code)) {
          rethrow;
        }
      }
    }
    await xoaTrucTiep();
  }

  Future<void> _xoaBaiHocTrucTiep(String courseId, String lessonId) async {
    final baiHoc = db.doc('courses/$courseId/lessons/$lessonId');
    final duLieuBaiHoc = (await baiHoc.get()).data() ?? <String, dynamic>{};
    if (duLieuBaiHoc['examId']?.toString().trim().isNotEmpty ?? false) {
      throw StateError(
        'Bài học có đề thi liên quan; cần triển khai Cloud Function '
        'courseDeleteLesson để xóa an toàn cả dữ liệu lượt thi.',
      );
    }
    final progressRecords = await _tienDoKhoaHoc(courseId, lessonId: lessonId);
    await deleteFirestoreDocuments(db, [...progressRecords, baiHoc]);
  }

  Future<void> _xoaKhoaHocTrucTiep(String courseId) async {
    final khoaHoc = db.collection('courses').doc(courseId);
    final courseData = (await khoaHoc.get()).data() ?? <String, dynamic>{};
    final ownedExams = await db
        .collection('exams')
        .where('courseId', isEqualTo: courseId)
        .limit(1)
        .get();
    final cacBaiHoc = await khoaHoc.collection('lessons').get();
    if ((courseData['examId']?.toString().isNotEmpty ?? false) ||
        ownedExams.docs.isNotEmpty ||
        cacBaiHoc.docs.any(
          (baiHoc) =>
              baiHoc.data()['examId']?.toString().trim().isNotEmpty ?? false,
        )) {
      throw StateError(
        'Khóa học có bài thi liên quan; cần triển khai Cloud Function courseDelete để xóa đầy đủ kết quả thi.',
      );
    }
    final reviews = await khoaHoc.collection('reviews').get();
    final progressRecords = await _tienDoKhoaHoc(courseId);
    final references = <DocumentReference<Map<String, dynamic>>>[
      ...cacBaiHoc.docs.map((banGhi) => banGhi.reference),
      ...reviews.docs.map((banGhi) => banGhi.reference),
      ...progressRecords,
      khoaHoc,
    ];
    await deleteFirestoreDocuments(db, references);
  }

  /// Đọc dữ liệu con của từng học viên để tránh khác biệt về quyền và chỉ mục
  /// collection-group giữa các môi trường Firebase.
  Future<List<DocumentReference<Map<String, dynamic>>>> _tienDoKhoaHoc(
    String courseId, {
    String? lessonId,
  }) async {
    final cacNguoiDung = await db.collection('users').get();
    final references = <DocumentReference<Map<String, dynamic>>>[];
    for (final nguoiDung in cacNguoiDung.docs) {
      Query<Map<String, dynamic>> query = nguoiDung.reference
          .collection('learning')
          .where('courseId', isEqualTo: courseId);
      if (lessonId != null) {
        query = query.where('lessonId', isEqualTo: lessonId);
      }
      final cacMauTin = await query.get();
      references.addAll(cacMauTin.docs.map((banGhi) => banGhi.reference));
    }
    return references;
  }

  /// Chỉ trả true khi mọi bài trong khóa đều có tiến độ hoàn thành.
  /// Khóa học trống không được xem là hoàn thành.
  Future<bool> isCourseComplete(
    String maNguoiDung,
    String courseId, {
    bool studyOnly = false,
  }) async {
    final khoaHoc = (await db.doc('courses/$courseId').get()).data() ?? {};
    final cacBaiHoc = await db
        .collection('courses')
        .doc(courseId)
        .collection('lessons')
        .get();
    if (cacBaiHoc.docs.isEmpty) return false;
    final cacMauTin = await db
        .collection('users')
        .doc(maNguoiDung)
        .collection('learning')
        .where('courseId', isEqualTo: courseId)
        .get();
    final byLesson = {
      for (final banGhi in cacMauTin.docs)
        banGhi.data()['lessonId']: banGhi.data(),
    };
    return cacBaiHoc.docs.every(
      (baiHoc) => studyOnly
          ? LearningPolicy.hasCompletedStudy(byLesson[baiHoc.id] ?? {})
          : LearningPolicy.isLessonComplete(
              byLesson[baiHoc.id] ?? {},
              khoaHoc,
              baiHoc.data(),
            ),
    );
  }

  Future<bool> startLesson(
    String maNguoiDung,
    String courseId,
    String lessonId,
  ) async {
    final thamChieu = db.doc(
      'users/$maNguoiDung/learning/${courseId}_$lessonId',
    );
    return db.runTransaction((tx) async {
      final hienHanh = (await tx.get(thamChieu)).data();
      final khoaHoc = (await tx.get(db.doc('courses/$courseId'))).data() ?? {};
      final baiHoc =
          (await tx.get(db.doc('courses/$courseId/lessons/$lessonId')))
              .data() ??
          {};
      if (LearningPolicy.hasCompletedStudy(hienHanh ?? {})) {
        if (hienHanh?['completed'] != true &&
            !LearningPolicy.requiresExam(khoaHoc, baiHoc)) {
          tx.update(thamChieu, {
            'completed': true,
            'completedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        return true;
      }
      tx.set(thamChieu, {
        'courseId': courseId,
        'lessonId': lessonId,
        'completed': false,
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return false;
    });
  }

  Future<void> completeLesson(
    String maNguoiDung,
    String courseId,
    String lessonId,
  ) async {
    final thamChieu = db.doc(
      'users/$maNguoiDung/learning/${courseId}_$lessonId',
    );
    await db.runTransaction((tx) async {
      final hienHanh = (await tx.get(thamChieu)).data();
      final khoaHoc = (await tx.get(db.doc('courses/$courseId'))).data() ?? {};
      final baiHoc =
          (await tx.get(db.doc('courses/$courseId/lessons/$lessonId')))
              .data() ??
          {};
      final needsExam = LearningPolicy.requiresExam(khoaHoc, baiHoc);
      if (LearningPolicy.hasCompletedStudy(hienHanh ?? {})) {
        if (hienHanh?['completed'] != true && !needsExam) {
          tx.update(thamChieu, {
            'completed': true,
            'completedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        return;
      }
      if (hienHanh?['startedAt'] is! Timestamp) {
        throw StateError('Bài học chưa bắt đầu.');
      }
      // Rules Firebase kiểm tra thời lượng tối thiểu theo giờ máy chủ.
      tx.update(thamChieu, {
        'studyCompleted': true,
        'studyCompletedAt': FieldValue.serverTimestamp(),
        'completed': !needsExam,
        if (!needsExam) 'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> saveContent(
    String maNguoiDung,
    DocumentReference<Map<String, dynamic>> thamChieu,
    Map<String, dynamic> duLieu,
  ) async {
    final auditRef = db.collection('learning_audit').doc();
    final notificationRef = db.collection('learning_notifications').doc();
    await db.runTransaction((loGhi) async {
      final truocDo = (await loGhi.get(thamChieu)).data();
      Map<String, dynamic>? announcement;
      if (thamChieu.parent.id == 'courses' &&
          duLieu['published'] == true &&
          truocDo?['published'] != true) {
        LearningPolicy.requireFutureDateTime(
          duLieu['publishedAt'],
          'Thời gian phát hành khóa học',
        );
        final khoaHoc = {...?truocDo, ...duLieu};
        final releaseAt = LearningPolicy.readDateTime(khoaHoc['publishedAt']);
        final releaseIsFuture =
            releaseAt != null && releaseAt.isAfter(DateTime.now());
        final isExamCourse = LearningPolicy.isExamCourse(khoaHoc, const []);
        final destination = isExamCourse ? 'Kiểm tra' : 'Học tập';
        announcement = {
          'title': 'Khóa học mới: ${khoaHoc['title']}',
          'courseId': thamChieu.id,
          'purpose': isExamCourse ? 'Làm bài kiểm tra' : 'Học tập',
          'body': releaseIsFuture
              ? 'Khóa học sẽ được phát hành lúc $releaseAt. Mở mục $destination để bắt đầu khi đến thời gian học.'
              : 'Khóa học đã được triển khai. Mở mục $destination để bắt đầu khi đến thời gian học.',
          'audience': 'all',
          if (releaseIsFuture) 'sendAt': Timestamp.fromDate(releaseAt),
          if (!releaseIsFuture) 'deliveryMode': 'immediate',
        };
      } else if (thamChieu.parent.id == 'lessons' && truocDo == null) {
        final khoaHoc = (await loGhi.get(thamChieu.parent.parent!)).data();
        if (khoaHoc?['published'] == true) {
          final releaseAt = LearningPolicy.readDateTime(
            khoaHoc?['publishedAt'],
          );
          final releaseIsFuture =
              releaseAt != null && releaseAt.isAfter(DateTime.now());
          final isExamCourse = LearningPolicy.isExamCourse(khoaHoc!, const []);
          final destination = isExamCourse ? 'Kiểm tra' : 'Học tập';
          announcement = {
            'title': 'Bài học mới: ${duLieu['title']}',
            'courseId': thamChieu.parent.parent!.id,
            'purpose': isExamCourse ? 'Làm bài kiểm tra' : 'Học tập',
            'body': releaseIsFuture
                ? 'Khóa học ${khoaHoc['title']} có bài học mới. Nội dung mở lúc $releaseAt. Mở mục $destination để tiếp tục.'
                : 'Khóa học ${khoaHoc['title']} có bài học mới. Mở mục $destination để tiếp tục.',
            'audience': 'all',
            if (releaseIsFuture) 'sendAt': Timestamp.fromDate(releaseAt),
            if (!releaseIsFuture) 'deliveryMode': 'immediate',
          };
        }
      }
      if (thamChieu.parent.id == 'learning_events' &&
          duLieu['type'] == 'exam' &&
          truocDo == null) {
        final batDau = LearningPolicy.requireFutureDateTime(
          duLieu['startsAt'],
          'Thời gian bắt đầu sự kiện',
        );
        final nhacLuc = batDau.subtract(const Duration(hours: 1));
        announcement = {
          'title': 'Nhắc lịch thi: ${duLieu['title']}',
          'purpose': 'Làm bài kiểm tra',
          'body': 'Bài thi bắt đầu lúc $batDau. ${duLieu['note'] ?? ''}',
          'audience': 'all',
          'sendAt': Timestamp.fromDate(
            nhacLuc.isAfter(DateTime.now()) ? nhacLuc : batDau,
          ),
        };
      }
      if (announcement != null) {
        loGhi.set(notificationRef, {
          ...announcement,
          'senderName': AccountSession.current?.displayName ?? 'Quản trị viên',
          'sendAt': announcement['sendAt'] ?? FieldValue.serverTimestamp(),
          'updatedBy': maNguoiDung,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      loGhi.set(thamChieu, {
        ...?truocDo,
        ...duLieu,
        if (thamChieu.parent.id == 'news' && truocDo?['publishedAt'] != null)
          'publishedAt': truocDo!['publishedAt'],
        if (thamChieu.parent.id == 'news' &&
            duLieu['published'] == true &&
            (truocDo?['published'] != true || truocDo?['publishedAt'] == null))
          'publishedAt': FieldValue.serverTimestamp(),
        'updatedBy': maNguoiDung,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      loGhi.set(auditRef, {
        'actorId': maNguoiDung,
        'path': thamChieu.path,
        'action': 'save',
        'at': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> notifications(
    String maNguoiDung,
    String classId,
  ) => watchQuery(
    db
        .collection('learning_notifications')
        .where(
          'audience',
          whereIn: ['all', 'class:$classId', 'user:$maNguoiDung'],
        )
        .where('sendAt', isLessThanOrEqualTo: Timestamp.now()),
  );
}
