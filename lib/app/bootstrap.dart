import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../firebase_options.dart';

Future<void> bootstrap(Widget app) async {
  WidgetsFlutterBinding.ensureInitialized();
  const emulator = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
  await Firebase.initializeApp(
    options: emulator.isEmpty
        ? DefaultFirebaseOptions.currentPlatform
        : const FirebaseOptions(
            apiKey: 'demo-key',
            appId: '1:123456:web:demo',
            messagingSenderId: '123456',
            projectId: 'demo-e09',
            authDomain: 'demo-e09.firebaseapp.com',
          ),
  );
  if (emulator.isNotEmpty) {
    await FirebaseAuth.instance.useAuthEmulator(emulator, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(emulator, 8080);
    FirebaseFunctions.instanceFor(region: 'asia-southeast1')
        .useFunctionsEmulator(emulator, 5001);
  }
  runApp(app);
}
