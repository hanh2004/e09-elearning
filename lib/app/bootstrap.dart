// KHỞI TẠO / GIAO DIỆN: Khởi tạo Firebase, kết nối emulator khi chạy local và mở ứng dụng.
// Các màn hình import tệp này sẽ dùng chung thay đổi.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../firebase_options.dart';
import 'app_config.dart';

Future<void> bootstrap(Widget app) async {
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
