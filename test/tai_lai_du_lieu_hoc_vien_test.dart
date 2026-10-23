import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/models/bai_viet_tin_tuc.dart';
import 'package:e09_elearning/screens/user/lich_su_bai_kiem_tra.dart';
import 'package:e09_elearning/screens/user/cac_khoa_hoc.dart';
import 'package:e09_elearning/screens/user/thong_bao_hoc_vien.dart';
import 'package:e09_elearning/services/ket_noi_api/dich_vu_bai_kiem_tra_bao_mat.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_tin_tuc.dart';
import 'package:e09_elearning/widgets/khung_tin_tuc_trang_chu.dart';
import 'package:e09_elearning/widgets/thong_bao_loi.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecoveringNewsService extends NewsService {
  _RecoveringNewsService() : super(FakeFirebaseFirestore());

  int loads = 0;

  @override
  Stream<List<NewsArticle>> published() => ++loads == 1
      ? Stream.error(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        )
      : Stream.value([
          NewsArticle('restored', {
            'title': 'Tin nổi bật đã tải',
            'coverUrl': 'icon:book',
          }),
        ]);
}

class _RecoveringLessonService extends LearningService {
  _RecoveringLessonService({required super.db});

  var loads = 0;

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> lessons(String courseId) =>
      ++loads == 1
      ? Stream.error(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        )
      : super.lessons(courseId);
}

void main() {
  testWidgets('a course opened from a notification offers a working retry', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final service = _RecoveringLessonService(db: db);
    final sentAt = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(minutes: 1)),
    );
    await db.doc('users/u').set({'classId': 'A'});
    await db.doc('courses/c').set({
      'title': 'Khóa phục hồi',
      'learningMode': 'study_only',
      'published': true,
      'publishedAt': sentAt,
    });
    await db.doc('courses/c/lessons/l').set({'title': 'Nội dung học'});
    await db.doc('learning_notifications/n').set({
      'title': 'Khóa học mới: Khóa phục hồi',
      'courseId': 'c',
      'audience': 'all',
      'sendAt': sentAt,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: UserNotificationsScreen(uid: 'u', service: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khóa học mới: Khóa phục hồi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HỌC NGAY'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Mở khóa học từ thông báo đang bị lỗi'),
      findsOneWidget,
    );
    expect(service.loads, 1);

    await tester.tap(find.text('Tải lại'));
    await tester.pumpAndSettle();
    expect(find.byType(UserLessonsScreen), findsOneWidget);
    expect(service.loads, greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('home banner reports a failed load and retries the news source', (
    tester,
  ) async {
    final service = _RecoveringNewsService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeNewsBanner(service: service, onStudy: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppErrorNotice), findsOneWidget);
    expect(find.text('Khám phá khóa học'), findsNothing);

    await tester.tap(find.text('Tải lại'));
    await tester.pumpAndSettle();
    expect(service.loads, 2);
    expect(find.text('Tin nổi bật đã tải'), findsOneWidget);
    expect(find.byType(AppErrorNotice), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('exam history retries a failed backend request', (tester) async {
    var loads = 0;
    final service = SecureExamService(
      transport: (_, _) async {
        if (++loads == 1) {
          throw FirebaseException(
            plugin: 'cloud_functions',
            code: 'unavailable',
          );
        }
        return {'runs': []};
      },
    );
    await tester.pumpWidget(
      MaterialApp(home: ExamHistoryScreen(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppErrorNotice), findsOneWidget);

    await tester.tap(find.text('Tải lại'));
    await tester.pumpAndSettle();
    expect(loads, 2);
    expect(
      find.text('Chưa có lịch sử kiểm tra đã hoàn thành.'),
      findsOneWidget,
    );
    expect(find.byType(AppErrorNotice), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('exam history stops waiting and can retry a stalled request', (
    tester,
  ) async {
    var loads = 0;
    final stalled = Completer<Map<String, dynamic>>();
    final service = SecureExamService(
      transport: (_, _) =>
          ++loads == 1 ? stalled.future : Future.value({'runs': []}),
    );
    await tester.pumpWidget(
      MaterialApp(home: ExamHistoryScreen(service: service)),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();
    expect(find.byType(AppErrorNotice), findsOneWidget);

    await tester.tap(find.text('Tải lại'));
    await tester.pumpAndSettle();
    expect(loads, 2);
    expect(
      find.text('Chưa có lịch sử kiểm tra đã hoàn thành.'),
      findsOneWidget,
    );
    expect(find.byType(AppErrorNotice), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
