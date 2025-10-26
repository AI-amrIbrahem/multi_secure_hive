// =====================================================================
// في الـ Package: lib/src/core/secure_storage_operations.dart
// =====================================================================

import '../exceptions/hive_secure_exception.dart';
import '../models/hive_keys_interface.dart';
import 'key_manager.dart';
import 'aes_gcm_encryptor.dart';
import 'storage_operations.dart';

class SecureStorageOperations<T extends HiveKeyInterface> {
  final KeyManager keyManager;
  final AesGcmEncryptor encryptor;
  final StorageOperations<T> storageOps;

  SecureStorageOperations({
    required this.keyManager,
    required this.encryptor,
    required this.storageOps,
  });

  Future<void> setSecureValue(T key, String value) async {
    try {
      final masterKey = keyManager.decodeKey(
        await keyManager.getOrCreateMasterKey(),
      );
      final encryptedValue = await encryptor.encrypt(value, masterKey);
      await storageOps.setValue(key, encryptedValue);
    } catch (e) {
      throw HiveSecureException(
          'Failed to set secure value for ${key.name}: $e'
      );
    }
  }

  Future<String?> getSecureValue(T key) async {
    try {
      final masterKey = keyManager.decodeKey(
        await keyManager.getOrCreateMasterKey(),
      );
      final encryptedValue = await storageOps.getValue<String>(key);
      if (encryptedValue == null) return null;
      return await encryptor.decrypt(encryptedValue, masterKey);
    } catch (e) {
      throw HiveSecureException(
          'Failed to get secure value for ${key.name}: $e'
      );
    }
  }
}