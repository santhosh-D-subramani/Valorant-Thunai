import 'package:flutter/material.dart';

enum AppThemeMode { system, light, dark }

class ThemeConfig {
  final Color seedColor;
  final bool useDynamicColor;
  final AppThemeMode themeMode;
  final double blendLevel;
  final bool pureBlackDark;

  const ThemeConfig({
    required this.seedColor,
    required this.useDynamicColor,
    required this.themeMode,
    required this.blendLevel,
    required this.pureBlackDark,
  });

  ThemeConfig copyWith({
    Color? seedColor,
    bool? useDynamicColor,
    AppThemeMode? themeMode,
    double? blendLevel,
    bool? pureBlackDark,
  }) {
    return ThemeConfig(
      seedColor: seedColor ?? this.seedColor,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      themeMode: themeMode ?? this.themeMode,
      blendLevel: blendLevel ?? this.blendLevel,
      pureBlackDark: pureBlackDark ?? this.pureBlackDark,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seedColor': seedColor.toARGB32(),
      'useDynamicColor': useDynamicColor,
      'themeMode': themeMode.index,
      'blendLevel': blendLevel,
      'pureBlackDark': pureBlackDark,
    };
  }

  factory ThemeConfig.fromJson(Map<String, dynamic> json) {
    return ThemeConfig(
      seedColor: Color(json['seedColor'] as int? ?? Colors.blue.toARGB32()),
      useDynamicColor: json['useDynamicColor'] as bool? ?? true,
      themeMode: AppThemeMode.values[json['themeMode'] as int? ?? 0],
      blendLevel: (json['blendLevel'] as num? ?? 0.25).toDouble(),
      pureBlackDark: json['pureBlackDark'] as bool? ?? false,
    );
  }

  static const defaultConfig = ThemeConfig(
    seedColor: Colors.blue,
    useDynamicColor: true,
    themeMode: AppThemeMode.system,
    blendLevel: 0.25,
    pureBlackDark: false,
  );
}
