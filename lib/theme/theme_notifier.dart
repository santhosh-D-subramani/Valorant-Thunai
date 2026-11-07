import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_thunai/theme/models/theme_config.dart';

class ThemeNotifier extends StateNotifier<ThemeConfig> {
  static const _keySeedColor = 'theme_seedColor';
  static const _keyUseDynamicColor = 'theme_useDynamicColor';
  static const _keyThemeMode = 'theme_themeMode';
  static const _keyBlendLevel = 'theme_blendLevel';
  static const _keyPureBlackDark = 'theme_pureBlackDark';

  ThemeNotifier([ThemeConfig? initialConfig])
    : super(initialConfig ?? ThemeConfig.defaultConfig) {
    if (initialConfig == null) {
      _load();
    }
  }

  Future<void> _load() async {
    state = await loadFromPrefs();
  }

  static Future<ThemeConfig> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final seedColorValue =
          prefs.getInt(_keySeedColor) ??
          ThemeConfig.defaultConfig.seedColor.toARGB32();
      final useDynamicColor =
          prefs.getBool(_keyUseDynamicColor) ??
          ThemeConfig.defaultConfig.useDynamicColor;
      final themeModeIndex =
          prefs.getInt(_keyThemeMode) ??
          ThemeConfig.defaultConfig.themeMode.index;
      final blendLevel =
          prefs.getDouble(_keyBlendLevel) ??
          ThemeConfig.defaultConfig.blendLevel;
      final pureBlackDark =
          prefs.getBool(_keyPureBlackDark) ??
          ThemeConfig.defaultConfig.pureBlackDark;

      return ThemeConfig(
        seedColor: Color(seedColorValue),
        useDynamicColor: useDynamicColor,
        themeMode: AppThemeMode
            .values[themeModeIndex.clamp(0, AppThemeMode.values.length - 1)],
        blendLevel: blendLevel,
        pureBlackDark: pureBlackDark,
      );
    } catch (e) {
      debugPrint('Error loading theme config (static): $e');
      return ThemeConfig.defaultConfig;
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setInt(_keySeedColor, state.seedColor.toARGB32()),
        prefs.setBool(_keyUseDynamicColor, state.useDynamicColor),
        prefs.setInt(_keyThemeMode, state.themeMode.index),
        prefs.setDouble(_keyBlendLevel, state.blendLevel),
        prefs.setBool(_keyPureBlackDark, state.pureBlackDark),
      ]);
    } catch (e) {
      debugPrint('Error saving theme config: $e');
    }
  }

  Future<void> restoreFromBackup(ThemeConfig config) async {
    state = config;
    await _save();
  }

  void setSeedColor(Color color) {
    state = state.copyWith(seedColor: color, useDynamicColor: false);
    _save();
  }

  void toggleDynamicColor(bool value) {
    state = state.copyWith(useDynamicColor: value);
    _save();
  }

  void setThemeMode(AppThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _save();
  }

  void setBlendLevel(double value) {
    state = state.copyWith(blendLevel: value.clamp(0.0, 1.0));
    _save();
  }

  void togglePureBlack(bool value) {
    state = state.copyWith(pureBlackDark: value);
    _save();
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeConfig>(
  (ref) => ThemeNotifier(),
);
