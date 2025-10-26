// =====================================================================
// core/aes_gcm_encryptor.dart (مُحدَّث)
// =====================================================================

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../config/hive_secure_config.dart';
import '../exceptions/hive_secure_exception.dart';

class AesGcmEncryptor {
  final HiveSecureConfig config; // ✅ إضافة Config
  final _algorithm = AesGcm.with256bits();

  AesGcmEncryptor({required this.config}); // ✅

  Uint8List generateNonce() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(config.nonceSize, (_) => random.nextInt(256)), // ✅ من Config
    );
  }

  Future<String> encrypt(String plaintext, Uint8List key) async {
    try {
      final nonce = generateNonce();
      final secretKey = SecretKey(key);

      final encrypted = await _algorithm.encrypt(
        utf8.encode(plaintext),
        secretKey: secretKey,
        nonce: nonce,
      );

      final combined = Uint8List.fromList([
        ...nonce,
        ...encrypted.cipherText,
        ...encrypted.mac.bytes,
      ]);

      return base64Encode(combined);
    } catch (e) {
      throw HiveSecureException('Encryption failed: $e');
    }
  }

  Future<String> decrypt(String cipherBase64, Uint8List key) async {
    try {
      final data = base64Decode(cipherBase64);

      final minSize = config.nonceSize + config.macSize; // ✅ من Config
      if (data.length < minSize) {
        throw HiveSecureException('Invalid encrypted data format');
      }

      final nonce = data.sublist(0, config.nonceSize); // ✅ من Config
      final mac = Mac(data.sublist(data.length - config.macSize)); // ✅ من Config
      final cipherText = data.sublist(
        config.nonceSize, // ✅ من Config
        data.length - config.macSize, // ✅ من Config
      );

      final secretKey = SecretKey(key);
      final decrypted = await _algorithm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: secretKey,
      );

      return utf8.decode(decrypted);
    } catch (e) {
      throw HiveSecureException('Decryption failed: $e');
    }
  }
}