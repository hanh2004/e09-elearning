import 'package:e09_elearning/screens/user/doc_bai_hoc.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'leaving app resets incomplete study time and completed lessons stay completed',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final service = LearningService(db: db);
      Widget reader() => MaterialApp(
        home: LessonReaderScreen(
          uid: 'u',
          courseId: 'c',
          lessonId: 'l',
          lesson: const {
            'title': 'Bài học',
            'content': 'Nội dung',
            'minimumStudySeconds': 3,
          },
          service: service,
        ),
      );
      await tester.pumpWidget(reader());
      await tester.pumpAndSettle();
      final ref = db.doc('users/u/learning/c_l');
      expect((await ref.get()).data()?['completed'], false);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.textContaining('Yêu thích'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 10));
      expect((await ref.get()).data()?['completed'], false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect((await ref.get()).data()?['completed'], false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect((await ref.get()).data()?['completed'], true);
      expect(find.text('Đã học'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(reader());
      await tester.pumpAndSettle();
      expect(find.text('Đã học'), findsOneWidget);
      expect((await ref.get()).data()?['completed'], true);
    },
  );
}
