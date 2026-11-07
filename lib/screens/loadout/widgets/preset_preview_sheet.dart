import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/models/loadout_preset.dart';
import 'package:valorant_thunai/providers/preset_provider.dart';
import 'package:valorant_thunai/providers/weapons_provider.dart';
import 'package:valorant_thunai/providers/skin_provider.dart';
import 'package:valorant_thunai/utils/weapon_asset_resolver.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';
import 'package:valorant_thunai/screens/loadout/widgets/preset_spray_wheel.dart';

class PresetPreviewSheet extends ConsumerStatefulWidget {
  final LoadoutPreset preset;
  final bool isNewRandomized;
  final bool readOnly;

  final bool isImportPreview;

  const PresetPreviewSheet({
    super.key,
    required this.preset,
    this.isNewRandomized = false,
    this.readOnly = false,
    this.isImportPreview = false,
  });

  @override
  ConsumerState<PresetPreviewSheet> createState() => _PresetPreviewSheetState();
}

class _PresetPreviewSheetState extends ConsumerState<PresetPreviewSheet> {
  bool _isSaving = false;
  bool _isApplying = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.preset.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  LoadoutPreset _buildFinalPreset() {
    return LoadoutPreset(
      id: widget.preset.id,
      name: _nameController.text.trim().isEmpty
          ? widget.preset.name
          : _nameController.text.trim(),
      createdAt: widget.preset.createdAt,
      guns: widget.preset.guns,
      identity: widget.preset.identity,
      sprays: widget.preset.sprays,
      expressions: widget.preset.expressions,
    );
  }

