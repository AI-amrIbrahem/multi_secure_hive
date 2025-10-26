// =====================================================================
// ✅ Service Layer (Singleton) - الحل الصحيح
// =====================================================================

import 'package:multi_secure_hive/multi_secure_hive.dart';

import 'models/hive_keys.dart';

class SecureStorageService {
  // Singleton Pattern
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final _storage = HiveSecureHelper<HiveKeys>();

  // Getters للوصول للبيانات بأمان
  HiveSecureConfig get config => _storage.config;
  List<HiveKeys> get keys => _storage.keys;
  bool get isInitialized {
    try {
      _storage.config;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// تهيئة التخزين
  Future<void> initialize({
    HiveSecureConfig? config,
    bool resetOnError = true,
    Function()? afterReset,
  }) async {
    print('initialize1');
    await _storage.initSafe(
      keys: HiveKeys.values,
      config: config ?? HiveSecureConfig.development(appName: 'MyApp'),
      resetOnError: resetOnError,
      afterReset: afterReset,
    );
  }

  // Operations
  Future<void> setValue(HiveKeys key, dynamic value) async {
    await _storage.setValue(key, value);
  }

  T? getValue<T>(HiveKeys key)  {
    return  _storage.getValue<T>(key);
  }

  Future<void> setSecureValue(HiveKeys key, String value) async {
    await _storage.setSecureValue(key, value);
  }

  Future<String?> getSecureValue(HiveKeys key) async {
    return await _storage.getSecureValue(key);
  }

  Future<void> deleteValue(HiveKeys key) async {
    await _storage.deleteValue(key);
  }

  bool hasValue(HiveKeys key)  {
    return  _storage.hasValue(key);
  }

  Future<void> clearBox(HiveKeys key) async {
    await _storage.clearBox(key);
  }

  Future<void> clearAllBoxes() async {
    await _storage.clearAllBoxes();
  }

  // Key Management
  Future<void> rotateMasterKey({
    void Function()? onSuccess,
    void Function(String error)? onError,
  }) async {
    await _storage.rotateMasterKey(
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<DateTime?> getLastRotationDate() async {
    return await _storage.getLastRotationDate();
  }

  Future<int?> getDaysUntilNextRotation() async {
    return await _storage.getDaysUntilNextRotation();
  }

  Future<SecurityLevel> getSecurityLevel() async {
    return await _storage.getSecurityLevel();
  }

  // Emergency
  Future<void> resetEverything() async {
    await _storage.resetEverything();
  }

  Future<void> dispose() async {
    await _storage.dispose();
  }
}