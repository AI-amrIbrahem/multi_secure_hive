# 🔐 Multi Secure Hive

A production-ready Flutter package for secure local data storage with enterprise-grade encryption, automatic key rotation, and hardware-backed security.

## ✨ Features

- **🔒 AES-256-GCM Encryption**: Military-grade encryption for all stored data
- **🔑 Hardware-Backed Security**: Leverages Android StrongBox and iOS Secure Enclave when available
- **🔄 Automatic Key Rotation**: Configurable automatic encryption key rotation
- **🎯 Type-Safe API**: Strongly-typed interface using Dart enums
- **💾 Secure Backup/Restore**: HMAC-verified backup system
- **🛡️ Key Wrapping**: Additional security layer using key wrapping protocol
- **⚡ High Performance**: Optimized for production workloads
- **🔧 Flexible Configuration**: Customizable for development and production environments
- **🚨 Error Recovery**: Automatic recovery from MAC authentication errors
- **📦 Zero Dependencies Overhead**: Uses only essential, well-maintained packages

## 📋 Requirements

- Flutter SDK: >=3.0.0
- Dart SDK: >=3.0.0
- iOS: >=12.0
- Android: >=21 (API level 21)

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  multi_secure_hive:
    git:
      url: https://github.com/AI-amrIbrahem/multi_secure_hive.git
```

Then run:

```bash
flutter pub get
```

## 🚀 Quick Start

### 1. Define Your Storage Keys

Create an enum implementing `HiveKeyInterface`:

```dart
import 'package:multi_secure_hive/multi_secure_hive.dart';

enum AppKeys implements HiveKeyInterface {
  userToken,
  userProfile,
  settings,
  cache;

  @override
  String get name => toString().split('.').last;
}
```

### 2. Create Storage Service

```dart
import 'package:multi_secure_hive/multi_secure_hive.dart';
import 'models/hive_keys.dart';

class SecureStorageService {
  // Singleton Pattern
  static final SecureStorageService _instance =
  SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final _storage = HiveSecureHelper<HiveKeys>();

  // Getters
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

  /// Initialize storage
  Future<void> initialize({
    HiveSecureConfig? config,
    bool resetOnError = true,
    Function()? afterReset,
  }) async {
    await _storage.initSafe(
      keys: HiveKeys.values,
      config: config ?? HiveSecureConfig.development(appName: 'MyApp'),
      resetOnError: resetOnError,
      afterReset: afterReset,
    );
  }

  // Basic Operations
  Future<void> setValue(HiveKeys key, dynamic value) async {
    await _storage.setValue(key, value);
  }

  T? getValue<T>(HiveKeys key) {
    return _storage.getValue<T>(key);
  }

  Future<void> deleteValue(HiveKeys key) async {
    await _storage.deleteValue(key);
  }

  bool hasValue(HiveKeys key) {
    return _storage.hasValue(key);
  }

  Future<void> clearBox(HiveKeys key) async {
    await _storage.clearBox(key);
  }

  Future<void> clearAllBoxes() async {
    await _storage.clearAllBoxes();
  }

  // Secure Operations (Double Encryption)
  Future<void> setSecureValue(HiveKeys key, String value) async {
    await _storage.setSecureValue(key, value);
  }

