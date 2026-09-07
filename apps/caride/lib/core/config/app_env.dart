class AppEnv {
  static const bool enableFirebaseEmulator = bool.fromEnvironment(
    'ENABLE_FIREBASE_EMULATOR',
    defaultValue: false,
  );
  static const String firebaseEmulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: 'localhost',
  );
  static const int firebaseAuthEmulatorPort = int.fromEnvironment(
    'FIREBASE_AUTH_EMULATOR_PORT',
    defaultValue: 9099,
  );
  static const int firebaseFirestoreEmulatorPort = int.fromEnvironment(
    'FIREBASE_FIRESTORE_EMULATOR_PORT',
    defaultValue: 8080,
  );
  static const int firebaseDatabaseEmulatorPort = int.fromEnvironment(
    'FIREBASE_DATABASE_EMULATOR_PORT',
    defaultValue: 9000,
  );
  static const int firebaseFunctionsEmulatorPort = int.fromEnvironment(
    'FIREBASE_FUNCTIONS_EMULATOR_PORT',
    defaultValue: 5001,
  );
  static const String firebaseFunctionsRegion = String.fromEnvironment(
    'FIREBASE_FUNCTIONS_REGION',
    defaultValue: 'us-east1',
  );
  static const int otpCodeLength = 6;
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyAQPLeYuNmRW9OuPBK93sX5M01aebbiknI',
  );
  static const String paystackPublicKey = String.fromEnvironment(
    'PAYSTACK_PUBLIC_KEY',
    defaultValue: 'pk_live_9a3133bdb8c6539b8ba228059dde0a4f10df3e1a',
  );
  static const String flutterwavePublicKey = String.fromEnvironment(
    'FLUTTERWAVE_PUBLIC_KEY',
    defaultValue: 'FLWPUBK-fe77d17f787c0e5c4c68a8d15b81ab72-X',
  );
}
