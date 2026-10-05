class NotificationItem {
  final String id;
  final String collegeId;
  final String? recipientUserId;
  final String recipientRole; // 'admin', 'teacher', 'student', 'all'
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? relatedType;
  final String? relatedId;

  NotificationItem({
    required this.id,
    required this.collegeId,
    this.recipientUserId,
    this.recipientRole = 'all',
    required this.title,
    required this.message,
    DateTime? timestamp,
    this.isRead = false,
    this.relatedType,
    this.relatedId,
  }) : timestamp = timestamp ?? DateTime.now();

  factory NotificationItem.fromJson(Map<String, dynamic> json, {String? id}) {
    return NotificationItem(
      id: id ?? json['id'] as String? ?? '',
      collegeId: json['collegeId'] as String? ?? '',
      recipientUserId: json['recipientUserId'] as String?,
      recipientRole: json['recipientRole'] as String? ?? 'all',
      title: json['title'] as String? ?? 'Notification',
      message: json['message'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      relatedType: json['relatedType'] as String?,
      relatedId: json['relatedId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collegeId': collegeId,
      'recipientUserId': recipientUserId,
      'recipientRole': recipientRole,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'relatedType': relatedType,
      'relatedId': relatedId,
    };
  }

  NotificationItem copyWith({
    String? id,
    String? collegeId,
    String? recipientUserId,
    String? recipientRole,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    String? relatedType,
    String? relatedId,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      collegeId: collegeId ?? this.collegeId,
      recipientUserId: recipientUserId ?? this.recipientUserId,
      recipientRole: recipientRole ?? this.recipientRole,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      relatedType: relatedType ?? this.relatedType,
      relatedId: relatedId ?? this.relatedId,
    );
  }
}
