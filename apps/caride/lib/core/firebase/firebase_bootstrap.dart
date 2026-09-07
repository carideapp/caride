import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../config/app_env.dart';

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static Future<void> initialize() async {
    await Firebase.initializeApp();

    if (AppEnv.enableFirebaseEmulator) {
      final host = AppEnv.firebaseEmulatorHost;
      FirebaseAuth.instance.useAuthEmulator(host, AppEnv.firebaseAuthEmulatorPort);
      FirebaseFirestore.instance.useFirestoreEmulator(
        host,
        AppEnv.firebaseFirestoreEmulatorPort,
      );
      FirebaseDatabase.instance.useDatabaseEmulator(
        host,
        AppEnv.firebaseDatabaseEmulatorPort,
      );
      FirebaseFunctions.instanceFor(
        region: AppEnv.firebaseFunctionsRegion,
      ).useFunctionsEmulator(host, AppEnv.firebaseFunctionsEmulatorPort);
    }
  }
}
