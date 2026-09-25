import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/app/app_portal.dart';
import 'package:e09_elearning/models/user_arguments.dart';
import 'package:e09_elearning/screens/login_screen.dart';
import 'package:e09_elearning/screens/user/user_home_screen.dart';
import 'package:e09_elearning/services/du_lieu/firestore_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'new exam stores numeric duration and optional closing deadline',
    () async {
      final db = FakeFirebaseFirestore();
      final closesAt = DateTime(2026, 9, 10, 20, 30);
      await FirestoreService(firestore: db).addExam(
        title: 'Giữa kỳ',
        durationMinutes: 45,
        isOpen: true,
        maxAttempts: 2,
        closesAt: closesAt,
      );

      final data = (await db.collection('exams').get()).docs.single.data();
      expect(data['durationMinutes'], 45);
      expect(data['duration'], '45 phút');
      expect(data['maxAttempts'], 2);
      expect((data['closesAt'] as Timestamp).toDate(), closesAt);
    },
  );

  test('closed and expired exams cannot create an attempt', () async {
    final db = FakeFirebaseFirestore();
    final service = FirestoreService(firestore: db);
    await db.collection('exams').doc('closed').set({
      'isOpen': false,
      'durationMinutes': 30,
    });
    await db.collection('exams').doc('expired').set({
      'isOpen': true,
      'durationMinutes': 30,
      'closesAt': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    });

    for (final id in ['closed', 'expired']) {
      await db.doc('courses/c/lessons/$id').set({
        'learningMode': 'study_exam',
        'examId': id,
      });
      await db.doc('users/student/learning/c_$id').set({
        'courseId': 'c',
        'lessonId': id,
        'completed': true,
      });
      await expectLater(
        service.getOrCreateAttempt(
          courseId: 'c',
          lessonId: id,
          userId: 'student',
          examId: id,
          durationMinutes: 30,
        ),
        throwsStateError,
      );
    }
    expect((await db.collection('exam_attempts').get()).docs, isEmpty);
  });

  testWidgets('home logout awaits sign-out before returning to login', (
    tester,
  ) async {
    var signedOut = false;
    await tester.pumpWidget(
      PortalScope(
        portal: AppPortal.user,
        homeBuilder: (_) => const SizedBox(),
        child: MaterialApp(
          home: UserHomeScreen(
            args: const UserArguments(userId: 'u1', userName: 'An'),
            service: FirestoreService(firestore: FakeFirebaseFirestore()),
            onSignOut: () async => signedOut = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(signedOut, isTrue);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
