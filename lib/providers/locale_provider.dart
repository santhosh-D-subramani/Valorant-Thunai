import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleNotifier extends StateNotifier<Locale?> {
  static const String _keyLocale = 'app_selected_locale';

  LocaleNotifier([Locale? initialLocale]) : super(initialLocale) {
    if (initialLocale == null) {
      _load();
    }
  }

  Future<void> _load() async {
    state = await loadFromPrefs();
  }

  static Future<Locale?> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_keyLocale);
      if (code != null && code.isNotEmpty && code != 'system') {
        return Locale(code);
      }
      return null;
    } catch (e) {
      debugPrint('Error loading locale: $e');
      return null;
    }
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.setString(_keyLocale, 'system');
      } else {
        await prefs.setString(_keyLocale, locale.languageCode);
      }
    } catch (e) {
      debugPrint('Error saving locale: $e');
    }
  }

  static bool isIndia() {
    try {
      final dispatcher = ui.PlatformDispatcher.instance;
      final currentLocale = dispatcher.locale;
      if (currentLocale.countryCode?.toUpperCase() == 'IN') return true;
      for (final loc in dispatcher.locales) {
        if (loc.countryCode?.toUpperCase() == 'IN') return true;
      }
    } catch (_) {}
    return false;
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>(
  (ref) => LocaleNotifier(),
);
