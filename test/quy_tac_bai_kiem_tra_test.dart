import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/services/du_lieu/dich_vu_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'new exam stores duration and attempt limit without an exam schedule',
    () async {
      final db = FakeFirebaseFirestore();
      await FirestoreService(firestore: db)
          .addExam(title: 'Giữa kỳ', durationMinutes: 45, maxAttempts: 2);

      final data = (await db.collection('exams').get()).docs.single.data();
      expect(data['durationMinutes'], 45);
      expect(data['duration'], '45 phút');
      expect(data['maxAttempts'], 2);
      expect(data.containsKey('isOpen'), isFalse);
      expect(data.containsKey('opensAt'), isFalse);
      expect(data.containsKey('closesAt'), isFalse);
    },
  );

  test(
    'course state controls entry and ignores old per-exam toggles',
    () async {
      final db = FakeFirebaseFirestore();
      final service = FirestoreService(firestore: db);
      final courseEnd = DateTime.now().add(const Duration(days: 1));
      await db.doc('courses/open').set({
        'published': true,
        'learningMode': 'study_exam',
        'examId': 'open',
        'endsAt': Timestamp.fromDate(courseEnd),
      });
      await db.doc('courses/open/lessons/study').set({
        'learningMode': 'study_exam',
        'examId': 'open',
      });
      await db.doc('users/student/learning/open_study').set({
        'courseId': 'open',
        'lessonId': 'study',
        'completed': true,
      });
      await db.collection('exams').doc('open').set({
        'isOpen': false,
        'closesAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 1)),
        ),
        'durationMinutes': 30,
      });

      await service.getOrCreateAttempt(
        courseId: 'open',
        lessonId: 'study',
        userId: 'student',
        examId: 'open',
        durationMinutes: 30,
      );
      expect((await db.collection('exam_attempts').get()).docs, hasLength(1));
    },
  );

  test('closed or ended courses cannot create an attempt', () async {
    final db = FakeFirebaseFirestore();
    final service = FirestoreService(firestore: db);
    await db.collection('courses').doc('closed').set({
      'published': false,
      'learningMode': 'study_exam',
      'examId': 'closed',
    });
    await db.collection('courses').doc('ended').set({
      'published': true,
      'learningMode': 'study_exam',
      'examId': 'ended',
      'endsAt': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    });
    for (final id in ['closed', 'ended']) {
      await db.doc('courses/$id/lessons/study').set({
        'learningMode': 'study_exam',
        'examId': id,
      });
      await db.doc('users/student/learning/${id}_study').set({
        'courseId': id,
        'lessonId': 'study',
        'completed': true,
      });
      await db.doc('exams/$id').set({'durationMinutes': 30});
      await expectLater(
        service.getOrCreateAttempt(
          courseId: id,
          lessonId: 'study',
          userId: 'student',
          examId: id,
          durationMinutes: 30,
        ),
        throwsStateError,
      );
    }
    expect((await db.collection('exam_attempts').get()).docs, isEmpty);
  });
}
