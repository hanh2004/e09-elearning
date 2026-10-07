import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/models/dinh_danh_tai_khoan.dart';
import 'package:e09_elearning/models/bieu_mau_bai_hoc.dart';
import 'package:e09_elearning/screens/admin/quan_ly_tin_tuc.dart';
import 'package:e09_elearning/screens/admin/forms/bieu_mau_bai_hoc.dart';
import 'package:e09_elearning/screens/user/tin_tuc_hoc_vien.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _WidgetSaveService extends LearningService {
  _WidgetSaveService({required super.db});

  @override
  Future<void> saveContent(
    String actorId,
    DocumentReference<Map<String, dynamic>> reference,
    Map<String, dynamic> data,
  ) async {
    final previous = (await reference.get()).data() ?? <String, dynamic>{};
    final updates = Map<String, dynamic>.from(data)..remove('chapter');
    final saved = {...previous, ...updates};
    if (reference.parent.id == 'news' &&
        updates['published'] == true &&
        previous['publishedAt'] == null) {
      saved['publishedAt'] = Timestamp.now();
    }
    saved['updatedBy'] = actorId;
    saved['updatedAt'] = Timestamp.now();
    await reference.set(saved, SetOptions(merge: true));
  }
}

void main() {
  tearDown(() => AccountSession.current = null);

  test(
    'lessons default to study only and require an exam for the second mode',
    () {
      final fields = {...LessonForm.initialValues({}), 'content': 'Nội dung'};
      expect(
        LessonForm.toFirestore(fields, previous: {})['learningMode'],
        'study_only',
      );
      fields['learningMode'] = LessonForm.studyExamLabel;
      expect(
        () => LessonForm.toFirestore(fields, previous: {}),
        throwsArgumentError,
      );
      fields['examId'] = 'exam-1';
      expect(LessonForm.toFirestore(fields, previous: {})['examId'], 'exam-1');
      fields['learningMode'] = LessonForm.studyOnlyLabel;
      expect(LessonForm.toFirestore(fields, previous: {})['examId'], '');
    },
  );

  testWidgets('lesson editor inherits the course mode and exam', (
    tester,
  ) async {
    AccountSession.current = const AccountIdentity(
      id: 'root',
      role: 'super_admin',
    );
    final db = FakeFirebaseFirestore();
    await db.doc('courses/c').set({
      'title': 'Khóa học',
      'published': false,
      'learningMode': 'study_exam',
      'examId': 'e',
    });
    await db.doc('courses/c/lessons/l').set({
      'title': 'Bài học',
      'chapter': 'Chương 1',
      'order': 1,
      'type': 'text',
      'content': 'Nội dung',
      'coverUrl': 'https://example.org/cover.png',
    });
    await db.doc('exams/e').set({'title': 'Kiểm tra cuối bài'});
    final course = (await db.collection('courses').get()).docs.single;
    final lesson =
        (await course.reference.collection('lessons').get()).docs.single;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showLessonEditor(
                context,
                service: _WidgetSaveService(db: db),
                course: course,
                lesson: lesson,
              ),
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    expect(find.text('Bài kiểm tra sau khi học'), findsNothing);
    expect(find.text('Loại bài học'), findsNothing);
    expect(find.text('Bài kiểm tra sau khi học'), findsNothing);
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(
      (await lesson.reference.get()).data()?['learningMode'],
      'study_exam',
    );
    expect((await lesson.reference.get()).data()?['examId'], 'e');
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 1200.0]) {
    testWidgets(
      'news editor saves and publishes, reader hides drafts at $width',
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
        final service = _WidgetSaveService(db: db);
        await tester.pumpWidget(
          MaterialApp(home: AdminNewsScreen(service: service)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'news admin screen');
        await tester.tap(find.text('Thêm tin tức'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'news editor');
        await tester.enterText(find.byType(TextFormField).at(0), 'Tin mới E09');
        await tester.enterText(
          find.byType(TextFormField).at(2),
          'Nội dung tin đã đăng',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lưu'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'after saving news');
        final saved = (await db.collection('news').get()).docs.single.data();
        expect(saved['published'], true);
        expect(saved['content'], 'Nội dung tin đã đăng');
        expect(saved['updatedBy'], 'root');
        await db.doc('news/draft').set({
          'title': 'Tin chưa đăng',
          'content': 'Nháp',
          'published': false,
          'updatedAt': Timestamp.now(),
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: UserNews(service: service)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'learner news list');
        expect(find.text('Tin mới E09'), findsOneWidget);
        expect(find.text('Tin chưa đăng'), findsNothing);
        await tester.tap(find.text('Tin mới E09'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'news detail');
        expect(find.text('Nội dung tin đã đăng'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('root can cancel and confirm deleting a news article', (
    tester,
  ) async {
    AccountSession.current = const AccountIdentity(
      id: 'root',
      role: 'super_admin',
    );
    final db = FakeFirebaseFirestore();
    await db.doc('news/test-draft').set({
      'title': '[KIỂM THỬ] Tin nháp cần xóa',
      'summary': 'Tin dùng để kiểm thử xóa',
      'content': 'Nội dung kiểm thử',
      'category': 'Thông báo',
      'published': false,
      'updatedAt': Timestamp.now(),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: AdminNewsScreen(service: _WidgetSaveService(db: db)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Xóa tin tức'), findsOneWidget);
    await tester.tap(find.byTooltip('Xóa tin tức'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Xóa vĩnh viễn tin tức "[KIỂM THỬ] Tin nháp cần xóa"? '
        'Không thể hoàn tác.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect((await db.doc('news/test-draft').get()).exists, isTrue);

    await tester.tap(find.byTooltip('Xóa tin tức'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa vĩnh viễn'));
    await tester.pumpAndSettle();
    expect((await db.doc('news/test-draft').get()).exists, isFalse);
    expect(find.text('Đã xóa tin tức.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('news rows keep image identity when Firestore reorders them', (
    tester,
  ) async {
    AccountSession.current = const AccountIdentity(
      id: 'root',
      role: 'super_admin',
    );
    final db = FakeFirebaseFirestore();
    final older = Timestamp.fromDate(DateTime(2026, 9, 1));
    await db.doc('news/story-a').set({
      'title': 'Tin A',
      'summary': '',
      'content': 'Nội dung A',
      'coverUrl': 'https://example.org/story-a.png',
      'published': true,
      'updatedAt': older,
    });
    await db.doc('news/story-b').set({
      'title': 'Tin B',
      'summary': '',
      'content': 'Nội dung B',
      'coverUrl': 'https://example.org/story-b.png',
      'published': true,
      'updatedAt': Timestamp.fromDate(DateTime(2026, 9, 2)),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: AdminNewsScreen(service: _WidgetSaveService(db: db)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('news:story-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('news:story-b')), findsOneWidget);

    await db.doc('news/story-a').update({
      'updatedAt': Timestamp.fromDate(DateTime(2026, 9, 3)),
    });
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('news:story-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('news:story-b')), findsOneWidget);
    for (final pair in {
      'news:story-a': 'https://example.org/story-a.png',
      'news:story-b': 'https://example.org/story-b.png',
    }.entries) {
      final imageFinder = find.descendant(
        of: find.byKey(ValueKey(pair.key)),
        matching: find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is NetworkImage,
        ),
      );
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect((image.image as NetworkImage).url, pair.value);
    }
    expect(tester.takeException(), isNull);
  });
}
