import 'dart:io';

import 'package:e09_elearning/app/app_portal.dart';
import 'package:e09_elearning/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    for (final portal in AppPortal.values) {
      testWidgets('${portal.name} login fits $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          PortalScope(
            portal: portal,
            homeBuilder: (_) => const SizedBox(),
            child: const MaterialApp(home: LoginScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(portal.loginLabel), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('each portal accepts only its explicit roles', () {
    for (final role in ['admin', 'Admin', ' ADMIN ', 'super_admin']) {
      expect(AppPortal.admin.acceptsRole(role), isTrue);
      expect(AppPortal.user.acceptsRole(role), isFalse);
    }
    for (final role in ['user', 'User', 'Học viên', ' học viên ']) {
      expect(AppPortal.user.acceptsRole(role), isTrue);
      expect(AppPortal.admin.acceptsRole(role), isFalse);
    }
    for (final role in [null, '', 'Giáo viên', 'owner', 1]) {
      expect(AppPortal.user.acceptsRole(role), isFalse);
      expect(AppPortal.admin.acceptsRole(role), isFalse);
    }
  });

  test('entry points have disjoint screen dependency graphs', () {
    Set<String> importsOf(String entry) {
      final visited = <String>{};
      void visit(Uri uri) {
        final path = uri.toFilePath().replaceAll('\\', '/');
        if (!visited.add(path)) return;
        final source = File.fromUri(uri).readAsStringSync();
        final imports = RegExp("(?:import|export)\\s+'([^']+)'");
        for (final match in imports.allMatches(source)) {
          final target = match.group(1)!;
          if (!target.contains(':')) visit(uri.resolve(target));
        }
      }

      visit(File(entry).absolute.uri);
      return visited;
    }

    final user = importsOf('lib/main_user.dart');
    final admin = importsOf('lib/main_admin.dart');
    expect(user.any((path) => path.contains('/screens/admin/')), isFalse);
    expect(admin.any((path) => path.contains('/screens/user/')), isFalse);
    expect(importsOf('lib/main.dart').containsAll(user), isTrue);
  });

  for (final portal in AppPortal.values) {
    for (final role in [
      'user',
      'Học viên',
      'Admin',
      'admin',
      null,
      'Giáo viên',
    ]) {
      testWidgets('${portal.name} login with role $role', (tester) async {
        await tester.pumpWidget(
          PortalScope(
            portal: portal,
            homeBuilder: (_) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginScreen(),
                    ),
                    (_) => false,
                  ),
                  child: const Text('Signed in'),
                ),
              ),
            ),
            child: MaterialApp(
              home: LoginScreen(
                authenticate: (_, _) async => {'id': 'test-user', 'role': role},
              ),
            ),
          ),
        );
        await tester.enterText(find.byType(TextFormField).at(0), 'test');
        await tester.enterText(find.byType(TextFormField).at(1), 'password');
        await tester.tap(find.text('ĐĂNG NHẬP'));
        await tester.pumpAndSettle();
        if (portal.acceptsRole(role)) {
          expect(find.text('Signed in'), findsOneWidget);
          await tester.tap(find.text('Signed in'));
          await tester.pumpAndSettle();
          expect(find.text(portal.loginLabel), findsOneWidget);
        } else {
          expect(find.text('Signed in'), findsNothing);
          expect(
            find.text('Tên đăng nhập hoặc mật khẩu không chính xác!'),
            findsOneWidget,
          );
          expect(find.textContaining('không được phép'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('failed authentication remains on login', (tester) async {
    await tester.pumpWidget(
      PortalScope(
        portal: AppPortal.user,
        homeBuilder: (_) => const Text('Signed in'),
        child: MaterialApp(
          home: LoginScreen(authenticate: (_, _) async => null),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'test');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.tap(find.text('ĐĂNG NHẬP'));
    await tester.pumpAndSettle();
    expect(find.text('Signed in'), findsNothing);
    expect(
      find.text('Tên đăng nhập hoặc mật khẩu không chính xác!'),
      findsOneWidget,
    );
  });

  testWidgets('maintenance blocks User login before authentication', (
    tester,
  ) async {
    var authenticationCalled = false;
    await tester.pumpWidget(
      PortalScope(
        portal: AppPortal.user,
        homeBuilder: (_) => const Text('Signed in'),
        child: MaterialApp(
          home: LoginScreen(
            maintenanceChecker: () async => true,
            authenticate: (_, _) async {
              authenticationCalled = true;
              return {'id': 'user', 'role': 'user'};
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'test');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.text('ĐĂNG NHẬP'));
    await tester.pumpAndSettle();
    expect(authenticationCalled, isFalse);
    expect(find.textContaining('Ứng dụng đang được cập nhật'), findsOneWidget);
  });

  testWidgets('maintenance does not block Admin portal', (tester) async {
    await tester.pumpWidget(
      PortalScope(
        portal: AppPortal.admin,
        homeBuilder: (_) => const Text('Admin signed in'),
        child: MaterialApp(
          home: LoginScreen(
            maintenanceChecker: () async => true,
            authenticate: (_, _) async => {'id': 'admin', 'role': 'admin'},
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.text('ĐĂNG NHẬP'));
    await tester.pumpAndSettle();
    expect(find.text('Admin signed in'), findsOneWidget);
  });
}
