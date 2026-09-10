import 'package:e09_elearning/screens/admin/admin_courses_screen.dart';
import 'package:e09_elearning/screens/user/user_courses_screen.dart';
import 'package:e09_elearning/services/learning_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('course lists show authorized data and fit width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FakeFirebaseFirestore();
      final service = LearningService(db: db);
      await db.collection('users').doc('u').set({'classId': 'A'});
      await db.collection('courses').doc('visible').set({
        'title': 'Toán cơ bản',
        'subject': 'Toán',
        'description': 'Bài học đầu tiên',
        'published': true,
        'audience': 'class:A',
      });
      await db.collection('courses').doc('draft').set({
        'title': 'Bản nháp bí mật',
        'subject': 'Toán',
        'published': false,
        'audience': 'all',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: UserCoursesScreen(uid: 'u', service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Toán cơ bản'), findsOneWidget);
      expect(find.text('Bản nháp bí mật'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(home: AdminCoursesScreen(service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bản nháp bí mật'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'không có');
      await tester.pumpAndSettle();
      expect(find.text('Chưa có khóa học phù hợp.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
