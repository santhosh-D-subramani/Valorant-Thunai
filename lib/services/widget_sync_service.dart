import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:home_widget/home_widget.dart';
import 'package:valorant_thunai/services/logger_service.dart';

class WidgetSyncService {
  static const String appGroupId =
      'group.com.santhoshDsubramani.valorantThunai';
  static const String androidWidgetProvider =
      'com.santhoshDsubramani.valorant_thunai.StoreWidgetProvider';
  static const String iosWidgetName = 'StoreWidget';

  static Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(appGroupId);
      }
    } catch (e) {
      LoggerService.log('HomeWidget init error: $e', tag: 'Widget');
    }
  }

  static Future<void> syncDailyShop({
    required List<Map<String, dynamic>> skins,
    required int remainingDurationInSeconds,
    String? expiryLabel,
    int? expirySeconds,
  }) async {
    if (kIsWeb) return;

    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(appGroupId);
      }

      final now = DateTime.now();
      final resetEpochMillis = now
          .add(Duration(seconds: remainingDurationInSeconds))
          .millisecondsSinceEpoch;

      final bool hasExpiry =
          expiryLabel != null &&
          expiryLabel.isNotEmpty &&
          expirySeconds != null &&
          expirySeconds > 0;
      final int expiryEpochMillis = hasExpiry
          ? now.add(Duration(seconds: expirySeconds)).millisecondsSinceEpoch
          : 0;

      await HomeWidget.saveWidgetData<bool>('has_expiry', hasExpiry);
      await HomeWidget.saveWidgetData<String>(
        'expiry_label',
        hasExpiry ? expiryLabel : '',
      );
      await HomeWidget.saveWidgetData<int>(
        'expiry_timestamp',
        expiryEpochMillis,
      );

      final List<Map<String, dynamic>> preparedSkins = [];

      for (int i = 0; i < skins.length && i < 4; i++) {
        final skin = skins[i];
        final name = skin['name'] as String? ?? 'Valorant Skin';
        final price = skin['price']?.toString() ?? '0';
        final iconUrl = skin['iconUrl'] as String? ?? '';
        final tierColor = skin['tierColor'] as String? ?? '#FFFFFFFF';

        String localImagePath = '';
        if (iconUrl.isNotEmpty) {
          try {
            final file = await DefaultCacheManager().getSingleFile(iconUrl);
            localImagePath = file.path;
          } catch (_) {
            localImagePath = '';
          }
        }

        preparedSkins.add({
          'name': name,
          'price': price,
          'iconUrl': iconUrl,
          'localImagePath': localImagePath,
          'tierColor': tierColor,
        });

        await HomeWidget.saveWidgetData<String>('skin_${i}_name', name);
        await HomeWidget.saveWidgetData<String>('skin_${i}_price', price);
        await HomeWidget.saveWidgetData<String>('skin_${i}_icon', iconUrl);
        await HomeWidget.saveWidgetData<String>(
          'skin_${i}_image_path',
          localImagePath,
        );
        await HomeWidget.saveWidgetData<String>(
          'skin_${i}_tier_color',
          tierColor,
        );
      }

      await HomeWidget.saveWidgetData<int>('skins_count', preparedSkins.length);
      await HomeWidget.saveWidgetData<int>('reset_timestamp', resetEpochMillis);
      await HomeWidget.saveWidgetData<int>(
        'last_updated',
        now.millisecondsSinceEpoch,
      );
      await HomeWidget.saveWidgetData<bool>('user_logged_in', true);
      await HomeWidget.saveWidgetData<String>(
        'daily_skins_json',
        jsonEncode(preparedSkins),
      );

      await HomeWidget.updateWidget(
        name: 'StoreWidgetProvider',
        iOSName: iosWidgetName,
        qualifiedAndroidName: androidWidgetProvider,
      );

      LoggerService.log(
        'Synced ${preparedSkins.length} daily skins to Home Widget. Reset at: $resetEpochMillis',
        tag: 'Widget',
      );
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('ClassNotFoundException') ||
          errStr.contains('No Widget found')) {
        LoggerService.log(
          'Widget update pending full app rebuild (native widget class not yet in active APK)',
          tag: 'Widget',
        );
      } else {
        LoggerService.log('WidgetSyncService error: $e', tag: 'Widget');
      }
    }
  }

  static Future<void> clearWidgetData() async {
    if (kIsWeb) return;
    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(appGroupId);
      }
      await HomeWidget.saveWidgetData<bool>('user_logged_in', false);
      await HomeWidget.saveWidgetData<int>('skins_count', 0);
      await HomeWidget.saveWidgetData<String>('daily_skins_json', '[]');
      await HomeWidget.saveWidgetData<bool>('has_expiry', false);
      await HomeWidget.saveWidgetData<String>('expiry_label', '');
      await HomeWidget.saveWidgetData<int>('expiry_timestamp', 0);

      await HomeWidget.updateWidget(
        name: 'StoreWidgetProvider',
        iOSName: iosWidgetName,
        qualifiedAndroidName: androidWidgetProvider,
      );
    } catch (e) {
      LoggerService.log('Error clearing widget data: $e', tag: 'Widget');
    }
  }
}