  Future<String?> getSecureValue(HiveKeys key) async {
    return await _storage.getSecureValue(key);
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

  // Emergency Actions
  Future<void> resetEverything() async {
    await _storage.resetEverything();
  }

  Future<void> dispose() async {
    await _storage.dispose();
  }
}
```

### 3. Initialize in Main

```dart
import 'package:flutter/material.dart';
import 'package:multi_secure_hive/multi_secure_hive.dart';
import 'core/storage/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize secure storage
  await SecureStorageService().initialize(
    config: HiveSecureConfig.production(appName: 'appkey'),
    resetOnError: true,
    afterReset: () {
      print("Secure storage initialized/reset");
      // Handle post-reset logic (e.g., force logout, clear user session)
    },
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi Secure Hive Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
```

### 4. Store and Retrieve Data

```dart

// Then use anywhere in your app
final secureStorage = SecureStorageService();

// Store regular data
await secureStorage.setValue(AppKeys.userProfile, {
  'name': 'John Doe',
  'email': 'john@example.com',
});

// Retrieve data
final profile = secureStorage.getValue<Map>(AppKeys.userProfile);
print(profile?['name']); // John Doe

// Store extra-secure data (double encrypted)
await secureStorage.setSecureValue(
  AppKeys.userToken,
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
);

// Retrieve secure data
final token = await secureStorage.getSecureValue(AppKeys.userToken);
```

## 📚 Configuration

### Production Configuration

```dart
final config = HiveSecureConfig.production(
  appName: 'MyApp',
  rotationIntervalInDays: 30, // Rotate keys monthly
);
```

### Development Configuration

```dart
final config = HiveSecureConfig.development(
  appName: 'MyApp',
  rotationIntervalInDays: 365, // Rotate keys yearly
);
```

### Custom Configuration

```dart
final config = HiveSecureConfig(
  keyStorageName: 'my_master_key',
  wrappedKeyStorageName: 'my_data_key',
  suffix: '_encrypted',
  rotationInterval: Duration(days: 60),
  autoRotate: true,
  useKeyWrapping: true,
  keySize: 32,        // AES-256
  nonceSize: 12,      // GCM recommended
  macSize: 16,        // 128-bit authentication
);
```

## 🔐 Security Features

### Hardware-Backed Storage

Check security level:

```dart
final securityLevel = await secureStorage.getSecurityLevel();

switch (securityLevel) {
  case SecurityLevel.hardware:
    print('🔒 Using hardware-backed encryption');
    break;
  case SecurityLevel.tee:
    print('🔐 Using TEE encryption');
    break;
  case SecurityLevel.software:
    print('🔓 Using software encryption');
    break;
}

// Check specific capabilities
final hasStrongBox = await secureStorage.isStrongBoxSupported();
final hasSecureEnclave = await secureStorage.isSecureEnclaveSupported();
```

### Key Rotation

```dart
// Manual key rotation
await secureStorage.rotateMasterKey(
  onSuccess: () => print('✅ Keys rotated successfully'),
  onError: (error) => print('❌ Rotation failed: $error'),
);

// Check rotation status
final lastRotation = await secureStorage.getLastRotationDate();
final daysUntilNext = await secureStorage.getDaysUntilNextRotation();

print('Last rotation: $lastRotation');
print('Days until next rotation: $daysUntilNext');
```

### Backup & Restore

```dart
// Create encrypted backup
final backup = await secureStorage.exportBackup();
final backupJson = backup.toJsonString();

// Save backup to file or cloud
await File('backup.json').writeAsString(backupJson);

// Restore from backup
final restoredBackup = BackupData.fromJsonString(backupJson);
await secureStorage.importBackup(restoredBackup);
```

## 🛠️ Advanced Usage

### Check if Value Exists

```dart
if (secureStorage.hasValue(AppKeys.userToken)) {
  print('Token exists');
}
```

### Delete Specific Value

```dart
await secureStorage.deleteValue(AppKeys.userToken);
```

### Clear Specific Box

```dart
await secureStorage.clearBox(AppKeys.cache);
```

### Clear All Data

```dart
await secureStorage.clearAllBoxes();
```

### Complete Reset

Use with caution - deletes all data and encryption keys:

```dart
await secureStorage.resetEverything();
```

### Proper Cleanup

```dart
@override
void dispose() {
  secureStorage.dispose();
  super.dispose();
}
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│      HiveSecureHelper (Public API)      │
├─────────────────────────────────────────┤
│  - setValue / getValue                  │
│  - setSecureValue / getSecureValue      │
│  - rotateMasterKey                      │
│  - exportBackup / importBackup          │
└────────────┬────────────────────────────┘
             │
    ┌────────┴────────┐
    │                 │
┌───▼───────────┐ ┌──▼──────────────┐
│  KeyManager   │ │ StorageOps      │
├───────────────┤ ├─────────────────┤
│ - Master Key  │ │ - Hive Boxes    │
│ - Data Key    │ │ - CRUD Ops      │
│ - Key Wrap    │ │ - Backup/Restore│
└───────┬───────┘ └──────┬──────────┘
        │                │
    ┌───▼────────────────▼───┐
    │   AesGcmEncryptor      │
    ├────────────────────────┤
    │ - AES-256-GCM          │
    │ - Nonce Generation     │
    │ - MAC Authentication   │
    └────────────────────────┘
             │
    ┌────────▼────────┐
    │ Secure Storage  │
    ├─────────────────┤
    │ - Android KS    │
    │ - iOS Keychain  │
    └─────────────────┘
```

## 🔧 Error Handling

### MAC Authentication Errors

The package automatically handles MAC authentication errors that can occur when encryption keys are corrupted:

```dart
try {
  await secureStorage.initSafe(
    keys: AppKeys.values,
    resetOnError: true, // Enable auto-recovery
  );
} on HiveSecureException catch (e) {
  print('Initialization failed: ${e.message}');
}
```

### General Error Handling

```dart
try {
  await secureStorage.setValue(AppKeys.userProfile, userData);
} on HiveSecureException catch (e) {
  // Handle specific secure storage errors
  print('Storage error: ${e.message}');
} catch (e) {
  // Handle general errors
  print('Unexpected error: $e');
}
```

## 📊 Performance Considerations

- **Initialization**: One-time setup, typically <100ms
- **Read Operations**: ~1-5ms for regular data, ~10-20ms for secure data
- **Write Operations**: ~5-15ms for regular data, ~20-40ms for secure data
- **Key Rotation**: ~100-500ms depending on data size
- **Memory Usage**: Minimal overhead, scales with data size

## 🔒 Security Best Practices

1. **Always use production config in release builds**
2. **Enable automatic key rotation**
3. **Regularly backup encrypted data**
4. **Never log sensitive data or encryption keys**
5. **Handle `resetOnError` callback appropriately (e.g., force re-login)**
6. **Test key rotation in staging before production**
7. **Monitor security level on different devices**
8. **Use `setSecureValue` for highly sensitive data**

## 🐛 Troubleshooting

### "MAC verification failed" Error

This occurs when encryption keys are corrupted or changed. Solution:

```dart
await secureStorage.initSafe(
  keys: AppKeys.values,
  resetOnError: true, // Auto-fix
);
```

### "Box already open" Error

Ensure you're not initializing multiple times:

```dart
if (!secureStorage._initialized) {
  await secureStorage.initSafe(keys: AppKeys.values);
}
```

### Data Loss After App Reinstall

This is expected behavior for security. Consider:
- Cloud backup with user authentication
- Prompt user to backup before uninstall
- Implement data sync with backend

## 📄 License

MIT License - see LICENSE file for details

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

## 🙏 Acknowledgments

Built with:
- [Hive](https://pub.dev/packages/hive) - Fast, local storage
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) - Keychain/KeyStore integration
- [cryptography](https://pub.dev/packages/cryptography) - Pure Dart cryptography

---

**Made with ❤️ for the Flutter community**