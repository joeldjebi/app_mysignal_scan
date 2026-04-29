import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../core/widgets/app_shell_widgets.dart';
import '../models/api_models.dart';
import '../state/session_controller.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, required this.controller});

  final PartnerSessionController controller;

  Future<void> _markAllAsRead(BuildContext context) async {
    try {
      await controller.markAllNotificationsAsRead();
    } on ApiException catch (error) {
      if (!context.mounted) {
        return;
      }
      _showError(context, error.message);
    }
  }

  Future<void> _markAsRead(
    BuildContext context,
    PartnerNotification notification,
  ) async {
    if (!notification.isUnread) {
      return;
    }

    try {
      await controller.markNotificationAsRead(notification.id);
    } on ApiException catch (error) {
      if (!context.mounted) {
        return;
      }
      _showError(context, error.message);
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifications = controller.notifications;
    final unreadCount = controller.unreadNotificationsCount;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications'),
            Text(
              unreadCount == 0
                  ? 'Aucune non lue'
                  : '$unreadCount non lue${unreadCount > 1 ? 's' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          if (notifications.isNotEmpty)
            IconButton(
              tooltip: 'Tout marquer comme lu',
              onPressed: unreadCount == 0
                  ? null
                  : () => _markAllAsRead(context),
              icon: const Icon(Icons.done_all_rounded),
            ),
          IconButton(
            tooltip: 'Actualiser',
            onPressed: controller.isLoadingNotifications
                ? null
                : () => controller.refreshNotifications(showLoader: true),
            icon: controller.isLoadingNotifications
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: buildGradientBackground(
        child: RefreshIndicator(
          onRefresh: () => controller.refreshNotifications(showLoader: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            children: [
              if (controller.pushWarning != null) ...[
                PremiumSection(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.orange,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          controller.pushWarning!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (notifications.isEmpty)
                const EmptyStateCard(
                  title: 'Aucune notification',
                  description:
                      'Les messages importants et alertes liees a vos scans apparaitront ici.',
                  icon: Icons.notifications_none_rounded,
                )
              else
                ...notifications.map(
                  (notification) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _NotificationTile(
                      notification: notification,
                      onTap: () => _markAsRead(context, notification),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final PartnerNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = notification.isUnread;

    return PremiumSection(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: unread
                    ? AppColors.primary.withValues(alpha: 0.14)
                    : AppColors.softBorder.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                unread
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_rounded,
                color: unread ? AppColors.primary : AppColors.muted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.mint.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          notification.categoryLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Non lue',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.orange,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    notification.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                    ),
                  ),
                  if (notification.body.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    formatDate(notification.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
