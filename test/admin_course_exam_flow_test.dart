import 'package:e09_elearning/models/account_identity.dart';
import 'package:e09_elearning/screens/admin/admin_lessons_screen.dart';
import 'package:e09_elearning/services/nghiep_vu/learning_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('study-only course does not show an exam action', (tester) async {
    AccountSession.current = const AccountIdentity(
      id: 'root',
      role: 'super_admin',
    );
    addTearDown(() => AccountSession.current = null);
    final db = FakeFirebaseFirestore();
    await db.doc('courses/only').set({
      'title': 'Khóa chỉ học',
      'published': false,
      'learningMode': 'study_only',
      'examId': '',
      'coverUrl': 'https://example.org/course.png',
    });
    final course = (await db.collection('courses').get()).docs.single;
    await tester.pumpWidget(
      MaterialApp(
        home: AdminLessonsScreen(
          course: course,
          service: LearningService(db: db),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thêm bài kiểm tra'), findsNothing);
    expect(find.text('Quản lý bài kiểm tra'), findsNothing);
  });

  testWidgets('admin adds the exam from the course detail page', (
    tester,
  ) async {
    AccountSession.current = const AccountIdentity(
      id: 'root',
      role: 'super_admin',
    );
    addTearDown(() => AccountSession.current = null);
    final db = FakeFirebaseFirestore();
    await db.doc('courses/c').set({
      'title': 'Khóa học nghị quyết',
      'published': false,
      'learningMode': 'study_exam',
      'examId': '',
      'coverUrl': 'https://example.org/course.png',
    });
    final course = (await db.collection('courses').get()).docs.single;
    await tester.pumpWidget(
      MaterialApp(
        home: AdminLessonsScreen(
          course: course,
          service: LearningService(db: db),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm bài kiểm tra'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Tên bài kiểm tra'),
      'Kiểm tra nghị quyết',
    );
    await tester.tap(find.text('Tạo'));
    await tester.pumpAndSettle();
    final updated = (await db.doc('courses/c').get()).data()!;
    final examId = updated['examId'] as String;
    expect(updated['learningMode'], 'study_exam');
    expect(examId, isNotEmpty);
    expect((await db.doc('exams/$examId').get()).data()?['courseId'], 'c');
    expect(find.text('Quản lý bài kiểm tra'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin can delete a lesson from the course detail page', (
    tester,
  ) async {
    AccountSession.current = const AccountIdentity(
      id: 'root',
      role: 'super_admin',
    );
    addTearDown(() => AccountSession.current = null);
    final db = FakeFirebaseFirestore();
    await db.doc('courses/c').set({
      'title': 'Khóa học nghị quyết',
      'published': false,
      'learningMode': 'study_only',
      'coverUrl': 'https://example.org/course.png',
    });
    await db.doc('courses/c/lessons/l').set({
      'title': 'Bài học cần xóa',
      'order': 1,
      'type': 'text',
      'content': 'Nội dung',
    });
    final course = (await db.collection('courses').get()).docs.single;
    await tester.pumpWidget(
      MaterialApp(
        home: AdminLessonsScreen(
          course: course,
          service: LearningService(db: db),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Xóa bài học'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa bài học'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await tester.pumpAndSettle();

    expect((await db.doc('courses/c/lessons/l').get()).exists, isFalse);
    expect(
      find.text('Thêm bài học trước khi xuất bản chuyên đề.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
