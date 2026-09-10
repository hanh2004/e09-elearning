import 'package:e09_elearning/services/firestore_service.dart';
import 'package:e09_elearning/services/learning_service.dart';
import 'package:e09_elearning/models/cau_hoi_model.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('editing an audience preserves all characters of class IDs', () {
    expect(LearningPolicy.classIdFromAudience('class:all'), 'all');
    expect(LearningPolicy.classIdFromAudience('class:small-A'), 'small-A');
    expect(LearningPolicy.classIdFromAudience('all'), '');
  });
  test(
    'server exam duration and attempt limit override stale client values',
    () async {
      final db = FakeFirebaseFirestore();
      final service = FirestoreService(firestore: db);
      await db.doc('exams/e').set({
        'isOpen': true,
        'durationMinutes': 5,
        'maxAttempts': 1,
      });
      final session = await service.getOrCreateAttempt(
        userId: 'u',
        examId: 'e',
        durationMinutes: 60,
      );
      expect(
        session.endsAt.difference(DateTime.now()).inMinutes,
        lessThanOrEqualTo(5),
      );
      await db.doc('exam_attempts/${session.attemptId}').update({
        'status': 'completed',
        'attemptCount': 1,
        'diemSo': 8,
      });
      await expectLater(
        service.getOrCreateAttempt(
          userId: 'u',
          examId: 'e',
          durationMinutes: 60,
          maxAttempts: 99,
        ),
        throwsStateError,
      );
    },
  );
  test('retry preserves legacy attempts and their histories', () async {
    final db = FakeFirebaseFirestore();
    final service = FirestoreService(firestore: db);
    await db.doc('exams/e').set({'isOpen': true, 'durationMinutes': 5});
    for (final id in ['a', 'b']) {
      await db.doc('exam_attempts/$id').set({
        'userId': 'u',
        'examId': 'e',
        'status': 'completed',
        'attemptCount': 1,
        'diemSo': 8,
      });
      await db.doc('exam_attempts/$id/runs/1').set({'score': 8});
    }
    await service.getOrCreateAttempt(
      userId: 'u',
      examId: 'e',
      durationMinutes: 5,
    );
    expect((await db.collection('exam_attempts').get()).docs.length, 2);
    expect((await db.doc('exam_attempts/b/runs/1').get()).exists, true);
  });
  test('unsupported or ungradable questions are rejected', () {
    final valid = {
      'questionText': 'Q',
      'options': ['A', 'B'],
      'correctAnswerIndex': 0,
    };
    expect(CauHoiModel.fromMap(valid, 'q').isValidForExam, true);
    expect(
      CauHoiModel.fromMap({
        ...valid,
        'loai_cau_hoi': 'MULTIPLE_CHOICE',
      }, 'q').isValidForExam,
      false,
    );
    expect(
      CauHoiModel.fromMap({
        ...valid,
        'correctAnswerIndex': -1,
      }, 'q').isValidForExam,
      false,
    );
  });
  test('republishing with edits keeps one notification', () async {
    final db = FakeFirebaseFirestore();
    final service = LearningService(db: db);
    final ref = db.doc('courses/c');
    await service.saveContent('admin', ref, {
      'title': 'C',
      'published': true,
      'audience': 'all',
    });
    await service.saveContent('admin', ref, {
      'published': true,
      'title': 'Updated',
    });
    expect(
      (await db.collection('learning_notifications').get()).docs.length,
      1,
    );
  });
}
