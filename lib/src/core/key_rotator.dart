// =====================================================================
// في الـ Package: lib/src/core/key_rotator.dart
// =====================================================================

import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/hive_secure_config.dart';
import '../exceptions/hive_secure_exception.dart';
import '../models/hive_keys_interface.dart';
import 'key_manager.dart';
import 'aes_gcm_encryptor.dart';
import 'storage_operations.dart';

class KeyRotator<T extends HiveKeyInterface> {
  final KeyManager keyManager;
  final FlutterSecureStorage secureStorage;
  final AndroidOptions androidOptions;
  final IOSOptions iosOptions;
  final HiveSecureConfig config;

  KeyRotator({
    required this.keyManager,
    required this.secureStorage,
    required this.androidOptions,
    required this.iosOptions,
    required this.config,
  });

  Future<bool> shouldRotate() async {
    try {
      final lastRotationStr = await secureStorage.read(
        key: config.lastRotationKey,
        aOptions: androidOptions,
        iOptions: iosOptions,
      );

      if (lastRotationStr == null) {
        await secureStorage.write(
          key: config.lastRotationKey,
          value: DateTime.now().toIso8601String(),
          aOptions: androidOptions,
          iOptions: iosOptions,
        );
        return false;
      }

      final lastRotation = DateTime.parse(lastRotationStr);
      final now = DateTime.now();
      final daysSinceRotation = now.difference(lastRotation).inDays;

      return daysSinceRotation >= config.rotationInterval.inDays;
    } catch (e) {
      print('shouldRotate check failed: $e');
      return false;
    }
  }

  /// تدوير المفتاح الرئيسي مع معالجة أفضل للأخطاء
  Future<void> rotateMasterKey(
      StorageOperations<T> storage,
      AesGcmEncryptor encryptor,
      List<T> keys, // ✅ تمرير قائمة الـ Keys
      ) async {
    print('🔄 Starting master key rotation...');

    try {
      // 1. الحصول على المفاتيح القديمة والجديدة
      final oldMasterKey = await keyManager.getOrCreateMasterKey();
      final newMasterKey = keyManager.generateRandomKey();
      final oldKey = keyManager.decodeKey(oldMasterKey);
      final newKey = keyManager.decodeKey(newMasterKey);

      print('   ✅ Generated new master key');

      // 2. تدوير كل صندوق على حدة
      int successCount = 0;
      int failCount = 0;

      for (final hiveKey in keys) {
        try {
          await _rotateBoxKey(hiveKey, oldKey, newKey, storage, encryptor);
          successCount++;
        } catch (e) {
          failCount++;
          print('   ❌ Failed to rotate ${hiveKey.name}: $e');
          // نواصل مع باقي الصناديق
        }
      }

      print('   📊 Rotation summary: $successCount succeeded, $failCount failed');

      // 3. إذا فشلت جميع الصناديق، لا نحفظ المفتاح الجديد
      if (successCount == 0) {
        throw HiveSecureException(
            'All box rotations failed. Master key not updated.'
        );
      }

      // 4. حفظ المفتاح الرئيسي الجديد
      await secureStorage.write(
        key: config.keyStorageName,
        value: newMasterKey,
        aOptions: androidOptions,
        iOptions: iosOptions,
      );

      print('   ✅ Saved new master key');

      // 5. تحديث تاريخ التدوير
      await secureStorage.write(
        key: config.lastRotationKey,
        value: DateTime.now().toIso8601String(),
        aOptions: androidOptions,
        iOptions: iosOptions,
      );

      print('✅ Master key rotation completed successfully!');

      if (failCount > 0) {
        print('⚠️ Warning: $failCount boxes failed to rotate');
      }

    } catch (e) {
      print('❌ Master key rotation failed: $e');
      throw HiveSecureException('Failed to rotate master key: $e');
    }
  }

  Future<void> _rotateBoxKey(
      T hiveKey,
      Uint8List oldKey,
      Uint8List newKey,
      StorageOperations<T> storage,
      AesGcmEncryptor encryptor,
      ) async {
    await storage.rotateBoxKey(hiveKey, oldKey, newKey, encryptor);
  }

  Future<DateTime?> getLastRotationDate() async {
    try {
      final lastRotationStr = await secureStorage.read(
        key: config.lastRotationKey,
        aOptions: androidOptions,
        iOptions: iosOptions,
      );
      if (lastRotationStr == null) return null;
      return DateTime.parse(lastRotationStr);
    } catch (e) {
      return null;
    }
  }

  Future<int?> getDaysUntilNextRotation() async {
    final lastRotation = await getLastRotationDate();
    if (lastRotation == null) return null;

    final nextRotation = lastRotation.add(config.rotationInterval);
    final daysRemaining = nextRotation.difference(DateTime.now()).inDays;
    return daysRemaining > 0 ? daysRemaining : 0;
  }
}