  Future<void> _saveToLocal() async {
    setState(() => _isSaving = true);
    try {
      final finalPreset = _buildFinalPreset();
      await ref.read(presetsProvider.notifier).savePreset(finalPreset);

      if (!mounted) return;
      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "${finalPreset.name}" to Presets!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _applyToGame() async {
    setState(() => _isApplying = true);
    try {
      final finalPreset = _buildFinalPreset();

      await ref.read(presetsProvider.notifier).savePreset(finalPreset);

      await ref.read(presetsProvider.notifier).applyPresetToGame(finalPreset);

      if (!mounted) return;
      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Applied "${finalPreset.name}" to Valorant successfully!',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isApplying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final weaponsAsync = ref.watch(weaponsProvider);
    final skinsAsync = ref.watch(skinsMetadataProvider);
    final buddiesAsync = ref.watch(buddiesProvider);
    final cardsMap = ref.watch(playerCardsProvider).value ?? {};
    final titlesMap = ref.watch(titlesProvider).value ?? {};
    final spraysMap = <String, dynamic>{
      ...ref.watch(spraysProvider).value ?? {},
      for (final flex in ref.watch(allFlexesProvider).value ?? const [])
        if (flex is Map && flex['uuid'] != null) flex['uuid'] as String: flex,
    };

    final identity = widget.preset.identity;
    final cardId = identity?['PlayerCardID'] as String?;
    final titleId = identity?['PlayerTitleID'] as String?;
    final cardName = cardId != null
        ? (cardsMap[cardId]?['displayName'] as String?)
        : null;
    final titleName = titleId != null
        ? ((titlesMap[titleId]?['displayName'] ??
                  titlesMap[titleId]?['titleText'])
              as String?)
        : null;
    final cardIcon = cardId != null
        ? ((cardsMap[cardId]?['smallArt'] ?? cardsMap[cardId]?['displayIcon'])
              as String?)
        : null;
    final sprayEntries = (widget.preset.sprays ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final slotSprayIds = <String, String?>{
      for (final entry in sprayEntries)
        if (entry['EquipSlotID'] != null)
          entry['EquipSlotID'] as String: entry['SprayID'] as String?,
    };

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.isImportPreview
                                    ? l10n.importPresetPreviewTitle
                                    : widget.isNewRandomized
                                    ? 'Randomized Loadout Preview'
                                    : (widget.readOnly
                                          ? 'Inspect Preset'
                                          : 'Preset Preview'),
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.isImportPreview
                                    ? l10n.importPresetPreviewSubtitle
                                    : widget.readOnly
                                    ? 'Viewing this preset\'s full loadout — weapons, card, title & sprays'
                                    : 'Review the full loadout before syncing to Valorant server',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (!widget.readOnly && !widget.isImportPreview) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Preset Name',
                          prefixIcon: const Icon(Icons.label_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: theme.colorScheme.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.preset.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    child: Text(
                      'CARD & TITLE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildExtraChip(
                          theme,
                          icon: Icons.badge_outlined,
                          label: cardId != null
                              ? (cardName ?? 'Player Card')
                              : null,
                          imageUrl: cardIcon,
                        ),
                        _buildExtraChip(
                          theme,
                          icon: Icons.title,
                          label: titleId != null
                              ? (titleName ?? 'Player Title')
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    child: Text(
                      'SPRAYS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Center(
                    child: PresetSprayWheel(
                      slotSprayIds: slotSprayIds,
                      spraysMap: spraysMap,
                      onTapSlot: (_, _) {},
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),

                  weaponsAsync.when(
                    loading: () => const SizedBox(
                      height: 200,
                      child: Center(child: FunnyLoadingView()),
                    ),
                    error: (e, _) => SizedBox(
                      height: 200,
                      child: Center(child: Text('Error: $e')),
                    ),
                    data: (weapons) {
                      return skinsAsync.when(
                        loading: () => const SizedBox(
                          height: 200,
                          child: Center(child: FunnyLoadingView()),
                        ),
                        error: (e, _) => SizedBox(
                          height: 200,
                          child: Center(child: Text('Error: $e')),
                        ),
                        data: (skinsMap) {
                          return buddiesAsync.when(
                            loading: () => const SizedBox(
                              height: 200,
                              child: Center(child: FunnyLoadingView()),
                            ),
                            error: (e, _) => SizedBox(
                              height: 200,
                              child: Center(child: Text('Error: $e')),
                            ),
                            data: (buddies) {
                              final guns = widget.preset.guns;

                              return GridView.builder(
                                padding: const EdgeInsets.all(16),
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 1.55,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                    ),
                                itemCount: guns.length,
                                itemBuilder: (context, index) {
                                  final gun = guns[index];
                                  final weaponData = weapons.firstWhere(
                                    (w) =>
                                        (w['uuid'] as String).toLowerCase() ==
                                        gun.id.toLowerCase(),
                                    orElse: () => null,
                                  );
                                  final weaponName =
                                      weaponData?['displayName'] ?? 'Weapon';

                                  final meta =
                                      skinsMap[gun.skinId] ??
                                      skinsMap[gun.skinLevelId];
                                  final skinName = meta?.displayName ?? 'Skin';

                                  final iconUrl =
                                      WeaponAssetResolver.resolveSkinImageUrl(
                                        weapon: weaponData,
                                        skinId: gun.skinId,
                                        skinLevelId: gun.skinLevelId,
                                        chromaId: gun.chromaId,
                                        skinsMap: skinsMap,
                                      );

                                  final buddyImage =
                                      WeaponAssetResolver.resolveBuddyImageUrl(
                                        charmId: gun.charmId,
                                        buddiesMap: buddies,
                                      );

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: theme.colorScheme.outlineVariant
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          weaponName,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                        Expanded(
                                          child: Center(
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                iconUrl.isNotEmpty
                                                    ? CachedNetworkImage(
                                                        imageUrl: iconUrl,
                                                        fit: BoxFit.contain,
                                                        placeholder: (
                                                          context,
                                                          url,
                                                        ) => const SizedBox(),
                                                        errorWidget:
                                                            (
                                                              context,
                                                              url,
                                                              error,
                                                            ) => const Icon(
                                                              Icons
                                                                  .broken_image,
                                                              size: 20,
                                                            ),
                                                      )
                                                    : const Icon(
                                                        Icons.shield_outlined,
                                                      ),
                                                if (buddyImage != null)
                                                  Positioned(
                                                    right: -6,
                                                    bottom: -6,
                                                    child: Container(
                                                      width: 20,
                                                      height: 20,
                                                      decoration: BoxDecoration(
                                                        color: theme
                                                            .colorScheme
                                                            .surfaceContainer,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: theme
                                                              .colorScheme
                                                              .surface,
                                                          width: 1.5,
                                                        ),
                                                      ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                            2,
                                                          ),
                                                      child: CachedNetworkImage(
                                                        imageUrl: buddyImage,
                                                        fit: BoxFit.contain,
                                                        errorWidget: (
                                                          context,
                                                          url,
                                                          error,
                                                        ) => const SizedBox(),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Text(
                                          skinName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: widget.isImportPreview
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close, size: 18),
                          label: Text(
                            l10n.importPresetCancel,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                          ),
                          label: Text(
                            l10n.importPresetConfirm,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : widget.readOnly
                ? SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(
                        'Close Preview',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _isSaving || _isApplying
                              ? null
                              : _saveToLocal,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.bookmark_add_outlined,
                                  size: 18,
                                ),
                          label: Text(
                            _isSaving ? 'Saving...' : 'Save to Presets',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _isSaving || _isApplying
                              ? null
                              : _applyToGame,
                          icon: _isApplying
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 18,
                                ),
                          label: Text(
                            _isApplying ? 'Syncing...' : 'Apply to Game',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraChip(
    ThemeData theme, {
    required IconData icon,
    required String? label,
    String? imageUrl,
  }) {
    final isSet = label != null;
    final color = isSet
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6);

    return DottedBorderIfUnset(
      unset: !isSet,
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSet
              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSet
              ? Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.4,
                  ),
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSet && imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 18,
                  height: 18,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) =>
                      Icon(icon, size: 14, color: theme.colorScheme.primary),
                ),
              )
            else
              Icon(
                icon,
                size: 14,
                color: isSet ? theme.colorScheme.primary : color,
              ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                label ?? 'Not set',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  fontStyle: isSet ? FontStyle.normal : FontStyle.italic,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DottedBorderIfUnset extends StatelessWidget {
  final bool unset;
  final Color color;
  final Widget child;

  const DottedBorderIfUnset({
    super.key,
    required this.unset,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!unset) return child;
    return CustomPaint(
      painter: _DashedRRectPainter(color: color, radius: 20),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedRRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
