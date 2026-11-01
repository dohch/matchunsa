import 'package:matchunsa/features/notifications/domain/notification_repository.dart';
import 'package:matchunsa/features/notifications/domain/notification_type.dart';
import 'package:matchunsa/features/notifications/domain/user_notification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<UserNotification>> getNotifications(String userId) async {
    // Attempt auto-syncing notifications first
    try {
      await syncNotifications(userId);
    } catch (_) {
      // Ignore background sync errors and continue fetching stored notifications
    }

    final rows = await _client
        .from('user_notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _client.from('user_notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', notificationId);
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    await _client
        .from('user_notifications')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  @override
  Future<int> syncNotifications(String userId) async {
    final result = await _client.rpc(
      'sync_user_notifications',
      params: {'p_user_id': userId},
    );

    if (result is int) return result;
    if (result is num) return result.toInt();
    return 0;
  }

  UserNotification _fromRow(Map<String, dynamic> row) {
    return UserNotification(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      title: row['title'] as String,
      message: row['message'] as String,
      type: NotificationType.fromDatabaseValue(row['type'] as String),
      opportunityId: row['opportunity_id'] as String?,
      isRead: (row['is_read'] as bool?) ?? false,
      readAt: _date(row['read_at']),
      createdAt: _date(row['created_at']),
    );
  }

  DateTime? _date(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
