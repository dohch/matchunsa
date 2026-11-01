import 'package:matchunsa/features/notifications/domain/notification_type.dart';

class UserNotification {
  const UserNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.opportunityId,
    this.isRead = false,
    this.readAt,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String message;
  final NotificationType type;
  final String? opportunityId;
  final bool isRead;
  final DateTime? readAt;
  final DateTime? createdAt;

  UserNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    NotificationType? type,
    String? opportunityId,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return UserNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      opportunityId: opportunityId ?? this.opportunityId,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
