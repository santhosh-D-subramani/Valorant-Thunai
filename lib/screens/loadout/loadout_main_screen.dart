import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/providers/loadout_provider.dart';
import 'package:valorant_thunai/providers/weapons_provider.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/utils/cache_managers.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';

import 'dart:math' as math;

import 'package:valorant_thunai/screens/loadout/weapons_list_screen.dart';
import 'package:valorant_thunai/screens/loadout/item_selection_screen.dart';
import 'package:valorant_thunai/screens/loadout/loadout_presets_screen.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class LoadoutMainScreen extends ConsumerStatefulWidget {
  const LoadoutMainScreen({super.key});

  @override
  ConsumerState<LoadoutMainScreen> createState() => _LoadoutMainScreenState();
}

class _LoadoutMainScreenState extends ConsumerState<LoadoutMainScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final loadoutAsync = ref.watch(loadoutProvider);
    final titlesAsync = ref.watch(allTitlesProvider);
    final allSprays = ref.watch(allSpraysProvider).value ?? [];
    final allFlexes = ref.watch(allFlexesProvider).value ?? [];
    final authUser = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.loadoutTitle,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Presets & Randomizer',
            icon: Icon(
              Icons.auto_awesome,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoadoutPresetsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () {
              ref.read(loadoutProvider.notifier).fetchLoadout();
            },
          ),
        ],
      ),
      body: loadoutAsync.when(
        loading: () => const Center(child: FunnyLoadingView()),
        error: (e, _) => Center(
          child: Text(
            l10n.errorMessage(e.toString()),
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ),
        data: (loadout) {
          final rawCardId = loadout['Identity']?['PlayerCardID'] as String?;
          final playerCardId =
              (rawCardId != null &&
                  rawCardId.isNotEmpty &&
                  rawCardId != '00000000-0000-0000-0000-000000000000')
              ? rawCardId
              : (authUser?.playerCardId != null &&
                    authUser!.playerCardId!.isNotEmpty &&
                    authUser.playerCardId !=
                        '00000000-0000-0000-0000-000000000000')
              ? authUser.playerCardId
              : '9fb3f4ab-4c11-1a3b-955e-5e9ad13289f3';

          String titleName = l10n.loadingTitleText;
          final playerTitleId =
              loadout['Identity']?['PlayerTitleID'] as String?;
          if (playerTitleId != null) {
            titlesAsync.when(
              data: (titles) {
                final matched = titles.firstWhere(
                  (t) =>
                      (t['uuid'] as String).toLowerCase() ==
                      playerTitleId.toLowerCase(),
                  orElse: () => null,
                );
                if (matched != null) {
                  titleName =
                      matched['titleText'] ?? matched['displayName'] ?? 'Title';
                } else {
                  titleName = l10n.noTitleText;
                }
              },
              error: (_, _) => titleName = l10n.errorLoadingTitle,
              loading: () => titleName = l10n.loadingTitleText,
            );
          } else {
            titleName = l10n.noTitleText;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.primaryContainer
                      .withValues(alpha: 0.7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoadoutPresetsScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Presets & Randomizer',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                                ),
                                Text(
                                  'Switch loadout profiles or randomize from owned skins',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withValues(alpha: 0.8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ItemSelectionScreen(
                          itemType: 'card',
                          title: l10n.choosePlayerCardTitle,
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CachedNetworkImage(
                              imageUrl:
                                  'https://media.valorant-api.com/playercards/$playerCardId/wideart.png',
                              cacheManager:
                                  CustomCacheManagers.loadoutPresetCacheManager,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                child: Center(
                                  child: Icon(
                                    Icons.badge_outlined,
                                    size: 36,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              radius: 16,
                              child: Icon(
                                Icons.edit,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _buildOptionButton(
                  icon: Icons.edit,
                  title: l10n.changeTitleOption,
                  trailingText: titleName,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ItemSelectionScreen(
                          itemType: 'title',
                          title: l10n.chooseTitleScreenTitle,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                _buildOptionButton(
                  icon: Icons.my_location,
                  title: l10n.weaponLoadoutOption,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WeaponsListScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                const SizedBox(height: 20),

                Center(
                  child: _buildStaticSprayWheel(loadout, allSprays, allFlexes),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String title,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailingText != null)
              Text(
                trailingText,
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticSprayWheel(
    Map<String, dynamic> loadout,
    List<dynamic> allSprays,
    List<dynamic> allFlexes,
  ) {
    const double size = 320.0;
    const double innerRadius = 78.0;

    final slotConfigs = <Map<String, dynamic>>[
      {
        'name': 'Top',
        'id': '0814b2fe-4512-60a4-5288-1fbdcec6ca48',
        'angle': -math.pi / 2,
        'index': 0,
      },
      {
        'name': 'Right',
        'id': '04af080a-4071-487b-61c0-5b9c0cfaac74',
        'angle': 0.0,
        'index': 1,
      },
      {
        'name': 'Bottom',
        'id': '5863985e-43ac-b05d-cb2d-139e72970014',
        'angle': math.pi / 2,
        'index': 2,
      },
      {
        'name': 'Left',
        'id': 'ec989a55-442a-5a9e-c852-510067ffbb3b',
        'angle': math.pi,
        'index': 3,
      },
    ];

    final wheelTheme = Theme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(size, size),
            painter: _SprayWheelPainter(
              baseColor: wheelTheme.scaffoldBackgroundColor,
              sectorColor: wheelTheme.cardColor,
              lineColor: wheelTheme.dividerColor,
              innerRadius: innerRadius,
            ),
          ),

          for (final config in slotConfigs)
            _buildSpraySlotItem(
              loadout: loadout,
              allSprays: allSprays,
              allFlexes: allFlexes,
              slotName: config['name'] as String,
              slotId: config['id'] as String,
              angle: config['angle'] as double,
              slotIndex: config['index'] as int,
            ),
        ],
      ),
    );
  }

  Widget _buildSpraySlotItem({
    required Map<String, dynamic> loadout,
    required List<dynamic> allSprays,
    required List<dynamic> allFlexes,
    required String slotName,
    required String slotId,
    required double angle,
    int? slotIndex,
  }) {
    String? equippedItemId;
    final List<dynamic> expressions = loadout['Expressions'] ?? [];
    final List<dynamic> sprays = loadout['Sprays'] ?? [];
    final List<dynamic> activeExpressions = loadout['ActiveExpressions'] ?? [];

    if (slotId.isNotEmpty) {
      final expr = expressions.firstWhere(
        (e) => e['EquipSlotID'] == slotId,
        orElse: () => null,
      );
      if (expr != null && expr['Action'] != null) {
        equippedItemId = expr['Action']['ID'] ?? expr['Action']['ItemID'];
      }

      if (equippedItemId == null) {
        final spray = sprays.firstWhere(
          (s) => s['EquipSlotID'] == slotId,
          orElse: () => null,
        );
        if (spray != null) {
          equippedItemId = spray['SprayID'];
        }
      }
    }

    if (equippedItemId == null && activeExpressions.isNotEmpty) {
      if (slotIndex != null && slotIndex < activeExpressions.length) {
        final activeExpr = activeExpressions[slotIndex];
        if (activeExpr is Map) {
          equippedItemId = activeExpr['AssetID'] ?? activeExpr['ID'];
        }
      }
    }

    String displayIconUrl = '';
    if (equippedItemId != null) {
      final sprayObj = allSprays.firstWhere(
        (s) =>
            (s['uuid'] as String).toLowerCase() ==
            equippedItemId!.toLowerCase(),
        orElse: () => null,
      );
      if (sprayObj != null) {
        displayIconUrl =
            sprayObj['fullTransparentIcon'] ?? sprayObj['displayIcon'] ?? '';
      } else {
        final flexObj = allFlexes.firstWhere(
          (f) =>
              (f['uuid'] as String).toLowerCase() ==
              equippedItemId!.toLowerCase(),
          orElse: () => null,
        );
        if (flexObj != null) {
          displayIconUrl = flexObj['displayIcon'] ?? '';
        } else {
          displayIconUrl =
              'https://media.valorant-api.com/sprays/$equippedItemId/displayicon.png';
        }
      }
    }

    final isClickable = slotId.isNotEmpty;

    final sprayIcon = isClickable
        ? (displayIconUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: displayIconUrl,
                  cacheManager: CustomCacheManagers.loadoutPresetCacheManager,
                  fit: BoxFit.contain,
                  placeholder: (context, url) =>
                      const CircularProgressIndicator(strokeWidth: 2),
                  errorWidget: (context, url, error) => Icon(
                    Icons.broken_image,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                )
              : Icon(
                  Icons.add,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ))
        : Icon(
            Icons.lock,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 20,
          );

    const wheelSize = 320.0;
    const iconRadius = 103.0;
    const iconSize = 76.0;
    final center = wheelSize / 2;
    final iconLeft = center + iconRadius * math.cos(angle) - iconSize / 2;
    final iconTop = center + iconRadius * math.sin(angle) - iconSize / 2;

    return SizedBox(
      width: wheelSize,
      height: wheelSize,
      child: Stack(
        children: [
          ClipPath(
            clipper: _WheelSectorClipper(angle),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isClickable
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ItemSelectionScreen(
                            itemType: 'spray',
                            title: 'Choose $slotName Spray',
                            slotId: slotId,
                          ),
                        ),
                      );
                    }
                  : null,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: iconLeft,
            top: iconTop,
            width: iconSize,
            height: iconSize,
            child: IgnorePointer(child: sprayIcon),
          ),
        ],
      ),
    );
  }
}

class _SprayWheelPainter extends CustomPainter {
  const _SprayWheelPainter({
    required this.baseColor,
    required this.sectorColor,
    required this.lineColor,
    required this.innerRadius,
  });

  final Color baseColor;
  final Color sectorColor;
  final Color lineColor;
  final double innerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 3;
    final outer = Paint()..color = baseColor;
    canvas.drawCircle(center, radius, outer);

    final sector = Paint()..color = sectorColor.withValues(alpha: 0.7);
    final sectorRect = Rect.fromCircle(center: center, radius: radius - 5);
    for (var i = 0; i < 4; i++) {
      canvas.drawArc(
        sectorRect,
        -math.pi / 4 + i * math.pi / 2,
        math.pi / 2,
        true,
        sector,
      );
    }

    final outline = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, outline);

    final dividerUnderlay = Paint()
      ..color = baseColor
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.square;
    final divider = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;
    for (final angle in const [math.pi / 4, -math.pi / 4]) {
      final vector = Offset(math.cos(angle), math.sin(angle));
      final start = center - vector * radius;
      final end = center + vector * radius;
      canvas.drawLine(start, end, dividerUnderlay);
      canvas.drawLine(start, end, divider);
    }

    final inner = Paint()..color = baseColor;
    canvas.drawCircle(center, innerRadius, inner);
    final innerOutline = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, innerRadius, innerOutline);
  }

  @override
  bool shouldRepaint(covariant _SprayWheelPainter oldDelegate) {
    return oldDelegate.baseColor != baseColor ||
        oldDelegate.sectorColor != sectorColor ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.innerRadius != innerRadius;
  }
}

class _WheelSectorClipper extends CustomClipper<Path> {
  const _WheelSectorClipper(this.angle);

  final double angle;

  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.8;
    return Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(
        center.dx + radius * math.cos(angle - math.pi / 4),
        center.dy + radius * math.sin(angle - math.pi / 4),
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        angle - math.pi / 4,
        math.pi / 2,
        false,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant _WheelSectorClipper oldClipper) {
    return oldClipper.angle != angle;
  }
}
