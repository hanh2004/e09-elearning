import 'package:cloud_firestore/cloud_firestore.dart';

/// Pure policy helpers are shared by lists, detail pages and tests.
class LearningPolicy {
  static String classIdFromAudience(String? audience) =>
      audience != null && audience.startsWith('class:')
      ? audience.substring(6)
      : '';

  static bool canRead(Map<String, dynamic> course, String classId) =>
      course['published'] == true;

  static double completion(
    Iterable<String> lessons,
    Iterable<String> completed,
  ) {
    final ids = lessons.toSet();
    return ids.isEmpty
        ? 0
        : ids.intersection(completed.toSet()).length / ids.length;
  }

  static String? validateUrl(String value) {
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? null
        : 'Liên kết phải bắt đầu bằng https://';
  }
}

class LearningService {
  LearningService({FirebaseFirestore? db})
    : db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore db;

  Stream<QuerySnapshot<Map<String, dynamic>>> notificationReads(String uid) =>
      db
          .collection('users')
          .doc(uid)
          .collection('notification_reads')
          .snapshots();

  Future<void> markNotificationRead(String uid, String notificationId) => db
      .collection('users')
      .doc(uid)
      .collection('notification_reads')
      .doc(notificationId)
      .set({'readAt': FieldValue.serverTimestamp()});

  Stream<QuerySnapshot<Map<String, dynamic>>> courses({String? classId}) {
    Query<Map<String, dynamic>> query = db.collection('courses');
    if (classId != null) {
      query = query.where('published', isEqualTo: true);
    }
    return query.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> lessons(String courseId) => db
      .collection('courses')
      .doc(courseId)
      .collection('lessons')
      .orderBy('order')
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> progress(
    String uid,
    String courseId,
  ) => db
      .collection('users')
      .doc(uid)
      .collection('learning')
      .where('courseId', isEqualTo: courseId)
      .snapshots();

  Future<void> markLesson(
    String uid,
    String courseId,
    String lessonId, {
    required bool completed,
    required bool favorite,
  }) => db
      .collection('users')
      .doc(uid)
      .collection('learning')
      .doc('${courseId}_$lessonId')
      .set({
        'courseId': courseId,
        'lessonId': lessonId,
        'completed': completed,
        'favorite': favorite,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> saveContent(
    String uid,
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    final auditRef = db.collection('learning_audit').doc();
    final notificationRef = db.collection('learning_notifications').doc();
    await db.runTransaction((batch) async {
      final previous = (await batch.get(ref)).data();
      Map<String, dynamic>? announcement;
      if (ref.parent.id == 'courses' &&
          data['published'] == true &&
          previous?['published'] != true) {
        final course = {...?previous, ...data};
        announcement = {
          'title': 'Khóa học mới: ${course['title']}',
          'body': 'Khóa học đã được xuất bản. Mở mục Khóa học để bắt đầu.',
          'audience': 'all',
        };
      } else if (ref.parent.id == 'lessons' && previous == null) {
        final course = (await batch.get(ref.parent.parent!)).data();
        if (course?['published'] == true) {
          announcement = {
            'title': 'Bài học mới: ${data['title']}',
            'body': 'Khóa học ${course!['title']} có bài học mới.',
            'audience': 'all',
          };
        }
      }
      if (ref.parent.id == 'learning_events' &&
          data['type'] == 'exam' &&
          previous == null) {
        final start = (data['startsAt'] as Timestamp).toDate();
        announcement = {
          'title': 'Nhắc lịch thi: ${data['title']}',
          'body': 'Bài thi bắt đầu lúc $start. ${data['note'] ?? ''}',
          'audience': 'all',
          'sendAt': Timestamp.fromDate(
            start.subtract(const Duration(hours: 1)),
          ),
        };
      }
      if (announcement != null) {
        batch.set(notificationRef, {
          ...announcement,
          'sendAt': announcement['sendAt'] ?? FieldValue.serverTimestamp(),
          'updatedBy': uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      batch.set(ref, {
        ...data,
        'updatedBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(auditRef, {
        'actorId': uid,
        'path': ref.path,
        'action': 'save',
        'at': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> notifications(
    String uid,
    String classId,
  ) => db
      .collection('learning_notifications')
      .where('audience', whereIn: ['all', 'class:$classId', 'user:$uid'])
      .where('sendAt', isLessThanOrEqualTo: Timestamp.now())
      .snapshots();
}
