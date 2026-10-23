import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/app/khoi_dong_ung_dung.dart';
import 'package:e09_elearning/screens/user/man_hinh_khoi_dong_hoc_vien.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:e09_elearning/widgets/danh_muc_khoa_hoc_hoc_vien.dart';
import 'package:e09_elearning/widgets/thong_bao_loi.dart';
import 'package:e09_elearning/widgets/tien_ich_giao_dien_hoc_tap.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _data(BuildContext context, AsyncSnapshot<int> snapshot) =>
    Text(snapshot.hasData ? 'Dữ liệu ${snapshot.data}' : 'Đang tải');

void main() {
  testWidgets('Firebase errors can be retried with a new subscription', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReloadableStreamBuilder<int>(
            feature: 'Tải khóa học',
            streamFactory: () => ++attempts == 1
                ? Stream.error(
                    FirebaseException(
                      plugin: 'cloud_firestore',
                      code: 'unavailable',
                    ),
                  )
                : Stream.value(7),
            builder: _data,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tải được dữ liệu'), findsOneWidget);
    await tester.tap(find.text('Tải lại'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Dữ liệu 7'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final onListen in [false, true]) {
    testWidgets(
      'synchronous lesson failure can be retried (listen=$onListen)',
      (tester) async {
        final db = FakeFirebaseFirestore();
        await db.doc('courses/c').set({'title': 'Khóa học'});
        await db.doc('courses/c/lessons/l').set({'title': 'Bài học đã tải'});
        final service = _SynchronousLessons(db, onListen: onListen);
        final courses = (await db.collection('courses').get()).docs;
        Widget catalog() => MaterialApp(
          home: Scaffold(
            body: LearnerCourseCatalog(
              courses: courses,
              service: service,
              builder: (entries) =>
                  Text(entries.single.lessons.single.data()['title'] as String),
            ),
          ),
        );

        await tester.pumpWidget(catalog());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Không tải được dữ liệu'), findsOneWidget);
        await tester.pumpWidget(catalog());
        await tester.pumpAndSettle();
        expect(service.attempts, 1);
        await tester.tap(find.text('Tải lại'));
        await tester.pumpAndSettle();
        expect(service.attempts, 2);
        expect(find.text('Bài học đã tải'), findsOneWidget);
        await tester.pump(const Duration(seconds: 21));
        expect(find.text('Không tải được dữ liệu'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('changing the catalog service clears the previous load state', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.doc('courses/c').set({'title': 'Khóa học'});
    await db.doc('courses/c/lessons/l').set({'title': 'Bài học đã tải'});
    final courses = (await db.collection('courses').get()).docs;
    Widget catalog(LearningService service) => MaterialApp(
      home: Scaffold(
        body: LearnerCourseCatalog(
          courses: courses,
          service: service,
          builder: (entries) =>
              Text(entries.single.lessons.single.data()['title'] as String),
        ),
      ),
    );
    await tester.pumpWidget(catalog(_SynchronousLessons(db)));
    await tester.pumpAndSettle();
    expect(find.text('Không tải được dữ liệu'), findsOneWidget);
    await tester.pumpWidget(catalog(LearningService(db: db)));
    await tester.pumpAndSettle();
    expect(find.text('Bài học đã tải'), findsOneWidget);
    await tester.pump(const Duration(seconds: 21));
    expect(find.text('Tải lại'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('removing a course clears its synchronous query failure', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.doc('courses/broken').set({'title': 'Khóa lỗi'});
    await db.doc('courses/ok').set({'title': 'Khóa tốt'});
    await db.doc('courses/ok/lessons/l').set({'title': 'Bài học'});
    final courses = (await db.collection('courses').get()).docs;
    final service = _SynchronousLessons(db);
    Widget catalog(List<LearnerCourseDocument> docs) => MaterialApp(
      home: Scaffold(
        body: LearnerCourseCatalog(
          courses: docs,
          service: service,
          builder: (entries) => Text(
            entries.map((entry) => entry.course.data()['title']).join(','),
          ),
        ),
      ),
    );
    await tester.pumpWidget(catalog(courses));
    await tester.pumpAndSettle();
    expect(find.text('Không tải được dữ liệu'), findsOneWidget);
    await tester.pumpWidget(
      catalog(courses.where((course) => course.id == 'ok').toList()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Khóa tốt'), findsOneWidget);
    await tester.pump(const Duration(seconds: 21));
    expect(find.text('Không tải được dữ liệu'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a silent initial load times out and recovers on retry', (
    tester,
  ) async {
    final silent = StreamController<int>.broadcast();
    addTearDown(silent.close);
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReloadableStreamBuilder<int>(
            feature: 'Tải dữ liệu',
            streamFactory: () =>
                ++attempts == 1 ? silent.stream : Stream.value(2),
            builder: _data,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 21));
    expect(find.text('Không tải được dữ liệu'), findsOneWidget);
    await tester.tap(find.text('Tải lại'));
    await tester.pumpAndSettle();
    expect(find.text('Dữ liệu 2'), findsOneWidget);
  });

  testWidgets('a valid empty result does not time out during a quiet stream', (
    tester,
  ) async {
    final data = StreamController<int>.broadcast();
    addTearDown(data.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReloadableStreamBuilder<int>(
            stream: data.stream,
            feature: 'Tải dữ liệu',
            isUsableData: (value) => value >= 0,
            builder: _data,
          ),
        ),
      ),
    );
    data.add(-1);
    await tester.pump();
    expect(find.text('Đang tải'), findsOneWidget);
    data.add(0);
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Dữ liệu 0'), findsOneWidget);
    expect(find.text('Tải lại'), findsNothing);
  });

  testWidgets('LearningList retries the same Firestore query stream', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.doc('courses/c').set({'title': 'Khóa học đã tải'});
    final snapshot = await db.collection('courses').get();
    var subscriptions = 0;
    late StreamController<QuerySnapshot<Map<String, dynamic>>> stream;
    stream = StreamController.broadcast(
      onListen: () {
        subscriptions++;
        scheduleMicrotask(() {
          if (subscriptions == 1) {
            stream.addError(
              FirebaseException(
                plugin: 'cloud_firestore',
                code: 'permission-denied',
              ),
            );
          } else {
            stream.add(snapshot);
          }
        });
      },
    );
    addTearDown(stream.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningList(
            stream: stream.stream,
            builder: (docs) => Text(docs.single.data()['title'] as String),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tải lại'));
    await tester.pumpAndSettle();
    expect(subscriptions, 2);
    expect(find.text('Khóa học đã tải'), findsOneWidget);
  });

  testWidgets('course catalog restarts failed lesson queries', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.doc('courses/c').set({'title': 'Khóa học'});
    await db.doc('courses/c/lessons/l').set({'title': 'Bài học đã tải'});
    final service = _RetryLessons(db);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearnerCourseCatalog(
            courses: (await db.collection('courses').get()).docs,
            service: service,
            builder: (courses) =>
                Text(courses.single.lessons.single.data()['title'] as String),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tải lại'));
    await tester.pumpAndSettle();
    expect(service.attempts, 2);
    expect(find.text('Bài học đã tải'), findsOneWidget);
  });

  testWidgets('Firebase initialization failure has a working retry', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      FirebaseStartupGate(
        app: const MaterialApp(home: Text('Ứng dụng sẵn sàng')),
        initialize: () async {
          if (++attempts == 1) {
            throw FirebaseException(plugin: 'core', code: 'unavailable');
          }
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ứng dụng sẵn sàng'), findsNothing);
    await tester.tap(find.text('Tải lại'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Ứng dụng sẵn sàng'), findsOneWidget);
  });

  testWidgets(
    'Firebase initialization cannot leave an endless loading screen',
    (tester) async {
      final pending = Completer<void>();
      var attempts = 0;
      await tester.pumpWidget(
        FirebaseStartupGate(
          app: const MaterialApp(home: Text('Đã kết nối')),
          initialize: () => ++attempts == 1 ? pending.future : Future.value(),
        ),
      );
      await tester.pump(const Duration(seconds: 21));
      expect(find.text('Không tải được dữ liệu'), findsOneWidget);
      await tester.tap(find.text('Tải lại'));
      await tester.pumpAndSettle();
      expect(find.text('Đã kết nối'), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('optional preloading cannot trap learners on the splash screen', (
    tester,
  ) async {
    final pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: UserSplashScreen(
          prepare: () => pending.future,
          nextBuilder: (_) => const Scaffold(body: Text('Trang học tập')),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 13));
    await tester.pumpAndSettle();
    expect(find.text('Trang học tập'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _RetryLessons extends LearningService {
  _RetryLessons(FirebaseFirestore db) : super(db: db);
  var attempts = 0;

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> lessons(String courseId) =>
      ++attempts == 1
      ? Stream.error(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        )
      : super.lessons(courseId);
}

class _SynchronousLessons extends LearningService {
  _SynchronousLessons(FirebaseFirestore db, {this.onListen = false})
    : super(db: db);

  final bool onListen;
  var attempts = 0;

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> lessons(String courseId) {
    if (++attempts > 1) return super.lessons(courseId);
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );
    if (onListen) return _ThrowOnListen(error);
    throw error;
  }
}

class _ThrowOnListen<T> extends Stream<T> {
  _ThrowOnListen(this.error);

  final Object error;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => throw error;
}
