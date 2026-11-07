import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:valorant_thunai/theme/models/theme_config.dart';

import 'package:valorant_thunai/theme/theme_notifier.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class ColorPreset {
  final String name;
  final Color primary;
  final Color secondary;
  final bool isPremium;

  ColorPreset({
    required this.name,
    required this.primary,
    required this.secondary,
    this.isPremium = false,
  });
}

class AppearancePage extends ConsumerStatefulWidget {
  const AppearancePage({super.key});

  @override
  ConsumerState<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends ConsumerState<AppearancePage> {
  final ScrollController _scrollController = ScrollController();

  final List<ColorPreset> _presets = [
    ColorPreset(
      name: 'Default',
      primary: const Color(0xFFFF4655),
      secondary: const Color(0xFF0F1923),
    ),
    ColorPreset(
      name: 'Green Apple',
      primary: const Color(0xFF4CAF50),
      secondary: const Color(0xFF1B5E20),
    ),
    ColorPreset(
      name: 'Lavender',
      primary: const Color(0xFF9C27B0),
      secondary: const Color(0xFF4A148C),
    ),
    ColorPreset(
      name: 'Midnight',
      primary: const Color(0xFF3F51B5),
      secondary: const Color(0xFF1A237E),
    ),
    ColorPreset(
      name: 'Orange',
      primary: const Color(0xFFFF9800),
      secondary: const Color(0xFFE65100),
    ),
    ColorPreset(
      name: 'Teal',
      primary: const Color(0xFF009688),
      secondary: const Color(0xFF004D40),
    ),
    ColorPreset(
      name: 'Red',
      primary: const Color(0xFFF44336),
      secondary: const Color(0xFFB71C1C),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToActivePreset();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActivePreset() {
    final themeConfig = ref.read(themeProvider);
    final activeIndex = _presets.indexWhere(
      (p) => themeConfig.seedColor.toARGB32() == p.primary.toARGB32(),
    );

    if (activeIndex != -1 && _scrollController.hasClients) {
      final cardWidth = 140.0 + 12.0;
      final screenWidth = MediaQuery.of(context).size.width;
      final targetScroll = (activeIndex * cardWidth);
      final offset = targetScroll - (screenWidth / 2) + (cardWidth / 2);

      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appearanceTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          children: [
            _buildSectionHeader(context, l10n.themeSectionHeader),

            ListTile(
              leading: const Icon(Icons.brightness_6),
              title: Text(l10n.appThemeOption),
              subtitle: Text(_getThemeModeName(l10n, themeConfig.themeMode)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showThemeModeDialog(
                context,
                ref,
                themeConfig.themeMode,
                l10n,
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 180,
              child: _buildFadeList(
                context,
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _presets.length,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final preset = _presets[index];
                    return _buildColorCard(
                      context,
                      ref,
                      _getPresetLocalizedName(l10n, preset.name),
                      preset.primary,
                      preset.secondary,
                      themeConfig.seedColor.toARGB32() ==
                          preset.primary.toARGB32(),
                      isPremium: preset.isPremium,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            ListTile(
              title: Text(l10n.pureBlackDarkModeTitle),
              subtitle: Text(l10n.pureBlackDarkModeSubtitle),
              leading: const Icon(Icons.dark_mode_outlined),
              trailing: Switch(
                value: themeConfig.pureBlackDark,
                onChanged: (value) => notifier.togglePureBlack(value),
              ),
            ),

            ListTile(
              title: Text(l10n.useSystemColorsTitle),
              subtitle: Text(l10n.useSystemColorsSubtitle),
              leading: const Icon(Icons.colorize),
              trailing: Switch(
                value: themeConfig.useDynamicColor,
                onChanged: (value) => notifier.toggleDynamicColor(value),
              ),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.layers_outlined, color: Colors.grey),
                      const SizedBox(width: 16),
                      Text(
                        l10n.colorBlendLevelTitle,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: themeConfig.blendLevel.clamp(0.1, 1.0),
                          min: 0.1,
                          max: 1.0,
                          divisions: 9,
                          label: (themeConfig.blendLevel * 10).toStringAsFixed(
                            0,
                          ),
                          onChanged: (value) => notifier.setBlendLevel(value),
                        ),
                      ),
                      Text(
                        (themeConfig.blendLevel * 10).toStringAsFixed(0),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          notifier.setBlendLevel(0.3);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFadeList(BuildContext context, {required Widget child}) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0.0, 0.05, 0.95, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
        ),
        child: child,
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildColorCard(
    BuildContext context,
    WidgetRef ref,
    String name,
    Color primary,
    Color secondary,
    bool isSelected, {
    bool isPremium = false,
  }) {
    return GestureDetector(
      onTap: () {
        ref.read(themeProvider.notifier).setSeedColor(primary);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                )
              : Border.all(color: Colors.transparent, width: 3),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Row(
                    children: [
                      Expanded(child: Container(color: primary)),
                      Expanded(child: Container(color: secondary)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isPremium) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.star,
                    size: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getThemeModeName(AppLocalizations l10n, AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return l10n.themeSystem;
      case AppThemeMode.light:
        return l10n.themeLight;
      case AppThemeMode.dark:
        return l10n.themeDark;
    }
  }

  String _getPresetLocalizedName(AppLocalizations l10n, String name) {
    switch (name.toLowerCase()) {
      case 'default':
        return l10n.colorPresetDefault;
      case 'green apple':
        return l10n.colorPresetGreenApple;
      case 'lavender':
        return l10n.colorPresetLavender;
      case 'midnight':
        return l10n.colorPresetMidnight;
      case 'orange':
        return l10n.colorPresetOrange;
      case 'teal':
        return l10n.colorPresetTeal;
      case 'red':
        return l10n.colorPresetRed;
      default:
        return name;
    }
  }

  void _showThemeModeDialog(
    BuildContext context,
    WidgetRef ref,
    AppThemeMode currentMode,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.appThemeOption),
        children: AppThemeMode.values.map((mode) {
          final isSelected = mode == currentMode;
          return SimpleDialogOption(
            onPressed: () {
              ref.read(themeProvider.notifier).setThemeMode(mode);
              Navigator.of(context).pop();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_getThemeModeName(l10n, mode)),
                if (isSelected)
                  Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
