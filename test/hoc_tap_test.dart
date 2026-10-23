import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
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
    final releaseAt = DateTime.now().add(const Duration(hours: 2));
    await service.saveContent('admin', course, {
      'published': true,
      'publishedAt': Timestamp.fromDate(releaseAt),
    });
    await service.saveContent('admin', course, {'published': true});
    var notes = (await db.collection('learning_notifications').get()).docs;
    expect(notes.length, 1);
    expect(notes.single.data()['purpose'], 'Học tập');
    expect(notes.single.data()['body'], contains('mục Học tập'));

    final examCourse = db.collection('courses').doc('exam-course');
    await service.saveContent('admin', examCourse, {
      'title': 'Học tập và làm bài kiểm tra',
      'learningMode': 'study_exam',
      'examId': 'final',
      'published': false,
    });
    await service.saveContent('admin', examCourse, {
      'published': true,
      'publishedAt': Timestamp.fromDate(releaseAt),
    });
    notes = (await db.collection('learning_notifications').get()).docs;
    final courseAnnouncement = notes.singleWhere(
      (notice) => notice.data()['courseId'] == 'exam-course',
    );
    expect(courseAnnouncement.data()['purpose'], 'Làm bài kiểm tra');
    expect(courseAnnouncement.data()['body'], contains('mục Kiểm tra'));

    final start = DateTime.now().add(const Duration(hours: 2));
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
    notes = (await db.collection('learning_notifications').get()).docs;
    expect(notes.length, 3);
    final reminder = notes.singleWhere(
      (d) => (d.data()['title'] as String).startsWith('Nhắc'),
    );
    expect(
      (reminder.data()['sendAt'] as Timestamp).toDate(),
      start.subtract(const Duration(hours: 1)),
    );
    expect(reminder.data()['audience'], 'all');
  });
  test('all published courses are shared and drafts stay private', () {
    expect(
      LearningPolicy.canRead({'published': false, 'audience': 'all'}),
      false,
    );
    expect(
      LearningPolicy.canRead({'published': true, 'audience': 'class:B'}),
      true,
    );
    expect(
      LearningPolicy.canRead({'published': true, 'audience': 'class:A'}),
      true,
    );
    expect(
      LearningPolicy.canRead({'published': true, 'audience': 'all'}),
      true,
    );
  });
  test('completion ignores deleted lessons and duplicate progress', () {
    expect(LearningPolicy.completion([], ['old']), 0);
    expect(LearningPolicy.completion(['a', 'b'], ['a', 'a', 'deleted']), .5);
  });
  test('course queries select all published courses', () async {
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
    final result = await service.courses(publishedOnly: true).first;
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
      await service.startLesson('u', 'c', 'l');
      await service.completeLesson('u', 'c', 'l');
      expect(await service.startLesson('u', 'c', 'l'), true);
      final result = await service.progress('u', 'c').first;
      expect(result.docs.length, 1);
      expect(result.docs.single.data()['completed'], true);
      expect(result.docs.single.data().containsKey('favorite'), false);
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
