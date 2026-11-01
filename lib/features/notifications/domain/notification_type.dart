import 'package:flutter/material.dart';

enum NotificationType {
  newOpportunity,
  closingSoon,
  applicationUpdate,
  system;

  String get databaseValue => switch (this) {
        NotificationType.newOpportunity => 'new_opportunity',
        NotificationType.closingSoon => 'closing_soon',
        NotificationType.applicationUpdate => 'application_update',
        NotificationType.system => 'system',
      };

  IconData get icon => switch (this) {
        NotificationType.newOpportunity => Icons.campaign_rounded,
        NotificationType.closingSoon => Icons.alarm_rounded,
        NotificationType.applicationUpdate => Icons.assignment_turned_in_rounded,
        NotificationType.system => Icons.notifications_rounded,
      };

  Color get color => switch (this) {
        NotificationType.newOpportunity => const Color(0xFF5E151D),
        NotificationType.closingSoon => const Color(0xFFF57C00),
        NotificationType.applicationUpdate => const Color(0xFF141E42),
        NotificationType.system => const Color(0xFF1E88E5),
      };

  static NotificationType fromDatabaseValue(String value) {
    return switch (value.trim().toLowerCase()) {
      'new_opportunity' => NotificationType.newOpportunity,
      'closing_soon' => NotificationType.closingSoon,
      'application_update' => NotificationType.applicationUpdate,
      _ => NotificationType.system,
    };
  }
}
