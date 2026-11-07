import 'dart:convert';

class AppNotification {
  final String remoteId;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final String? payload;

  AppNotification({
    required this.remoteId,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.payload,
  });

  AppNotification copyWith({
    String? remoteId,
    String? title,
    String? body,
    DateTime? timestamp,
    bool? isRead,
    String? payload,
  }) {
    return AppNotification(
      remoteId: remoteId ?? this.remoteId,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      payload: payload ?? this.payload,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'remoteId': remoteId,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'payload': payload,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      remoteId: map['remoteId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      payload: map['payload'],
    );
  }

  String toJson() => json.encode(toMap());

  factory AppNotification.fromJson(String source) =>
      AppNotification.fromMap(json.decode(source));
}
