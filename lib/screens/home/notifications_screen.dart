import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:valorant_thunai/providers/display_settings_provider.dart';
import 'package:valorant_thunai/services/notification_service.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';
import 'package:valorant_thunai/utils/format_utils.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notifications = ref.watch(notificationProvider);
    final notifier = ref.read(notificationProvider.notifier);
    final displaySettings = ref.watch(displaySettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        actions: [
          IconButton(
            onPressed: () {
              notifier.clearAll();
            },
            icon: const Icon(Icons.clear_all),
          ),
        ],
      ),
      body: SafeArea(
        child: notifications.isEmpty
            ? Center(
                child: Text(
                  l10n.noNotificationsYet,
                  style: const TextStyle(color: Colors.grey),
                ),
              )
            : ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Icon(
                        notification.isRead
                            ? Icons.notifications_none
                            : Icons.notifications_active,
                        color: notification.isRead
                            ? Colors.grey
                            : Colors.blueAccent,
                      ),
                      title: Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight: notification.isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            notification.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            FormatUtils.formatDateTime(
                              notification.timestamp,
                              displaySettings,
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      onTap: () async {
                        if (!notification.isRead) {
                          await notifier.markAsRead(notification.remoteId);
                        }

                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(notification.title),
                              content: Text(notification.body),
                              actions: [
                                TextButton(
                                  child: Text(l10n.close),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
