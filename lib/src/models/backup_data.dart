import 'dart:convert';

/// نموذج النسخة الاحتياطية مع HMAC للتحقق من السلامة
class BackupData {
  final String data;
  final String hmac;
  final String timestamp;

  BackupData({
    required this.data,
    required this.hmac,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'data': data,
    'hmac': hmac,
    'timestamp': timestamp,
  };

  factory BackupData.fromJson(Map<String, dynamic> json) => BackupData(
    data: json['data'] as String,
    hmac: json['hmac'] as String,
    timestamp: json['timestamp'] as String,
  );

  String toJsonString() => jsonEncode(toJson());

  factory BackupData.fromJsonString(String jsonStr) =>
      BackupData.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
}