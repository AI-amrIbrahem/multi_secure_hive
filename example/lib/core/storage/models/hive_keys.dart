import 'package:multi_secure_hive/multi_secure_hive.dart';

/// مفاتيح التخزين الخاصة بمشروعك
enum HiveKeys implements HiveKeyInterface {
  darkMode,
  lang,
  token,
  user,
  onBoarding,
  // ✅ أضف أي key تريده هنا!
  notifications,
  theme,
  lastSync;

  @override
  String get name => toString().split('.').last;
}