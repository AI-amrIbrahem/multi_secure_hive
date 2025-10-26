
// =====================================================================
// config/hive_secure_config.dart
// =====================================================================

import 'package:flutter/foundation.dart';

/// إعدادات التخزين والتشفير القابلة للتخصيص
@immutable
class HiveSecureConfig {
  // أسماء المفاتيح في Secure Storage
  final String keyStorageName;
  final String wrappedKeyStorageName;
  final String lastRotationKey;

  // إعدادات التخزين
  final String suffix;

  // إعدادات التدوير
  final Duration rotationInterval;
  final bool autoRotate;

  // إعدادات التشفير (AES-256-GCM)
  final int keySize;
  final int nonceSize;
  final int macSize;

  // تفعيل Key Wrapping
  final bool useKeyWrapping;

  const HiveSecureConfig({
    this.keyStorageName = 'secure_master_key',
    this.wrappedKeyStorageName = 'wrapped_data_key',
    this.lastRotationKey = 'last_key_rotation_date',
    this.suffix = '_secure',
    this.rotationInterval = const Duration(days: 90),
    this.autoRotate = true,
    this.keySize = 32,        // 256 bits
    this.nonceSize = 12,      // 96 bits (recommended for GCM)
    this.macSize = 16,        // 128 bits
    this.useKeyWrapping = true,
  }) : assert(keySize == 32, 'Key size must be 32 bytes (256 bits)'),
        assert(nonceSize == 12, 'Nonce size must be 12 bytes (96 bits) for GCM'),
        assert(macSize == 16, 'MAC size must be 16 bytes (128 bits)');

  /// التكوين الافتراضي
  factory HiveSecureConfig.defaults() => const HiveSecureConfig();

  /// تكوين للإنتاج مع أمان عالي
  factory HiveSecureConfig.production({
    required String appName,
    int rotationIntervalInDays = 30
  }) => HiveSecureConfig(
    keyStorageName: '${appName}_master_key',
    wrappedKeyStorageName: '${appName}_data_key',
    lastRotationKey: '${appName}_last_rotation',
    suffix: '_${appName}_prod',
    rotationInterval:  Duration(days: rotationIntervalInDays), // تدوير شهري
    autoRotate: true,
    useKeyWrapping: true,
  );

  /// تكوين للتطوير
  factory HiveSecureConfig.development({
    required String appName,
    int rotationIntervalInDays = 365
  }) => HiveSecureConfig(
    keyStorageName: '${appName}_dev_master_key',
    wrappedKeyStorageName: '${appName}_dev_data_key',
    lastRotationKey: '${appName}_dev_last_rotation',
    suffix: '_${appName}_dev',
    rotationInterval:  Duration(days: rotationIntervalInDays), // تدوير سنوي
    autoRotate: false, // تعطيل التدوير التلقائي في التطوير
    useKeyWrapping: true,
  );

  /// نسخ مع تعديلات
  HiveSecureConfig copyWith({
    String? keyStorageName,
    String? wrappedKeyStorageName,
    String? lastRotationKey,
    String? suffix,
    Duration? rotationInterval,
    bool? autoRotate,
    int? keySize,
    int? nonceSize,
    int? macSize,
    bool? useKeyWrapping,
  }) {
    return HiveSecureConfig(
      keyStorageName: keyStorageName ?? this.keyStorageName,
      wrappedKeyStorageName: wrappedKeyStorageName ?? this.wrappedKeyStorageName,
      lastRotationKey: lastRotationKey ?? this.lastRotationKey,
      suffix: suffix ?? this.suffix,
      rotationInterval: rotationInterval ?? this.rotationInterval,
      autoRotate: autoRotate ?? this.autoRotate,
      keySize: keySize ?? this.keySize,
      nonceSize: nonceSize ?? this.nonceSize,
      macSize: macSize ?? this.macSize,
      useKeyWrapping: useKeyWrapping ?? this.useKeyWrapping,
    );
  }

  @override
  String toString() {
    return 'HiveSecureConfig('
        'suffix: $suffix, '
        'rotationInterval: ${rotationInterval.inDays} days, '
        'autoRotate: $autoRotate, '
        'useKeyWrapping: $useKeyWrapping'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HiveSecureConfig &&
        other.keyStorageName == keyStorageName &&
        other.wrappedKeyStorageName == wrappedKeyStorageName &&
        other.lastRotationKey == lastRotationKey &&
        other.suffix == suffix &&
        other.rotationInterval == rotationInterval &&
        other.autoRotate == autoRotate &&
        other.keySize == keySize &&
        other.nonceSize == nonceSize &&
        other.macSize == macSize &&
        other.useKeyWrapping == useKeyWrapping;
  }

  @override
  int get hashCode {
    return Object.hash(
      keyStorageName,
      wrappedKeyStorageName,
      lastRotationKey,
      suffix,
      rotationInterval,
      autoRotate,
      keySize,
      nonceSize,
      macSize,
      useKeyWrapping,
    );
  }
}
