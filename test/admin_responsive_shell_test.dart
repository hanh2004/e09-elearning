import 'package:e09_elearning/models/account_identity.dart';
import 'package:e09_elearning/screens/admin/admin_home_screen.dart';
import 'package:e09_elearning/screens/admin/admin_responsive_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AccountSession.current = null);

  test('admin tabs switch without route animation', () {
    final route = adminTabRoute(const SizedBox());
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
  });

  for (final size in [const Size(390, 844), const Size(1200, 800)]) {
    testWidgets('admin navigation adapts at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AccountSession.current = const AccountIdentity(
        id: 'root',
        role: 'super_admin',
      );
      await tester.pumpWidget(const MaterialApp(home: AdminHomeScreen()));
      await tester.pumpAndSettle();
      if (size.width >= 900) {
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(BottomNavigationBar), findsNothing);
      } else {
        expect(find.byType(NavigationRail), findsNothing);
        expect(find.byType(BottomNavigationBar), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
