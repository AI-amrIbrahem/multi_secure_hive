import 'package:flutter/material.dart';
import 'package:multi_secure_hive/multi_secure_hive.dart';

import 'core/storage/models/hive_keys.dart';
import 'core/storage/storage_service.dart';
// =====================================================================
// أمثلة الاستخدام
// =====================================================================

void main() async {
  example8(); // استخدم المثال الآمن
}

// ✅ مثال 1: استخدام بسيط مع Service
void example1() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = SecureStorageService();
  await storage.initialize();

  runApp(const MyApp());
}

// ✅ مثال 2: تطبيق إنتاج
void example2() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = SecureStorageService();
  await storage.initialize(
    config: HiveSecureConfig.production(appName: 'MyApp'),
  );

  runApp(const MyApp());
}

// ✅ مثال 3: تطبيق تطوير
void example3() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = SecureStorageService();
  await storage.initialize(
    config: HiveSecureConfig.development(appName: 'MyApp'),
  );

  print('Auto rotate: ${storage.config.autoRotate}');

  runApp(const MyApp());
}

// ✅ مثال 8: الأكثر أماناً (مُوصى به) ⭐
void example8() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = SecureStorageService();

  try {
    await storage.initialize(
      config: HiveSecureConfig.development(appName: 'MyApp'),
      resetOnError: true, // ✅ معالجة تلقائية
      afterReset: () {
        print('📢 Storage was reset due to MAC error');
      },
    );

    print('✅ Storage initialized successfully');
  } catch (e) {
    print('❌ Failed to initialize: $e');
    return;
  }

  runApp(const MyApp());
}


// =====================================================================
// التطبيق الرئيسي
// =====================================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HiveSecure Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ✅ استخدم Service بدلاً من إنشاء storage جديد
  final storage = SecureStorageService();
  String _status = 'Ready';

  @override
  Widget build(BuildContext context) {
    // ✅ التحقق من التهيئة
    if (!storage.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('HiveSecure Demo')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing storage...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('HiveSecure Config Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Card
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_status),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // معلومات التكوين الحالي
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Configuration',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  _buildConfigInfo('Suffix', storage.config.suffix),
                  _buildConfigInfo(
                    'Rotation Interval',
                    '${storage.config.rotationInterval.inDays} days',
                  ),
                  _buildConfigInfo(
                    'Auto Rotate',
                    storage.config.autoRotate ? 'Enabled' : 'Disabled',
                  ),
                  _buildConfigInfo(
                    'Key Wrapping',
                    storage.config.useKeyWrapping ? 'Enabled' : 'Disabled',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // معلومات الأمان
          FutureBuilder<SecurityInfo>(
            future: _getSecurityInfo(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              final info = snapshot.data!;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Security Information',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      _buildConfigInfo('Security Level', info.level.name),
                      _buildConfigInfo(
                        'Last Rotation',
                        info.lastRotation?.toString() ?? 'Never',
                      ),
                      _buildConfigInfo(
                        'Days Until Next',
                        info.daysLeft?.toString() ?? 'N/A',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Test Operations
          Text(
            'Test Operations',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),

          ElevatedButton.icon(
            onPressed: _testSaveData,
            icon: const Icon(Icons.save),
            label: const Text('Save Test Data'),
          ),

          const SizedBox(height: 8),

          ElevatedButton.icon(
            onPressed: _testLoadData,
            icon: const Icon(Icons.folder_open),
            label: const Text('Load Test Data'),
          ),

          const SizedBox(height: 16),

          // Key Management
          Text(
            'Key Management',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),

          ElevatedButton.icon(
            onPressed: _rotateKeys,
            icon: const Icon(Icons.refresh),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            label: const Text('Rotate Master Key'),
          ),

          const SizedBox(height: 16),

          // Emergency Actions
          Text(
            'Emergency Actions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),

          ElevatedButton.icon(
            onPressed: _resetStorage,
            icon: const Icon(Icons.delete_forever),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            label: const Text('Reset Everything'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<SecurityInfo> _getSecurityInfo() async {
    final level = await storage.getSecurityLevel();
    final lastRotation = await storage.getLastRotationDate();
    final daysLeft = await storage.getDaysUntilNextRotation();

    print('hhhhhhhhhhhhhhhhhhhhhhh111111111111');
    return SecurityInfo(
      level: level,
      lastRotation: lastRotation,
      daysLeft: daysLeft,
    );
  }

  Future<void> _testSaveData() async {
    try {
      await storage.setValue(HiveKeys.theme, true);
      await storage.setValue(HiveKeys.lang, 'ar');
      await storage.setSecureValue(HiveKeys.token, 'test_token_123');

      setState(() => _status = '✅ Data saved successfully');
    } catch (e) {
      setState(() => _status = '❌ Save error: $e');
    }
  }

  Future<void> _testLoadData() async {
    try {
      final theme =  storage.getValue<bool>(HiveKeys.theme);
      final lang =  storage.getValue<String>(HiveKeys.lang);
      final token = await storage.getSecureValue(HiveKeys.token);

      setState(() {
        _status = '✅ Data loaded:\n'
            'Theme: $theme\n'
            'Lang: $lang\n'
            'Token: $token';
      });
    } catch (e) {
      setState(() => _status = '❌ Load error: $e');
    }
  }

  Future<void> _rotateKeys() async {
    try {
      setState(() => _status = '⏳ Rotating keys...');

      await storage.rotateMasterKey(
        onSuccess: () {
          setState(() => _status = '✅ Keys rotated successfully');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Key rotated successfully')),
            );
          }
        },
        onError: (error) {
          setState(() => _status = '❌ Rotation failed: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('❌ Rotation failed: $error')),
            );
          }
        },
      );
    } catch (e) {
      setState(() => _status = '❌ Rotation error: $e');
    }
  }

  Future<void> _resetStorage() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Reset Storage'),
        content: const Text(
          'This will delete all stored data and keys.\n\n'
              'This action cannot be undone.\n\n'
              'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() => _status = '⏳ Resetting...');
        await storage.resetEverything();


        setState(() => _status = '✅ Storage reset successfully');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Storage reset. Please restart the app.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        setState(() => _status = '❌ Reset error: $e');
      }
    }
  }

}

class SecurityInfo {
  final SecurityLevel level;
  final DateTime? lastRotation;
  final int? daysLeft;

  SecurityInfo({
    required this.level,
    this.lastRotation,
    this.daysLeft,
  });
}