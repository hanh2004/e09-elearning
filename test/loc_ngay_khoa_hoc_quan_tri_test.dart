import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e09_elearning/screens/admin/quan_ly_khoa_hoc.dart';
import 'package:e09_elearning/services/nghiep_vu/dich_vu_hoc_tap.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('course list filters by the selected day', (tester) async {
    final db = FakeFirebaseFirestore();
    final now = DateTime.now();
    await db.doc('courses/today').set({
      'title': 'Hôm nay',
      'subject': 'Nghiệp vụ',
      'published': true,
      'startsAt': Timestamp.fromDate(now),
      'coverUrl': 'icon:book',
    });
    await db.doc('courses/old').set({
      'title': 'Cũ',
      'subject': 'Nghiệp vụ',
      'published': true,
      'startsAt': Timestamp.fromDate(DateTime(2020, 1, 2)),
      'coverUrl': 'icon:book',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: AdminCoursesScreen(service: LearningService(db: db)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Cũ'), findsOneWidget);
    await tester.tap(find.text('Ngày'));
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Cũ'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
