import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:e09_elearning/app/app_theme.dart';
import 'package:e09_elearning/widgets/admin_ui.dart';
import 'package:e09_elearning/models/account_identity.dart';
import 'package:e09_elearning/screens/admin/admin_account_screen.dart';
import 'package:e09_elearning/screens/admin/admin_classes_screen.dart';
import 'package:e09_elearning/screens/admin/admin_courses_screen.dart';
import 'package:e09_elearning/screens/admin/admin_notifications_screen.dart';
import 'package:e09_elearning/services/du_lieu/firestore_service.dart';
import 'package:e09_elearning/services/nghiep_vu/learning_service.dart';

void main() {
  for (final width in [760.0, 1440.0]) {
    testWidgets(
      'all secondary admin pages retain navigation and red headers at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        AccountSession.current = const AccountIdentity(
          id: 'root',
          role: 'super_admin',
        );
        addTearDown(() => AccountSession.current = null);
        final db = FakeFirebaseFirestore();
        final learning = LearningService(db: db);
        final pages = <Widget>[
          AdminAccountScreen(service: FirestoreService(firestore: db)),
          AdminClassesScreen(service: learning),
          AdminCoursesScreen(service: learning),
          AdminNotificationsScreen(service: learning),
        ];
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            theme: AdminUi.theme,
            navigatorKey: navigator,
            home: pages.first,
          ),
        );
        await tester.pumpAndSettle();
        for (final page in pages.skip(1)) {
          navigator.currentState!.push(
            MaterialPageRoute<void>(builder: (_) => page),
          );
          await tester.pumpAndSettle();
          expect(find.byType(NavigationRail), findsOneWidget);
          final bar = tester.widget<AppBar>(find.byType(AppBar));
          expect(bar.backgroundColor, AppTheme.red);
          expect(bar.foregroundColor, Colors.white);
          expect((bar.title! as Text).style?.color, Colors.white);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
