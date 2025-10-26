// =====================================================================
// في الـ Package: lib/src/models/hive_key_interface.dart
// =====================================================================

/// واجهة يجب أن يطبّقها أي Enum للـ Keys
abstract class HiveKeyInterface {
  /// اسم الـ Key (يُستخدم في Hive)
  String get name;
}