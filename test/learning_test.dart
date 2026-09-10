import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/services/firestore_service.dart';
import 'package:e09_elearning/services/learning_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('publication and scheduled exams create scoped notifications', () async {
    final db = FakeFirebaseFirestore();
    final service = LearningService(db: db);
    final course = db.collection('courses').doc('c');
    await service.saveContent('admin', course, {
      'title': 'Math',
      'published': false,
      'audience': 'class:A',
    });
    expect((await db.collection('learning_notifications').get()).docs, isEmpty);
    await service.saveContent('admin', course, {'published': true});
    await service.saveContent('admin', course, {'published': true});
    expect(
      (await db.collection('learning_notifications').get()).docs.length,
      1,
    );
    final start = DateTime(2026, 10, 1, 10);
    await service.saveContent(
      'admin',
      db.collection('learning_events').doc('e'),
      {
        'title': 'Exam',
        'type': 'exam',
        'audience': 'class:A',
        'startsAt': Timestamp.fromDate(start),
      },
    );
    final notes = (await db.collection('learning_notifications').get()).docs;
    expect(notes.length, 2);
    final reminder = notes.singleWhere(
      (d) => (d.data()['title'] as String).startsWith('Nhắc'),
    );
    expect(
      (reminder.data()['sendAt'] as Timestamp).toDate(),
      start.subtract(const Duration(hours: 1)),
    );
    expect(reminder.data()['audience'], 'all');
  });
  test(
    'submission preserves every run and duplicate submit is idempotent',
    () async {
      final db = FakeFirebaseFirestore();
      final service = FirestoreService(firestore: db);
      final ref = db.collection('exam_attempts').doc('attempt');
      await ref.set({
        'userId': 'u',
        'examId': 'e',
        'status': 'in_progress',
        'attemptCount': 0,
      });
      Future<void> submit(double score) => service.submitExam(
        maLuot: 'attempt',
        diemSo: score,
        dsCauTraLoi: [],
        examTitle: 'Exam',
        correctAnswers: score.toInt(),
        totalQuestions: 10,
      );
      await submit(8);
      await submit(8);
      expect((await ref.collection('runs').get()).docs.length, 1);
      await ref.update({'status': 'in_progress'});
      await submit(5);
      expect((await ref.collection('runs').get()).docs.length, 2);
      expect((await ref.get()).data()!['bestScore'], 8);
      expect((await ref.collection('runs').doc('2').get()).data()!['score'], 5);
    },
  );
  test('all published courses are shared and drafts stay private', () {
    expect(
      LearningPolicy.canRead({'published': false, 'audience': 'all'}, 'A'),
      false,
    );
    expect(
      LearningPolicy.canRead({'published': true, 'audience': 'class:B'}, 'A'),
      true,
    );
    expect(
      LearningPolicy.canRead({'published': true, 'audience': 'class:A'}, 'A'),
      true,
    );
    expect(
      LearningPolicy.canRead({'published': true, 'audience': 'all'}, 'A'),
      true,
    );
  });
  test('completion ignores deleted lessons and duplicate progress', () {
    expect(LearningPolicy.completion([], ['old']), 0);
    expect(LearningPolicy.completion(['a', 'b'], ['a', 'a', 'deleted']), .5);
  });
  test('only absolute HTTPS media links accepted', () {
    expect(LearningPolicy.validateUrl('https://example.org/a.pdf'), null);
    for (final url in [
      'javascript:alert(1)',
      'http://example.org',
      '/a.pdf',
      'https:foo',
    ]) {
      expect(LearningPolicy.validateUrl(url), isNotNull);
    }
  });
  test('course queries select published courses for correct class', () async {
    final db = FakeFirebaseFirestore();
    final service = LearningService(db: db);
    for (final entry in {
      'public': 'all',
      'own': 'class:A',
      'other': 'class:B',
    }.entries) {
      await db.collection('courses').doc(entry.key).set({
        'published': true,
        'audience': entry.value,
      });
    }
    await db.collection('courses').doc('draft').set({
      'published': false,
      'audience': 'all',
    });
    final result = await service.courses(classId: 'A').first;
    expect(
      result.docs.map((d) => d.id),
      unorderedEquals(['public', 'own', 'other']),
    );
  });
  test(
    'progress updates retain one record and content edits create audit',
    () async {
      final db = FakeFirebaseFirestore();
      final service = LearningService(db: db);
      await service.markLesson('u', 'c', 'l', completed: true, favorite: false);
      await service.markLesson('u', 'c', 'l', completed: true, favorite: true);
      final result = await service.progress('u', 'c').first;
      expect(result.docs.length, 1);
      expect(result.docs.single.data()['favorite'], true);
      await service.saveContent('admin', db.collection('courses').doc('c'), {
        'title': 'Course',
      });
      expect(
        (await db.collection('learning_audit').get()).docs.single
            .data()['actorId'],
        'admin',
      );
    },
  );
}

// Each submission is archived even when it does not beat the best score.
