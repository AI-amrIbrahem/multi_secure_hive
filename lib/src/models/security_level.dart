/// مستويات الأمان المتاحة
enum SecurityLevel {
  /// تخزين برمجي (أقل أماناً)
  software,

  /// تخزين في TEE (Trusted Execution Environment)
  tee,

  /// تخزين في Hardware (StrongBox/Secure Enclave)
  hardware,
}