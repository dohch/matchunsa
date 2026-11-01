import 'package:flutter/material.dart';
import 'package:matchunsa/app/theme/app_theme.dart';
import 'package:matchunsa/app/widgets/mu_empty_state.dart';
import 'package:matchunsa/app/widgets/mu_surface.dart';
import 'package:matchunsa/features/notifications/domain/notification_repository.dart';
import 'package:matchunsa/features/notifications/domain/user_notification.dart';
import 'package:matchunsa/features/opportunities/domain/opportunity_repository.dart';
import 'package:matchunsa/features/opportunities/presentation/opportunity_detail_page.dart';

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({
    super.key,
    required this.userId,
    required this.notificationRepository,
    required this.opportunityRepository,
  });

  final String userId;
  final NotificationRepository notificationRepository;
  final OpportunityRepository opportunityRepository;

  static Future<void> show({
    required BuildContext context,
    required String userId,
    required NotificationRepository notificationRepository,
    required OpportunityRepository opportunityRepository,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NotificationsSheet(
        userId: userId,
        notificationRepository: notificationRepository,
        opportunityRepository: opportunityRepository,
      ),
    );
  }

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  List<UserNotification> _notifications = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list =
          await widget.notificationRepository.getNotifications(widget.userId);
      if (!mounted) return;
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las notificaciones.';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(UserNotification item) async {
    if (item.isRead) return;
    try {
      await widget.notificationRepository.markAsRead(item.id);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((n) => n.id == item.id ? n.copyWith(isRead: true) : n)
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    try {
      await widget.notificationRepository.markAllAsRead(widget.userId);
      if (!mounted) return;
      setState(() {
        _notifications =
            _notifications.map((n) => n.copyWith(isRead: true)).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notificaciones marcadas como leídas.')),
      );
    } catch (_) {}
  }

  Future<void> _handleNotificationTap(UserNotification item) async {
    await _markAsRead(item);
    if (!mounted) return;

    if (item.opportunityId != null) {
      final oppId = item.opportunityId!;
      try {
        final opportunities =
            await widget.opportunityRepository.getOpportunities();
        final match = opportunities.where((o) => o.id == oppId).firstOrNull;
        if (match != null && mounted) {
          Navigator.of(context).pop();
          Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => OpportunityDetailPage(opportunity: match),
            ),
          );
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grabber.
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 2),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.hairline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            // Header.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                children: [
                  const MuIconBadge(
                    icon: Icons.notifications_active_outlined,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notificaciones',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (unreadCount > 0)
                          Text(
                            '$unreadCount sin leer',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.maroon),
                          ),
                      ],
                    ),
                  ),
                  if (unreadCount > 0)
                    TextButton(
                      onPressed: _markAllAsRead,
                      child: const Text('Marcar todas leídas',
                          style: TextStyle(fontSize: 12)),
                    ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildContent(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: MuLoading(),
      );
    }

    if (_error case final error?) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return const SizedBox(
        height: 240,
        child: MuEmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'Sin notificaciones',
          message:
              'Te avisaremos cuando haya convocatorias de tu carrera o próximas a vencer.',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: _notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _notifications[index];
        final type = item.type;

        return Material(
          color: item.isRead
              ? Colors.transparent
              : AppTheme.maroon.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => _handleNotificationTap(item),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type icon in soft colored circle.
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: type.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(type.icon, color: type.color, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontWeight: item.isRead
                                      ? FontWeight.w600
                                      : FontWeight.bold,
                                  fontSize: 13,
                                  color: AppTheme.navy,
                                ),
                              ),
                            ),
                            if (!item.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.maroon,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.message,
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (item.createdAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(item.createdAt!),
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.gray),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
