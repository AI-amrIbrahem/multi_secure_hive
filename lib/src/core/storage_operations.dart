
// =====================================================================
// في الـ Package: lib/src/core/storage_operations.dart
// =====================================================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import '../exceptions/hive_secure_exception.dart';
import '../models/hive_keys_interface.dart';
import 'aes_gcm_encryptor.dart';

class StorageOperations<T extends HiveKeyInterface> {
  final String suffix;

  StorageOperations({required this.suffix});

  String _getBoxName(T key) => key.name + suffix;

  Future<void> openBox(T key, Uint8List encryptionKey) async {
    final boxName = _getBoxName(key);
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(
        boxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
    }
  }

  Future<void> setValue(T key, dynamic value) async {
    try {
      final box = Hive.box(_getBoxName(key));
      await box.put(key.name, value);
    } catch (e) {
      throw HiveSecureException('Failed to set value for ${key.name}: $e');
    }
  }

  V? getValue<V>(T key)  {
    try {
      final box = Hive.box(_getBoxName(key));
      final value = box.get(key.name);
      return value as V?;
    } catch (e) {
      throw HiveSecureException('Failed to get value for ${key.name}: $e');
    }
  }

  Future<void> deleteValue(T key) async {
    try {
      final box = Hive.box(_getBoxName(key));
      await box.delete(key.name);
    } catch (e) {
      throw HiveSecureException('Failed to delete value for ${key.name}: $e');
    }
  }

  Future<void> clearBox(T key) async {
    try {
      await Hive.box(_getBoxName(key)).clear();
    } catch (e) {
      throw HiveSecureException('Failed to clear box for ${key.name}: $e');
    }
  }

  bool hasValue(T key)  {
    final box = Hive.box(_getBoxName(key));
    return box.containsKey(key.name);
  }

  String exportBackup(List<T> keys)  {
    final backup = <String, Map<dynamic, dynamic>>{};
    for (final key in keys) {
      final box = Hive.box(_getBoxName(key));
      backup[key.name] = box.toMap();
    }
    return base64Encode(utf8.encode(jsonEncode(backup)));
  }

  Future<void> importBackup(String backupData, List<T> keys) async {
    try {
      final decoded = jsonDecode(
          utf8.decode(base64Decode(backupData))
      ) as Map<String, dynamic>;

      for (final entry in decoded.entries) {
        final hiveKey = keys.firstWhere(
              (k) => k.name == entry.key,
          orElse: () => throw HiveSecureException(
              'Invalid backup: unknown key ${entry.key}'
          ),
        );

        final box = Hive.box(_getBoxName(hiveKey));
        final data = entry.value as Map<dynamic, dynamic>;
        await box.putAll(data);
      }
    } catch (e) {
      throw HiveSecureException('Failed to import backup: $e');
    }
  }

  Future<void> rotateBoxKey(
      T hiveKey,
      Uint8List oldKey,
      Uint8List newKey,
      AesGcmEncryptor encryptor,
      ) async {
    final boxName = _getBoxName(hiveKey);
    Box? oldBox;
    Box? newBox;
    Map<dynamic, dynamic>? backupData;

    try {
      if (!Hive.isBoxOpen(boxName)) {
        throw HiveSecureException('Box $boxName is not open');
      }

      oldBox = Hive.box(boxName);

      print('🔄 Rotating box: $boxName (${oldBox.length} items)');

      backupData = <dynamic, dynamic>{};

      for (final entry in oldBox.toMap().entries) {
        final val = entry.value;

        if (val is String && val.isNotEmpty) {
          try {
            final decrypted = await encryptor.decrypt(val, oldKey);
            final reEncrypted = await encryptor.encrypt(decrypted, newKey);
            backupData[entry.key] = reEncrypted;
            print('   ✅ Rotated: ${entry.key}');
          } catch (e) {
            print('   ⚠️ Non-encrypted value kept: ${entry.key}');
            backupData[entry.key] = val;
          }
        } else {
          backupData[entry.key] = val;
        }
      }

      await oldBox.deleteFromDisk();
      oldBox = null;

      print('   ✅ Old box deleted');

      newBox = await Hive.openBox(
        boxName,
        encryptionCipher: HiveAesCipher(newKey),
      );

      print('   ✅ New box opened');

      if (backupData.isNotEmpty) {
        await newBox.putAll(backupData);
        print('   ✅ Restored ${backupData.length} items');
      }

      print('✅ Box $boxName rotated successfully');

    } catch (e, stackTrace) {
      print('❌ Failed to rotate box $boxName: $e');
      print('Stack trace: $stackTrace');

      await _attemptRecovery(
        boxName: boxName,
        oldKey: oldKey,
        newKey: newKey,
        backupData: backupData,
      );

      rethrow;
    }
  }

  Future<void> _attemptRecovery({
    required String boxName,
    required Uint8List oldKey,
    required Uint8List newKey,
    Map<dynamic, dynamic>? backupData,
  }) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        final box = Hive.box(boxName);
        if (box.isEmpty && backupData != null && backupData.isNotEmpty) {
          await box.putAll(backupData);
          print('⚠️ Recovered data to new box');
          return;
        }
      }

      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox(
          boxName,
          encryptionCipher: HiveAesCipher(oldKey),
        );
        print('⚠️ Restored box with old key');
      }
    } catch (recoveryError) {
      print('❌ Recovery failed: $recoveryError');

      try {
        if (Hive.isBoxOpen(boxName)) {
          await Hive.box(boxName).deleteFromDisk();
        }
        await Hive.openBox(
          boxName,
          encryptionCipher: HiveAesCipher(oldKey),
        );
        print('⚠️ Created fresh box with old key (data lost)');
      } catch (finalError) {
        print('❌ Complete recovery failure: $finalError');
      }
    }
  }

  Future<void> dispose(List<T> keys) async {
    for (final key in keys) {
      final boxName = _getBoxName(key);
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close();
      }
    }
  }
}