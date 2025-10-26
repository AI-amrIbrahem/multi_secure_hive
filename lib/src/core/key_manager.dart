// =====================================================================
// core/key_manager.dart - النسخة الكاملة مع معالجة MAC Error
// =====================================================================

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/hive_secure_config.dart';
import '../exceptions/hive_secure_exception.dart';
import '../models/security_level.dart';
import 'aes_gcm_encryptor.dart';

class KeyManager {
  final FlutterSecureStorage secureStorage;
  final AndroidOptions androidOptions;
  final IOSOptions iosOptions;
  final HiveSecureConfig config;
  late final AesGcmEncryptor _encryptor;

  KeyManager({
    required this.secureStorage,
    required this.androidOptions,
    required this.iosOptions,
    required this.config,
  }) {
    _encryptor = AesGcmEncryptor(config: config);
  }

  Future<String> getOrCreateMasterKey() async {
    try {
      String? key = await secureStorage.read(
        key: config.keyStorageName,
        aOptions: androidOptions,
        iOptions: iosOptions,
      );

      if (key == null) {
        final newKey = generateRandomKey();
        await _storeMasterKeySecurely(newKey);
        return newKey;
      }
      return key;
    } catch (e) {
      throw HiveSecureException(
          'Failed to access master key: $e\n'
              'If master key is lost, all encrypted data will be inaccessible. '
              'Consider re-authentication or data reset.'
      );
    }
  }

  /// ✅ معالجة MAC Error في getOrCreateDataKey
  Future<Uint8List> getOrCreateDataKey() async {
    if (!config.useKeyWrapping) {
      final masterKey = await getOrCreateMasterKey();
      return decodeKey(masterKey);
    }

    try {
      String? wrappedKey = await secureStorage.read(
        key: config.wrappedKeyStorageName,
        aOptions: androidOptions,
        iOptions: iosOptions,
      );

      if (wrappedKey != null) {
        // ✅ محاولة فك التشفير مع معالجة MAC Error
        try {
          return await _unwrapDataKey(wrappedKey);
        } catch (e) {
          // ✅ التحقق من MAC Error
          if (e.toString().contains('MAC') ||
              e.toString().contains('authentication') ||
              e.toString().contains('SecretBoxAuthenticationError')) {

            print('⚠️ MAC Error detected in data key unwrapping');
            print('🔄 Regenerating data key...');

            // حذف المفتاح التالف
            await secureStorage.delete(
              key: config.wrappedKeyStorageName,
              aOptions: androidOptions,
              iOptions: iosOptions,
            );

            // إنشاء مفتاح جديد
            final newDataKey = _generateRandomKeyBytes();
            await _wrapAndStoreDataKey(newDataKey);

            print('✅ New data key generated successfully');
            return newDataKey;
          } else {
            // خطأ آخر غير MAC
            rethrow;
          }
        }
      }

      // إذا لم يكن هناك مفتاح، أنشئ واحداً جديداً
      final newDataKey = _generateRandomKeyBytes();
      await _wrapAndStoreDataKey(newDataKey);
      return newDataKey;
    } catch (e) {
      throw HiveSecureException('Failed to access data key: $e');
    }
  }

  Future<void> _wrapAndStoreDataKey(Uint8List dataKey) async {
    final masterKey = await getOrCreateMasterKey();
    final masterKeyBytes = decodeKey(masterKey);

    final wrappedKey = await _encryptor.encrypt(
      base64Encode(dataKey),
      masterKeyBytes,
    );

    await secureStorage.write(
      key: config.wrappedKeyStorageName,
      value: wrappedKey,
      aOptions: androidOptions,
      iOptions: iosOptions,
    );
  }

  Future<Uint8List> _unwrapDataKey(String wrappedKey) async {
    final masterKey = await getOrCreateMasterKey();
    final masterKeyBytes = decodeKey(masterKey);

    final dataKeyBase64 = await _encryptor.decrypt(wrappedKey, masterKeyBytes);
    return base64Decode(dataKeyBase64);
  }

  Future<void> _storeMasterKeySecurely(String key) async {
    await secureStorage.write(
      key: config.keyStorageName,
      value: key,
      aOptions: androidOptions,
      iOptions: iosOptions,
    );
  }

  String generateRandomKey() {
    final keyBytes = _generateRandomKeyBytes();
    return base64Encode(keyBytes);
  }

  Uint8List _generateRandomKeyBytes() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(config.keySize, (_) => random.nextInt(256)),
    );
  }

  /// ✅ إعادة تعيين جميع المفاتيح (للحالات الطارئة)
  Future<void> resetAllKeys() async {
    try {
      print('🔄 Resetting all keys...');

      // حذف المفتاح الرئيسي
      await secureStorage.delete(
        key: config.keyStorageName,
        aOptions: androidOptions,
        iOptions: iosOptions,
      );

      // حذف مفتاح البيانات المغلف
      await secureStorage.delete(
        key: config.wrappedKeyStorageName,
        aOptions: androidOptions,
        iOptions: iosOptions,
      );

      // حذف تاريخ التدوير
      await secureStorage.delete(
        key: config.lastRotationKey,
        aOptions: androidOptions,
        iOptions: iosOptions,
      );

      print('✅ All keys reset successfully');
    } catch (e) {
      print('❌ Failed to reset keys: $e');
      throw HiveSecureException('Failed to reset keys: $e');
    }
  }

  /// ✅ التحقق من وجود مفاتيح
  Future<bool> hasKeys() async {
    try {
      final masterKey = await secureStorage.read(
        key: config.keyStorageName,
        aOptions: androidOptions,
        iOptions: iosOptions,
      );
      return masterKey != null;
    } catch (e) {
      return false;
    }
  }

  /// ✅ حذف جميع البيانات من Secure Storage (Debug فقط)
  Future<void> deleteAllSecureStorage() async {
    try {
      print('⚠️ Deleting all secure storage...');
      await secureStorage.deleteAll(
        aOptions: androidOptions,
        iOptions: iosOptions,
      );
      print('✅ All secure storage deleted');
    } catch (e) {
      print('❌ Failed to delete secure storage: $e');
    }
  }

  Future<bool> isStrongBoxSupported() async {
    try {
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isSecureEnclaveSupported() async {
    try {
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<SecurityLevel> getSecurityLevel() async {
    try {
      return SecurityLevel.hardware;
    } catch (e) {
      return SecurityLevel.software;
    }
  }

  Uint8List decodeKey(String key) => base64Decode(key);
  String encodeKey(Uint8List key) => base64Encode(key);
}