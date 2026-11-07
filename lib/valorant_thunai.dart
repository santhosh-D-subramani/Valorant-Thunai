import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:valorant_thunai/router/zen_router.dart';
import 'package:valorant_thunai/theme/models/theme_config.dart';
import 'package:valorant_thunai/theme/app_theme.dart';
import 'package:valorant_thunai/theme/theme_notifier.dart';
import 'package:valorant_thunai/constants.dart';
import 'package:valorant_thunai/services/logger_service.dart';

import 'package:valorant_thunai/providers/locale_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';

class ValorantThunai extends ConsumerStatefulWidget {
  const ValorantThunai({super.key});

  @override
  ConsumerState<ValorantThunai> createState() => _ValorantThunaiState();
}

class _ValorantThunaiState extends ConsumerState<ValorantThunai> {
  StreamSubscription<Uri?>? _widgetClickSub;

  @override
  void initState() {
    super.initState();
    _handleHomeWidgetLaunch();
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    super.dispose();
  }

  Future<void> _handleHomeWidgetLaunch() async {
    try {
      final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (initialUri != null) {
        _goToDailyShop();
      }
    } catch (e) {
      LoggerService.log(
        'initiallyLaunchedFromHomeWidget error: $e',
        tag: 'Widget',
      );
    }

    _widgetClickSub = HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) {
        _goToDailyShop();
      }
    });
  }

  void _goToDailyShop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(appCoordinatorProvider).switchToTab(AppTab.home.index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.watch(appCoordinatorProvider);
    final config = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final Color seed = config.useDynamicColor && lightDynamic != null
            ? lightDynamic.primary
            : config.seedColor;

        final themeMode = switch (config.themeMode) {
          AppThemeMode.light => ThemeMode.light,
          AppThemeMode.dark => ThemeMode.dark,
          AppThemeMode.system => ThemeMode.system,
        };

        return MaterialApp.router(
          title: appName,
          themeMode: themeMode,
          locale: locale,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(
            brightness: Brightness.light,
            seedColor: seed,
            blendLevel: config.blendLevel,
            pureBlackDark: false,
          ),
          darkTheme: buildTheme(
            brightness: Brightness.dark,
            seedColor: seed,
            blendLevel: config.blendLevel,
            pureBlackDark: config.pureBlackDark,
          ),
          routerDelegate: coordinator.routerDelegate,
          routeInformationParser: coordinator.routeInformationParser,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        );
      },
    );
  }
}
