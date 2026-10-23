// KHỞI TẠO / GIAO DIỆN: Khởi tạo Firebase, kết nối emulator khi chạy local và mở ứng dụng.
// Các màn hình import tệp này sẽ dùng chung thay đổi.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../widgets/thong_bao_loi.dart';
import 'cau_hinh_ung_dung.dart';
import 'chu_de_ung_dung.dart';

Future<void> bootstrap(
  Widget app, {
  bool useIsolatedAdminWebSessions = false,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final initializer = _FirebaseInitializer(useIsolatedAdminWebSessions);
  runApp(FirebaseStartupGate(app: app, initialize: initializer.call));
}

/// Có giao diện tải lại ngay cả khi Firebase chưa khởi tạo được.
class FirebaseStartupGate extends StatefulWidget {
  const FirebaseStartupGate({
    super.key,
    required this.app,
    required this.initialize,
    this.timeout = const Duration(seconds: 20),
  });

  final Widget app;
  final Future<void> Function() initialize;
  final Duration timeout;

  @override
  State<FirebaseStartupGate> createState() => _FirebaseStartupGateState();
}

class _FirebaseStartupGateState extends State<FirebaseStartupGate> {
  bool _loading = false;
  bool _ready = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.initialize().timeout(widget.timeout);
      if (mounted) setState(() => _ready = true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _ready
      ? widget.app
      : MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: Scaffold(
            body: SafeArea(
              child: _error != null
                  ? AppErrorNotice(
                      error: _error!,
                      feature: 'Kết nối dữ liệu Firebase',
                      fallbackAction: 'Kiểm tra Internet rồi bấm Tải lại. Nếu chưa kết nối được, hãy đóng và mở lại ứng dụng.',
                      padding: const EdgeInsets.all(24),
                      onRetry: _start,
                    )
                  : const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 220,
                            child: LinearProgressIndicator(),
                          ),
                          SizedBox(height: 16),
                          Text('Đang kết nối dữ liệu…'),
                        ],
                      ),
                    ),
            ),
          ),
        );
}

class _FirebaseInitializer {
  _FirebaseInitializer(this.isolatedAdmin);

  final bool isolatedAdmin;
  Future<void>? _pending;
  bool _initialized = false;
  bool _storage = false;
  bool _auth = false;
  bool _firestore = false;
  bool _functions = false;
  bool _persistence = false;
  bool _clearedAdmin = false;

  Future<void> call() => _pending ??= _initialize().whenComplete(() {
    _pending = null;
  });

  Future<void> _initialize() async {
    const emulator = AppConfig.emulatorHost;
    final options = emulator.isEmpty
        ? DefaultFirebaseOptions.currentPlatform
        : const FirebaseOptions(
            apiKey: 'demo-key',
            appId: '1:123456:web:demo',
            messagingSenderId: '123456',
            projectId: 'demo-e09',
            authDomain: 'demo-e09.firebaseapp.com',
            storageBucket: 'demo-e09.appspot.com',
          );
    if (!_initialized) {
      final app = Firebase.apps.any((app) => app.name == '[DEFAULT]')
          ? Firebase.app()
          : await Firebase.initializeApp(options: options);
      if (app.options.projectId != options.projectId) {
        throw StateError('Cấu hình Firebase không khớp môi trường ứng dụng.');
      }
      _initialized = true;
    }
    if (emulator.isNotEmpty) {
      if (!_storage) {
        await FirebaseStorage.instance.useStorageEmulator(
          emulator,
          AppConfig.storageEmulatorPort,
        );
        _storage = true;
      }
      if (!_auth) {
        await FirebaseAuth.instance.useAuthEmulator(
          emulator,
          AppConfig.authEmulatorPort,
        );
        _auth = true;
      }
      if (!_firestore) {
        FirebaseFirestore.instance.useFirestoreEmulator(
          emulator,
          AppConfig.firestoreEmulatorPort,
        );
        _firestore = true;
      }
      if (!_functions) {
        FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion)
            .useFunctionsEmulator(emulator, AppConfig.functionsEmulatorPort);
        _functions = true;
      }
    }
    if (kIsWeb && !_persistence) {
      // Learner web sessions end when their tab closes. Admin auth is kept only
      // in memory so closing or reloading the Admin page requires a new sign-in.
      await FirebaseAuth.instance.setPersistence(
        isolatedAdmin ? Persistence.NONE : Persistence.SESSION,
      );
      _persistence = true;
    }
    if (kIsWeb && isolatedAdmin && !_clearedAdmin) {
      // Clear any Admin credential saved by an older build using LOCAL
      // persistence; fresh page loads must start at the login screen.
      await FirebaseAuth.instance.signOut();
      _clearedAdmin = true;
    }
  }
}
