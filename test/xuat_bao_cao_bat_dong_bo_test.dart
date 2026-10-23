import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/screens/admin/bao_cao_thong_ke.dart';
import 'package:e09_elearning/services/du_lieu/dich_vu_firestore.dart';
import 'package:e09_elearning/services/nguon_du_lieu_bao_cao_quan_tri.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Hold one query open to exercise navigation while the export is awaiting data.
// ignore: subtype_of_sealed_class
class _PendingCourses implements CollectionReference<Map<String, dynamic>> {
  final pending = Completer<QuerySnapshot<Map<String, dynamic>>>();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #where) return this;
    if (invocation.memberName == #get) return pending.future;
    return super.noSuchMethod(invocation);
  }
}

class _PendingFirestore implements FirebaseFirestore {
  final courses = _PendingCourses();

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    if (path != 'courses') throw StateError('Unexpected query: $path');
    return courses;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PendingReportService extends FirestoreService {
  _PendingReportService(FakeFirebaseFirestore db) : super(firestore: db);

  final pendingDb = _PendingFirestore();

  @override
  FirebaseFirestore get db => pendingDb;
}

void main() {
  for (final pressBack in [false, true]) {
    testWidgets('failed export owns its progress dialog (back: $pressBack)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FakeFirebaseFirestore();
      final empty = await db.collection('empty').get();
      final service = _PendingReportService(db);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: AdminReportScreen(
            embedded: true,
            service: service,
            reportData: AdminReportData.fromSnapshots(
              users: empty,
              courses: empty,
              exams: empty,
              attempts: empty,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xuất Excel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xuất Excel').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      if (pressBack) unawaited(navigator.currentState!.maybePop());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final progressStayedOpen = find
          .byType(CircularProgressIndicator)
          .evaluate()
          .isNotEmpty;
      unawaited(
        showDialog<void>(
          context: navigator.currentContext!,
          builder: (_) => const AlertDialog(title: Text('Thông tin mới')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      service.pendingDb.courses.pending.completeError(StateError('offline'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(progressStayedOpen, isTrue);
      expect(find.text('Thông tin mới'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Không xuất được Excel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
