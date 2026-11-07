import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_thunai/models/app_notification.dart';

import 'remote_config_service.dart';
import 'logger_service.dart';

final notificationProvider =
    NotifierProvider<NotificationNotifier, List<AppNotification>>(() {
      return NotificationNotifier();
    });

class NotificationNotifier extends Notifier<List<AppNotification>> {
  static const _prefsKey = 'app_notifications_local';

  static const String _localNotificationPrefix = 'local_';

  @override
  List<AppNotification> build() {
    _loadAndSync();
    return [];
  }

  Future<void> _loadAndSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localJsonList = prefs.getStringList(_prefsKey) ?? [];

      final localNotifications = localJsonList
          .map((jsonStr) => AppNotification.fromJson(jsonStr))
          .toList();

      final localMap = {
        for (var notif in localNotifications) notif.remoteId: notif,
      };

      final remoteConfig = ref.read(remoteConfigServiceProvider);
      final remoteData = remoteConfig.appNotifications;

      final mergedNotifications = <AppNotification>[];

      final remoteIds = remoteData
          .map((item) => item['id']?.toString() ?? '')
          .toSet();
      for (final local in localNotifications) {
        if (local.remoteId.startsWith(_localNotificationPrefix) &&
            !remoteIds.contains(local.remoteId)) {
          mergedNotifications.add(local);
        }
      }

      for (final item in remoteData) {
        final remoteId = item['id']?.toString() ?? '';
        if (remoteId.isNotEmpty) {
          final existing = localMap[remoteId];
          if (existing != null) {
            mergedNotifications.add(
              existing.copyWith(
                title: item['title']?.toString() ?? existing.title,
                body: item['body']?.toString() ?? existing.body,
                timestamp:
                    DateTime.tryParse(item['date']?.toString() ?? '') ??
                    existing.timestamp,
              ),
            );
          } else {
            mergedNotifications.add(
              AppNotification(
                remoteId: remoteId,
                title: item['title']?.toString() ?? 'Announcement',
                body: item['body']?.toString() ?? '',
                timestamp:
                    DateTime.tryParse(item['date']?.toString() ?? '') ??
                    DateTime.now(),
                isRead: false,
              ),
            );
          }
        }
      }

      mergedNotifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      state = mergedNotifications;
      _saveToPrefs(mergedNotifications);
    } catch (e) {
      LoggerService.log(
        'Error syncing notifications: $e',
        tag: 'Notifications',
      );
    }
  }

  Future<void> markAsRead(String remoteId) async {
    final updatedList = state.map((notif) {
      if (notif.remoteId == remoteId && !notif.isRead) {
        return notif.copyWith(isRead: true);
      }
      return notif;
    }).toList();

    state = updatedList;
    await _saveToPrefs(updatedList);
  }

  Future<void> clearAll() async {
    state = [];
    await _saveToPrefs([]);
  }

  Future<void> addLocalNotification({
    required String id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final remoteId = '$_localNotificationPrefix$id';
    if (state.any((n) => n.remoteId == remoteId)) return;

    final notification = AppNotification(
      remoteId: remoteId,
      title: title,
      body: body,
      timestamp: DateTime.now(),
      isRead: false,
      payload: payload,
    );

    final updatedList = [notification, ...state];
    state = updatedList;
    await _saveToPrefs(updatedList);
  }

  Future<void> _saveToPrefs(List<AppNotification> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = list.map((n) => n.toJson()).toList();
      await prefs.setStringList(_prefsKey, jsonList);
    } catch (e) {
      LoggerService.log('Error saving notifications: $e', tag: 'Notifications');
    }
  }
}
