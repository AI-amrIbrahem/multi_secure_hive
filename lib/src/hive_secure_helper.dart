// =====================================================================
// في الـ Package: lib/src/hive_secure_helper.dart
// =====================================================================

import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/key_manager.dart';
import 'core/aes_gcm_encryptor.dart';
import 'core/key_rotator.dart';
import 'core/storage_operations.dart';
import 'core/secure_storage_operations.dart';
import 'models/hive_keys_interface.dart';
import 'models/security_level.dart';
import 'models/backup_data.dart';
import 'config/hive_secure_config.dart';
import 'exceptions/hive_secure_exception.dart';

class HiveSecureHelper<T extends HiveKeyInterface> {
  HiveSecureHelper();

  final _secureStorage = const FlutterSecureStorage();

  final _androidOptions = const AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
  );

  final _iosOptions = const IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  );

  late final KeyManager _keyManager;
  late final AesGcmEncryptor _encryptor;
  late final KeyRotator<T> _rotator;
  late final StorageOperations<T> _storage;
  late final SecureStorageOperations<T> _secureOps;

  late HiveSecureConfig _config;
  late List<T> _keys; // ✅ قائمة الـ Keys من المستخدم

  HiveSecureConfig get config => _config;
  List<T> get keys => _keys;

  bool _initialized = false;
  bool _rotationInProgress = false;

  /// تهيئة مع تمرير الـ Keys من المشروع
  Future<void> _init({
    required List<T> keys, // ✅ إلزامي: تمرير الـ Keys
    HiveSecureConfig? config,
  }) async {

    print('initialize1$_initialized');

    if (_initialized) return;

    _keys = keys;
    _config = config ?? HiveSecureConfig.defaults();

    try {
      print('aaaaaaaaaaaa10');
      await Hive.initFlutter();
      print('aaaaaaaaaaaa101');
      _keyManager = KeyManager(
        secureStorage: _secureStorage,
        androidOptions: _androidOptions,
        iosOptions: _iosOptions,
        config: _config,
      );
      print('aaaaaaaaaaaa1011');
      _encryptor = AesGcmEncryptor(config: _config);

      _rotator = KeyRotator<T>(
        keyManager: _keyManager,
        secureStorage: _secureStorage,
        androidOptions: _androidOptions,
        iosOptions: _iosOptions,
        config: _config,
      );

      _storage = StorageOperations<T>(suffix: _config.suffix);

      _secureOps = SecureStorageOperations<T>(
        keyManager: _keyManager,
        encryptor: _encryptor,
        storageOps: _storage,
      );

      final dataKey = await _keyManager.getOrCreateDataKey();


      print('aaaaaaaaaaaa1');
      for (final boxKey in _keys) {
        print('aaaaaaaaaaaa1$boxKey');

        await _storage.openBox(boxKey, dataKey);
      }

      if (_config.autoRotate) {
        await _checkAndAutoRotate();
      }

      _initialized = true;
      print('✅ HiveSecureHelper initialized with ${_keys.length} keys');
    } catch (e) {
      throw HiveSecureException('Failed to initialize: $e');
    }
  }

  Future<void> setValue(T key, dynamic value) async {
    _ensureInitialized();
    _checkRotationLock();
    await _storage.setValue(key, value);
  }

  V? getValue<V>(T key)  {
    _ensureInitialized();
    return  _storage.getValue<V>(key);
  }

  Future<void> deleteValue(T key) async {
    _ensureInitialized();
    _checkRotationLock();
    await _storage.deleteValue(key);
  }

  bool hasValue(T key)  {
    _ensureInitialized();
    return  _storage.hasValue(key);
  }

  Future<void> clearBox(T key) async {
    _ensureInitialized();
    _checkRotationLock();
    await _storage.clearBox(key);
  }

  Future<void> clearAllBoxes() async {
    _ensureInitialized();
    _checkRotationLock();
    for (final key in _keys) {
      await clearBox(key);
    }
  }

  Future<void> setSecureValue(T key, String value) async {
    _ensureInitialized();
    _checkRotationLock();
    await _secureOps.setSecureValue(key, value);
  }

  Future<String?> getSecureValue(T key) async {
    _ensureInitialized();
    return await _secureOps.getSecureValue(key);
  }

  Future<void> rotateMasterKey({
    void Function()? onSuccess,
    void Function(String error)? onError,
  }) async {
    _ensureInitialized();

    if (_rotationInProgress) {
      throw HiveSecureException('Key rotation already in progress');
    }

    try {
      _rotationInProgress = true;
      print('🔄 Manual key rotation started...');

      await _rotator.rotateMasterKey(_storage, _encryptor, _keys);

      onSuccess?.call();
      print('✅ Manual key rotation completed successfully');
    } catch (e) {
      onError?.call(e.toString());
      print('❌ Manual key rotation failed: $e');
      rethrow;
    } finally {
      _rotationInProgress = false;
    }
  }

  Future<DateTime?> getLastRotationDate() async {
    _ensureInitialized();
    return await _rotator.getLastRotationDate();
  }

  Future<int?> getDaysUntilNextRotation() async {
    _ensureInitialized();
    return await _rotator.getDaysUntilNextRotation();
  }

  Future<bool> isStrongBoxSupported() async {
    _ensureInitialized();
    return await _keyManager.isStrongBoxSupported();
  }

  Future<bool> isSecureEnclaveSupported() async {
    _ensureInitialized();
    return await _keyManager.isSecureEnclaveSupported();
  }

  Future<SecurityLevel> getSecurityLevel() async {
    _ensureInitialized();
    return await _keyManager.getSecurityLevel();
  }

  Future<BackupData> exportBackup() async {
    _ensureInitialized();

    final backupJson = await _storage.exportBackup(_keys);
    final masterKey = await _keyManager.getOrCreateMasterKey();
    final hmac = await _computeHmac(backupJson, masterKey);

    return BackupData(
      data: backupJson,
      hmac: hmac,
      timestamp: DateTime.now().toIso8601String(),
    );
  }

  Future<void> importBackup(BackupData backup) async {
    _ensureInitialized();

    final masterKey = await _keyManager.getOrCreateMasterKey();
    final calculatedHmac = await _computeHmac(backup.data, masterKey);

    if (calculatedHmac != backup.hmac) {
      throw HiveSecureException('Backup integrity check failed: HMAC mismatch');
    }

    await _storage.importBackup(backup.data, _keys);
    print('✅ Backup imported successfully');
  }

  Future<String> _computeHmac(String data, String key) async {
    final hmac = Hmac.sha256();
    final secretKey = SecretKey(utf8.encode(key));
    final mac = await hmac.calculateMac(
      utf8.encode(data),
      secretKey: secretKey,
    );
    return base64Encode(mac.bytes);
  }

  Future<void> dispose() async {
    if (!_initialized) return;

    await _storage.dispose(_keys);
    _initialized = false;
    _rotationInProgress = false;
    print('🔒 HiveSecureHelper disposed');
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw HiveSecureException('HiveSecureHelper not initialized. Call init() first.');
    }
  }

  void _checkRotationLock() {
    if (_rotationInProgress) {
      throw HiveSecureException('Operation blocked: key rotation in progress');
    }
  }

  Future<void> _checkAndAutoRotate() async {
    try {
      final needsRotation = await _rotator.shouldRotate();
      if (needsRotation) {
        print('🔄 Auto key rotation started...');
        _rotationInProgress = true;

        await _rotator.rotateMasterKey(_storage, _encryptor, _keys);

        print('✅ Auto key rotation completed successfully');
      }
    } catch (e) {
      print('⚠️ Auto rotation failed: $e');
    } finally {
      _rotationInProgress = false;
    }
  }

  /// ✅ إعادة تعيين كاملة (حذف جميع البيانات والمفاتيح)
  /// استخدمها فقط عند الحاجة (مثل تسجيل خروج نهائي)
  Future<void> resetEverything() async {
    try {
      print('⚠️ Resetting everything...');

      // 1. حذف جميع الصناديق
      if (_initialized) {
        for (final key in _keys) {
          try {
            await clearBox(key);
          } catch (e) {
            print('⚠️ Failed to clear box ${key.name}: $e');
          }
        }
      }

      // 2. إعادة تعيين المفاتيح
      await _keyManager.resetAllKeys();

      // 3. إعادة التهيئة
      _initialized = false;

      print('✅ Reset completed. Re-initialize to use again.');
    } catch (e) {
      throw HiveSecureException('Failed to reset: $e');
    }
  }

  /// ✅ معالجة أخطاء MAC عند التهيئة
  Future<void> initSafe({
    required List<T> keys,
    HiveSecureConfig? config,
    bool resetOnError = false, // إعادة تعيين تلقائية عند الخطأ
    Function()? afterReset
  }) async {
    try {
      await _init(keys: keys, config: config);
    } on HiveSecureException catch (e) {
      // التحقق من خطأ MAC
      if (e.message.contains('MAC') ||
          e.message.contains('authentication') ||
          e.message.contains('Decryption failed')) {

        print('⚠️ MAC Error detected: ${e.message}');

        if (resetOnError) {
          print('🔄 Auto-resetting due to MAC error...');

          // إعادة تعيين المفاتيح
          await _keyManager.resetAllKeys();

          // محاولة التهيئة مرة أخرى
          await _init(keys: keys, config: config);

          if(afterReset!=null)
          afterReset();
          print('✅ Successfully recovered from MAC error');
        } else {
          print('❌ MAC Error: Please call resetEverything() or pass resetOnError: true');
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }
}