// CẤU HÌNH CHẠY: các giá trị dùng chung cho app học viên, web admin và kết nối API.
// Truyền --dart-define khi chạy/build để chọn emulator hoặc luồng thi tương thích cũ.
class AppConfig {
  static const useSecureBackend = bool.fromEnvironment(
    'USE_SECURE_BACKEND',
    defaultValue: true,
  );
  static const emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST');

  // Phải trùng vùng deploy trong functions/src/index.js.
  static const functionsRegion = 'asia-southeast1';
  // Phải trùng cổng trong firebase.json khi chạy local.
  static const authEmulatorPort = 9099;
  static const firestoreEmulatorPort = 8080;
  static const functionsEmulatorPort = 5001;
  static const storageEmulatorPort = 9199;
}
