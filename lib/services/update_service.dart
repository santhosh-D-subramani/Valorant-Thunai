import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:valorant_thunai/services/remote_config_service.dart';

import 'logger_service.dart';

import 'package:valorant_thunai/l10n/app_localizations.dart';

class UpdateService {
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.santhoshDsubramani.valorant_thunai';
  static const String developerUrl =
      'https://play.google.com/store/apps/dev?id=6310299424273414832';

  static bool _isChecking = false;
  static bool _hasShownAutomaticThisSession = false;
  static bool _isDialogOpen = false;

  static bool isUpdateEnabled = true;

  static bool _isCurrentVersionBehind(String current, String latest) {
    try {
      final cleanCurrent = current.split('+')[0];
      final cleanLatest = latest.split('+')[0];

      final currentParts = cleanCurrent.split('.').map(int.parse).toList();
      final latestParts = cleanLatest.split('.').map(int.parse).toList();

      final length = currentParts.length > latestParts.length
          ? currentParts.length
          : latestParts.length;
      for (int i = 0; i < length; i++) {
        final currentVal = i < currentParts.length ? currentParts[i] : 0;
        final latestVal = i < latestParts.length ? latestParts[i] : 0;

        if (currentVal < latestVal) return true;
        if (currentVal > latestVal) return false;
      }
    } catch (e) {
      return current != latest;
    }
    return false;
  }

  static Future<void> checkUpdates(
    BuildContext context, {
    bool manual = false,
  }) async {
    if (_isChecking) return;
    if (!manual && _hasShownAutomaticThisSession) return;
    if (_isDialogOpen) return;

    _isChecking = true;
    try {
      final l10n = AppLocalizations.of(context);
      if (manual) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.checkingForUpdates ?? 'Checking for updates...',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }

      final remoteConfig = RemoteConfigService.instance;

      if (manual) {
        try {
          await remoteConfig.refreshManually(context);
        } catch (e) {
          LoggerService.log(
            'Manual remote config fetch failed: $e',
            tag: 'UpdateService',
          );
        }
      }

      final String latestVersion = remoteConfig.latestVersion;
      final bool isForce = remoteConfig.isForceUpdate;
      final String message = remoteConfig.updateMessage;

      isUpdateEnabled = remoteConfig.enableUpdateCheck;

      if (!isUpdateEnabled) {
        LoggerService.log(
          'Update feature disabled remotely.',
          tag: 'UpdateService',
        );
        return;
      }

      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;

      LoggerService.log(
        'DEBUG Update Check: Current=$currentVersion, Latest=$latestVersion, Force=$isForce',
        tag: 'UpdateService',
      );

      if (!manual) {
        _hasShownAutomaticThisSession = true;
      }

      if (_isCurrentVersionBehind(currentVersion, latestVersion)) {
        if (!manual && !isForce) {
          final prefs = await SharedPreferences.getInstance();
          final String today = DateTime.now().toIso8601String().split('T')[0];
          final String? lastCheck = prefs.getString('last_update_check_date');

          if (lastCheck == today) {
            LoggerService.log(
              'Update available (v$latestVersion) but skipping automatic popup (already shown today).',
              tag: 'UpdateService',
            );
            return;
          }
          await prefs.setString('last_update_check_date', today);
        }

        if (context.mounted) {
          showUpdateDialog(
            context,
            isForce: isForce,
            newVersion: latestVersion,
            message: message,
          );
        }
      } else if (manual && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.latestVersionMessage ?? 'You are on the latest version!',
            ),
          ),
        );
      }
    } catch (e) {
      LoggerService.log('Update check failed: $e', tag: 'UpdateService');
      if (manual && context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.updateCheckFailedMessage ??
                  'Update check failed. Please try again later.',
            ),
          ),
        );
      }
    } finally {
      _isChecking = false;
    }
  }

  static void showUpdateDialog(
    BuildContext context, {
    required bool isForce,
    required String newVersion,
    String? message,
  }) {
    if (_isDialogOpen) return;
    _isDialogOpen = true;
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      barrierDismissible: !isForce,
      builder: (context) => PopScope(
        canPop: !isForce,
        child: AlertDialog(
          title: Text(
            isForce
                ? (l10n?.criticalUpdateRequiredTitle ??
                      'Critical Update Required')
                : (l10n?.updateAvailableTitle ?? 'Update Available!'),
          ),
          content: Text(
            message != null && message.isNotEmpty
                ? message
                : (isForce
                      ? (l10n?.criticalUpdateRequiredBody(newVersion) ??
                            'A critical update (v$newVersion) is required to continue using the app. This fix addresses essential Riot API changes.')
                      : (l10n?.updateAvailableBody(newVersion) ??
                            'A new version (v$newVersion) of Valorant Thunai is ready! Update now for new features and bug fixes.')),
          ),
          actions: [
            if (!isForce)
              TextButton(
                onPressed: () {
                  _isDialogOpen = false;
                  Navigator.pop(context);
                },
                child: Text(l10n?.later ?? 'Later'),
              ),
            ElevatedButton(
              onPressed: () {
                if (!isForce) {
                  _isDialogOpen = false;
                }
                launchUrl(
                  Uri.parse(playStoreUrl),
                  mode: LaunchMode.externalApplication,
                );
                if (!isForce) {
                  Navigator.pop(context);
                }
              },
              child: Text(l10n?.updateNowButton ?? 'Update Now'),
            ),
          ],
        ),
      ),
    ).then((_) {
      _isDialogOpen = false;
    });
  }

  static Future<void> openRating() async {
    final Uri url = Uri.parse('$playStoreUrl&review=1');
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  static Future<void> openOtherApps() async {
    final Uri url = Uri.parse(developerUrl);
    launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
