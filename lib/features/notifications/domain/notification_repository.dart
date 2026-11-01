import 'package:matchunsa/features/notifications/domain/user_notification.dart';

abstract interface class NotificationRepository {
  Future<List<UserNotification>> getNotifications(String userId);

  Future<void> markAsRead(String notificationId);

  Future<void> markAllAsRead(String userId);

  Future<int> syncNotifications(String userId);
}
