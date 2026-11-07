import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_thunai/providers/locale_provider.dart';
import 'package:valorant_thunai/services/logger_service.dart';
import 'package:valorant_thunai/services/remote_config_service.dart';
import 'package:valorant_thunai/services/valorant_api.dart';
import 'package:valorant_thunai/services/widget_sync_service.dart';
import 'package:valorant_thunai/theme/theme_notifier.dart';
import 'package:valorant_thunai/valorant_thunai.dart';

late final SharedPreferences prefs;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await WidgetSyncService.initialize();
  } catch (e) {
    LoggerService.log('Widget sync init failed: $e', tag: 'System');
  }

  try {
    await RemoteConfigService.instance.initialize();
  } catch (e) {
    LoggerService.log('Remote Config Initialization failed: $e', tag: 'System');
  }

  prefs = await SharedPreferences.getInstance();
  LoggerService.initFromPrefs(prefs);
  await ValorantApi.loadCustomApiKey();

  final savedTheme = await ThemeNotifier.loadFromPrefs();
  final savedLocale = await LocaleNotifier.loadFromPrefs();

  runApp(
    ProviderScope(
      overrides: [
        themeProvider.overrideWith((ref) => ThemeNotifier(savedTheme)),
        localeProvider.overrideWith((ref) => LocaleNotifier(savedLocale)),
      ],
      child: const ValorantThunai(),
    ),
  );
}
