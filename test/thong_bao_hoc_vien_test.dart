import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/app/chu_de_hoc_vien.dart';
import 'package:e09_elearning/screens/user/cac_khoa_hoc.dart';
import 'package:e09_elearning/screens/user/thong_bao_hoc_vien.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('course notification opens a legacy test course from HỌC NGAY', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final service = LearningService(db: db);
    final sentAt = DateTime.now().subtract(const Duration(minutes: 1));
    await db.doc('users/u').set({'classId': 'A'});
    await db.doc('courses/c').set({
      'title': 'Khóa cũ có kiểm tra',
      'published': true,
      'publishedAt': Timestamp.fromDate(sentAt),
    });
    await db.doc('courses/c/lessons/l').set({
      'title': 'Bài học kiểm tra',
      'learningMode': 'study_exam',
      'examId': 'exam',
    });
    await db.doc('learning_notifications/n').set({
      'title': 'Khóa học mới: Khóa cũ có kiểm tra',
      'courseId': 'c',
      'purpose': 'Làm bài kiểm tra',
      'body': 'Mở khóa học để bắt đầu.',
      'audience': 'all',
      'sendAt': Timestamp.fromDate(sentAt),
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: LearnerTheme.light,
        home: UserNotificationsScreen(uid: 'u', service: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khóa học mới: Khóa cũ có kiểm tra'));
    await tester.pumpAndSettle();
    expect(find.text('Khóa cũ có kiểm tra'), findsOneWidget);
    expect(find.text('Học ngay'), findsNothing);
    await tester.tap(find.text('HỌC NGAY'));
    await tester.pumpAndSettle();
    expect(find.byType(TestCourseDetailsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
