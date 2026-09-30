import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/models/dinh_danh_tai_khoan.dart';
import 'package:e09_elearning/screens/admin/quan_ly_khoa_hoc.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:e09_elearning/services/ket_noi_api/api_tai_khoan.dart';
import 'package:e09_elearning/widgets/giao_dien_quan_tri.dart';

void main() {
  tearDown(() => AccountSession.current = null);
  test('a course being deleted is unavailable to learners', () {
    expect(
      LearningPolicy.canRead({'published': true, 'deleting': true}, ''),
      isFalse,
    );
  });

  test('direct course deletion refuses legacy lesson-only exams without removing data', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('courses/legacy').set({'published': true});
    await db.doc('courses/legacy/lessons/l').set({'examId': 'legacy_exam'});
    await db.doc('exams/legacy_exam').set({'title': 'Đề cũ'});
    await expectLater(
      LearningService(db: db).deleteCourse('legacy'),
      throwsStateError,
    );
    expect((await db.doc('courses/legacy').get()).exists, isTrue);
    expect((await db.doc('courses/legacy/lessons/l').get()).exists, isTrue);
    expect((await db.doc('exams/legacy_exam').get()).exists, isTrue);
  });

  for (final width in [390.0, 1200.0]) {
    testWidgets(
      'ended course opens locked report and retains desktop menu at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        AccountSession.current = const AccountIdentity(
          id: 'root',
          role: 'super_admin',
        );
        final db = FakeFirebaseFirestore();
        await db.doc('courses/old').set({
          'title': 'Khóa đã hết hạn',
          'subject': 'Nghiệp vụ',
          'published': true,
          'endsAt': Timestamp.fromDate(DateTime(2020)),
        });
        await db.doc('courses/new').set({
          'title': 'Khóa đang mở',
          'published': true,
        });
        await db.doc('courses/old/lessons/one').set({
          'title': 'Bài 1',
          'order': 1,
        });
        await db.doc('users/u').set({
          'name': 'Học viên A',
          'role': 'user',
          'unit': 'D1',
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: AdminUi.theme,
            home: AdminCoursesScreen(
              service: LearningService(db: db),
              ended: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Khóa đang mở'), findsNothing);
        expect(find.text('Tạo khóa học'), findsNothing);
        expect(find.byTooltip('Sửa chuyên đề'), findsNothing);
        expect(find.byTooltip('Xóa vĩnh viễn khóa học'), findsOneWidget);
        await tester.tap(find.text('Khóa đã hết hạn'));
        await tester.pumpAndSettle();
        expect(find.text('Kết quả khóa học'), findsOneWidget);
        expect(find.text('Tổng học viên'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Tổng 1 • Đã hoàn thành 0 • Chưa hoàn thành 1'),
          250,
          scrollable: find.byType(Scrollable).last,
        );
        expect(
          find.text('Tổng 1 • Đã hoàn thành 0 • Chưa hoàn thành 1'),
          findsOneWidget,
        );
        if (width >= 1000) {
          expect(find.byType(NavigationRail), findsNothing);
          expect(find.text('Quản lý khóa học'), findsWidgets);
          expect(find.text('Khóa học kết thúc'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  test('permanently deletes the course and related learning records', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('courses/ended').set({'title': 'Đã kết thúc'});
    await db.doc('courses/ended/lessons/one').set({'title': 'Bài 1'});
    await db.doc('courses/ended/reviews/u').set({'rating': 5});
    await db.doc('users/u').set({'role': 'user', 'status': 'active'});
    await db.doc('users/u/learning/ended_one').set({
      'courseId': 'ended',
      'lessonId': 'one',
    });

    await LearningService(db: db).deleteCourse('ended');

    expect((await db.doc('courses/ended').get()).exists, isFalse);
    expect((await db.doc('courses/ended/lessons/one').get()).exists, isFalse);
    expect((await db.doc('courses/ended/reviews/u').get()).exists, isFalse);
    expect((await db.doc('users/u/learning/ended_one').get()).exists, isFalse);
  });

  test('uses the backend deletion endpoint when it is configured', () async {
    final calls = <String>[];
    final service = LearningService(
      db: FakeFirebaseFirestore(),
      api: AccountApi(
        transport: (method, data) async {
          calls.add('$method:${data['courseId']}');
          return {'deleted': true};
        },
      ),
    );

    await service.deleteCourse('course-1');

    expect(calls, ['courseDelete:course-1']);
  });

  test(
    'direct deletion refuses a course with an exam to preserve results',
    () async {
      final db = FakeFirebaseFirestore();
      await db.doc('courses/with-exam').set({'examId': 'exam-1'});
      await db.doc('exams/exam-1').set({'courseId': 'with-exam'});
      await expectLater(
        LearningService(db: db).deleteCourse('with-exam'),
        throwsStateError,
      );
      expect((await db.doc('courses/with-exam').get()).exists, isTrue);
      expect((await db.doc('exams/exam-1').get()).exists, isTrue);
    },
  );

  test('deletes a lesson and its related learning records', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('courses/c').set({'title': 'Khóa học'});
    await db.doc('courses/c/lessons/l').set({'title': 'Bài 1'});
    await db.doc('users/u').set({'role': 'user'});
    await db.doc('users/u/learning/c_l').set({
      'courseId': 'c',
      'lessonId': 'l',
    });

    await LearningService(db: db).deleteLesson('c', 'l');

    expect((await db.doc('courses/c/lessons/l').get()).exists, isFalse);
    expect((await db.doc('users/u/learning/c_l').get()).exists, isFalse);
  });

  test('direct lesson deletion refuses to orphan an attached exam', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('courses/c').set({'title': 'Khóa học'});
    await db.doc('courses/c/lessons/l').set({
      'title': 'Bài 1',
      'examId': 'exam-1',
    });
    await db.doc('exams/exam-1').set({});

    await expectLater(
      LearningService(db: db).deleteLesson('c', 'l'),
      throwsStateError,
    );
    expect((await db.doc('courses/c/lessons/l').get()).exists, isTrue);
    expect((await db.doc('exams/exam-1').get()).exists, isTrue);
  });

  test('uses the backend lesson deletion endpoint when configured', () async {
    final calls = <String>[];
    final service = LearningService(
      db: FakeFirebaseFirestore(),
      api: AccountApi(
        transport: (method, data) async {
          calls.add('$method:${data['courseId']}:${data['lessonId']}');
          return {'deleted': true};
        },
      ),
    );

    await service.deleteLesson('course-1', 'lesson-1');

    expect(calls, ['courseDeleteLesson:course-1:lesson-1']);
  });
}
