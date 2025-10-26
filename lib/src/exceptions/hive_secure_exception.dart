/// استثناء مخصص لأخطاء HiveSecure
class HiveSecureException implements Exception {
  final String message;

  HiveSecureException(this.message);

  @override
  String toString() => 'HiveSecureException: $message';
}