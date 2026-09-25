import 'package:e09_elearning/screens/user/saved_lessons_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/screens/user/user_courses_screen.dart';
import 'package:e09_elearning/screens/user/secure_exam_screen.dart';
import 'package:e09_elearning/services/nghiep_vu/learning_service.dart';
import 'package:e09_elearning/services/ket_noi_api/secure_exam_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'exam content saves study without completing lessons or course',
    () async {
      final db = FakeFirebaseFirestore();
      final service = LearningService(db: db);
      await db.doc('courses/c').set({
        'learningMode': 'study_exam',
        'examId': 'e',
      });
      await db.doc('courses/c/lessons/l').set({'order': 1});
      await service.startLesson('u', 'c', 'l');
      await service.completeLesson('u', 'c', 'l');
      final ref = db.doc('users/u/learning/c_l');
      final record = (await ref.get()).data()!;
      expect(record['studyCompleted'], true);
      expect(record['completed'], false);
      expect(record.containsKey('completedAt'), false);
      expect(await service.startLesson('u', 'c', 'l'), true);
      expect((await ref.get()).data(), record);
      expect(await service.isCourseComplete('u', 'c'), false);
      expect(await service.isCourseComplete('u', 'c', studyOnly: true), true);
      await ref.update({'completed': true}); // Legacy reading-only completion.
      expect(await service.isCourseComplete('u', 'c'), false);
      await ref.update({'examCompleted': true, 'completedExamId': 'e'});
      expect(await service.isCourseComplete('u', 'c'), true);
      await db.doc('courses/c').update({'examId': 'replacement'});
      expect(await service.isCourseComplete('u', 'c'), false);
    },
  );

  test(
    'study progress is promoted after course changes to study only',
    () async {
      final db = FakeFirebaseFirestore();
      final service = LearningService(db: db);
      await db.doc('courses/c').set({
        'learningMode': 'study_exam',
        'examId': 'e',
      });
      await db.doc('courses/c/lessons/l').set({'order': 1});
      await service.startLesson('u', 'c', 'l');
      await service.completeLesson('u', 'c', 'l');
      await db.doc('courses/c').update({
        'learningMode': 'study_only',
        'examId': '',
      });
      expect(await service.startLesson('u', 'c', 'l'), true);
      final record = (await db.doc('users/u/learning/c_l').get()).data()!;
      expect(record['studyCompleted'], true);
      expect(record['completed'], true);
      expect(record['completedAt'], isA<Timestamp>());
    },
  );

  testWidgets('saved lessons excludes unfinished study and all exam content', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    for (final mode in ['study_only', 'study_exam']) {
      await db.doc('courses/$mode').set({
        'published': true,
        'title': mode,
        'learningMode': mode,
        'examId': mode == 'study_exam' ? 'e' : '',
      });
      for (final done in [true, false]) {
        await db.doc('courses/$mode/lessons/$done').set({
          'order': done ? 1 : 2,
          'title': '$mode $done',
          'learningMode': 'study_exam',
          'examId': 'old',
        });
        await db.doc('users/u/learning/${mode}_$done').set({
          'courseId': mode,
          'lessonId': '$done',
          'completed': done,
        });
      }
    }
    await tester.pumpWidget(
      MaterialApp(
        home: SavedLessonsScreen(
          uid: 'u',
          service: LearningService(db: db),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('study_only true'), findsNothing);
    expect(find.text('study_only false'), findsNothing);
    expect(find.text('study_exam true'), findsNothing);
    expect(find.text('study_exam false'), findsNothing);
    for (final mode in ['study_only', 'study_exam']) {
      await db.doc('users/u/learning/${mode}_false').update({
        'completed': true,
      });
    }
    await tester.pumpAndSettle();
    expect(find.text('study_only'), findsOneWidget);
    expect(find.text('study_only true'), findsNothing);
    expect(find.text('study_only false'), findsNothing);
    expect(find.text('study_exam'), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: UserCoursesScreen(
          uid: 'u',
          service: LearningService(db: db),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('study_only'), findsOneWidget);
    // The admin's end action retains publication and lesson/progress documents.
    await LearningService(db: db)
        .saveContent('admin', db.doc('courses/study_only'), {
          'published': true,
          'endsAt': Timestamp.fromDate(DateTime(2020)),
          'deploymentMode': 'manual',
        });
    await tester.pumpAndSettle();
    expect(find.text('study_only'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: SavedLessonsScreen(
          uid: 'u',
          service: LearningService(db: db),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('study_only'), findsOneWidget);
    expect(find.text('study_only true'), findsNothing);
    expect(find.text('study_only false'), findsNothing);
    await tester.tap(find.text('study_only'));
    await tester.pumpAndSettle();
    expect(find.byType(UserLessonsScreen), findsOneWidget);
    await tester.tap(find.text('Chương học'));
    await tester.pumpAndSettle();
    expect(find.text('study_only true'), findsOneWidget);
    expect(find.text('study_only false'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history groups completed attempts by course including failed scores',
    (tester) async {
      final service = SecureExamService(
        transport: (_, _) async => {
          'runs': [
            for (final entry in [
              ('c', 'completed', 2),
              ('c', 'completed', 8),
              ('other', 'completed', 5),
              ('pending', 'in_progress', 0),
            ])
              {
                'courseId': entry.$1,
                'courseTitle': 'Khóa ${entry.$1}',
                'status': entry.$2,
                'title': 'Đề ${entry.$3}',
                'score': entry.$3,
                'passed': entry.$3 >= 5,
                'completedAt': 1000,
              },
          ],
        },
      );
      await tester.pumpWidget(
        MaterialApp(home: SecureExamHistoryScreen(service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Khóa c'), findsOneWidget);
      expect(find.text('Khóa other'), findsOneWidget);
      expect(find.text('Khóa pending'), findsNothing);
      await tester.tap(find.text('Khóa c'));
      await tester.pumpAndSettle();
      expect(find.text('Đề 2'), findsOneWidget);
      expect(find.text('Đề 8'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
