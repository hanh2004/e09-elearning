import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:e09_elearning/widgets/tien_ich_giao_dien_hoc_tap.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Metadata extends Fake implements SnapshotMetadata {
  _Metadata(this.isFromCache);
  @override
  final bool isFromCache;
}

class _EmptySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _EmptySnapshot({required bool fromCache}) : metadata = _Metadata(fromCache);
  @override
  final SnapshotMetadata metadata;
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];
}

// A fake query lets the test emit cache/server metadata without a real network.
// ignore: subtype_of_sealed_class
class _Query extends Fake implements Query<Map<String, dynamic>> {
  final controller =
      StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
  final includedMetadata = <bool>[];
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    includedMetadata.add(includeMetadataChanges);
    return controller.stream;
  }
}

void main() {
  testWidgets(
    'empty cache waits for the server before showing an empty library',
    (tester) async {
      final query = _Query();
      addTearDown(query.controller.close);
      final service = LearningService(db: FakeFirebaseFirestore());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearningList(
              stream: service.watchQuery(query),
              builder: (_) => const Text('Máy chủ xác nhận danh sách rỗng'),
            ),
          ),
        ),
      );
      expect(query.includedMetadata, [true]);
      query.controller.add(_EmptySnapshot(fromCache: true));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Máy chủ xác nhận danh sách rỗng'), findsNothing);

      query.controller.add(_EmptySnapshot(fromCache: false));
      await tester.pump();
      expect(find.text('Máy chủ xác nhận danh sách rỗng'), findsOneWidget);
      await tester.pump(const Duration(seconds: 21));
      expect(find.text('Tải lại'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('empty cache without a server response times out with retry', (
    tester,
  ) async {
    final query = _Query();
    addTearDown(query.controller.close);
    final service = LearningService(db: FakeFirebaseFirestore());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningList(
            stream: service.watchQuery(query),
            builder: (_) => const Text('Danh sách rỗng'),
          ),
        ),
      ),
    );
    query.controller.add(_EmptySnapshot(fromCache: true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    expect(find.text('Không tải được dữ liệu'), findsOneWidget);
    expect(find.text('Tải lại'), findsOneWidget);
    expect(find.text('Danh sách rỗng'), findsNothing);
    await tester.tap(find.text('Tải lại'));
    query.controller.add(_EmptySnapshot(fromCache: false));
    await tester.pumpAndSettle();
    expect(find.text('Danh sách rỗng'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
