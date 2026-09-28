import 'dart:async';

import 'package:e09_elearning/app/cong_ung_dung.dart';
import 'package:e09_elearning/app/ung_dung_hoc_tap_so.dart';
import 'package:e09_elearning/screens/user/cong_bao_tri_hoc_vien.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a persisted account from before maintenance must sign in again', () {
    final epoch = Timestamp.fromDate(DateTime.utc(2026, 9, 27, 9));
    expect(
      sessionPredatesMaintenance(epoch, DateTime.utc(2026, 9, 27, 8), true),
      isTrue,
    );
    expect(
      sessionPredatesMaintenance(epoch, DateTime.utc(2026, 9, 27, 10), true),
      isFalse,
    );
    expect(sessionPredatesMaintenance(epoch, null, true), isTrue);
    expect(sessionPredatesMaintenance(epoch, null, false), isFalse);
  });
  testWidgets(
    'missing server response shows retry and recovers when status arrives',
    (tester) async {
      final status = StreamController<bool>();
      addTearDown(status.close);
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => UserMaintenanceGate(
            statusStream: () => status.stream,
            signedInEvents: const Stream.empty(),
            signOut: () async {},
            child: child!,
          ),
          home: const Scaffold(body: Text('Login form')),
        ),
      );
      await tester.pump(const Duration(seconds: 12));
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Login form'), findsNothing);
      status.add(false);
      await tester.pumpAndSettle();
      expect(find.text('Login form'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'a maintenance cycle missed while offline still invalidates the session',
    () async {
      final signals = await maintenanceSignals(
        Stream.fromIterable([
          {'maintenance': false, 'lastMaintenanceAt': 1},
          {'maintenance': false, 'lastMaintenanceAt': 1},
          {'maintenance': false, 'lastMaintenanceAt': 2},
        ]),
      ).toList();
      expect(signals, [false, false, true]);
    },
  );

  testWidgets(
    'global gate survives replacement, disposes pushed pages and dialogs, and exits Android',
    (tester) async {
      final status = StreamController<bool>();
      addTearDown(status.close);
      var signOuts = 0;
      var disposed = false;
      var ticks = 0;
      final platformCalls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          platformCalls.add(call.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        ElearningApp(
          portal: AppPortal.user,
          homeBuilder: (_) => const SizedBox(),
          appBuilder: (_, child) => UserMaintenanceGate(
            statusStream: () => status.stream,
            signedInEvents: const Stream.empty(),
            signOut: () async {
              signOuts++;
            },
            child: child!,
          ),
          initialHome: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => Builder(
                      builder: (context) => Scaffold(
                        body: TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => _RunningPage(
                                onDispose: () => disposed = true,
                                onTick: () => ticks++,
                              ),
                            ),
                          ),
                          child: const Text('Open exam'),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('Sign in'),
              ),
            ),
          ),
        ),
      );
      status.add(false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open exam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm exam'), findsOneWidget);
      status.add(true);
      await tester.pumpAndSettle();
      expect(signOuts, 1);
      expect(disposed, isTrue);
      expect(find.text('Confirm exam'), findsNothing);
      expect(find.text('Ứng dụng đang được bảo trì'), findsOneWidget);
      final stoppedAt = ticks;
      await tester.pump(const Duration(seconds: 25));
      expect(ticks, stoppedAt);
      status.add(false);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Open exam'), findsNothing);
      await tester.tap(find.text('Xác nhận và thoát'));
      await tester.pumpAndSettle();
      expect(platformCalls, contains('SystemNavigator.pop'));
      expect(signOuts, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'maintenance at startup blocks login and a late authentication is signed out again',
    (tester) async {
      final status = StreamController<bool>();
      final sessions = StreamController<void>();
      addTearDown(status.close);
      addTearDown(sessions.close);
      var signOuts = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => UserMaintenanceGate(
            statusStream: () => status.stream,
            signedInEvents: sessions.stream,
            signOut: () async {
              signOuts++;
            },
            exitApp: () async {},
            child: child!,
          ),
          home: const Scaffold(body: Text('Login form')),
        ),
      );
      expect(find.text('Login form'), findsNothing);
      status.add(true);
      await tester.pumpAndSettle();
      expect(find.text('Login form'), findsNothing);
      expect(signOuts, 1);
      sessions.add(null);
      await tester.pumpAndSettle();
      expect(signOuts, 2);
    },
  );

  testWidgets(
    'signout failure stays blocked and confirmation retries before exit',
    (tester) async {
      final status = StreamController<bool>();
      addTearDown(status.close);
      var attempts = 0;
      var exits = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => UserMaintenanceGate(
            statusStream: () => status.stream,
            signedInEvents: const Stream.empty(),
            signOut: () async {
              if (++attempts == 1) throw StateError('offline');
            },
            exitApp: () async {
              exits++;
            },
            child: child!,
          ),
          home: const Scaffold(body: Text('Private page')),
        ),
      );
      status.add(true);
      await tester.pumpAndSettle();
      expect(exits, 0);
      expect(find.textContaining('Chưa kết thúc được'), findsOneWidget);
      await tester.tap(find.text('Xác nhận và thoát'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(exits, 1);
      expect(find.text('Private page'), findsNothing);
    },
  );

  testWidgets('initial connection failure gives a working retry', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => UserMaintenanceGate(
          statusStream: () => ++attempts == 1
              ? Stream.error(StateError('offline'))
              : Stream.value(false),
          signedInEvents: const Stream.empty(),
          signOut: () async {},
          child: child!,
        ),
        home: const Scaffold(body: Text('Login form')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Login form'), findsNothing);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Login form'), findsOneWidget);
  });

  testWidgets('maintenance notice scrolls at narrow width and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 480),
            textScaler: TextScaler.linear(2),
          ),
          child: UserMaintenanceGate(
            statusStream: () => Stream.value(true),
            signedInEvents: const Stream.empty(),
            signOut: () async {},
            exitApp: () async {},
            child: child!,
          ),
        ),
        home: const SizedBox(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Xác nhận và thoát'));
    expect(tester.takeException(), isNull);
  });
}

class _RunningPage extends StatefulWidget {
  const _RunningPage({required this.onDispose, required this.onTick});
  final VoidCallback onDispose;
  final VoidCallback onTick;
  @override
  State<_RunningPage> createState() => _RunningPageState();
}

class _RunningPageState extends State<_RunningPage> {
  late final Timer timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => widget.onTick());
  }

  @override
  void dispose() {
    timer.cancel();
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TextButton(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(title: Text('Confirm exam')),
      ),
      child: const Text('Open dialog'),
    ),
  );
}
