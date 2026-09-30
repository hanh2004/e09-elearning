// KHỞI TẠO / GIAO DIỆN: Khởi tạo Firebase, kết nối emulator khi chạy local và mở ứng dụng.
// Các màn hình import tệp này sẽ dùng chung thay đổi.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import '../firebase_options.dart';
import 'cau_hinh_ung_dung.dart';

Future<void> bootstrap(
  Widget app, {
  bool useIsolatedAdminWebSessions = false,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  const emulator = AppConfig.emulatorHost;
  await Firebase.initializeApp(
    options: emulator.isEmpty
        ? DefaultFirebaseOptions.currentPlatform
        : const FirebaseOptions(
            apiKey: 'demo-key',
            appId: '1:123456:web:demo',
            messagingSenderId: '123456',
            projectId: 'demo-e09',
            authDomain: 'demo-e09.firebaseapp.com',
            storageBucket: 'demo-e09.appspot.com',
          ),
  );
  if (kIsWeb) {
    // Learner web sessions end when their tab closes. Admin auth is kept only
    // in memory so closing or reloading the Admin page requires a new sign-in.
    await FirebaseAuth.instance.setPersistence(
      useIsolatedAdminWebSessions ? Persistence.NONE : Persistence.SESSION,
    );
    if (useIsolatedAdminWebSessions) {
      // Clear any Admin credential saved by an older build using LOCAL
      // persistence; fresh page loads must start at the login screen.
      await FirebaseAuth.instance.signOut();
    }
  }
  if (emulator.isNotEmpty) {
    await FirebaseStorage.instance.useStorageEmulator(
      emulator,
      AppConfig.storageEmulatorPort,
    );
    await FirebaseAuth.instance.useAuthEmulator(
      emulator,
      AppConfig.authEmulatorPort,
    );
    FirebaseFirestore.instance.useFirestoreEmulator(
      emulator,
      AppConfig.firestoreEmulatorPort,
    );
    FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion)
        .useFunctionsEmulator(emulator, AppConfig.functionsEmulatorPort);
  }
  runApp(app);
}
