import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/models/loadout_preset.dart';
import 'package:valorant_thunai/providers/display_settings_provider.dart';
import 'package:valorant_thunai/providers/weapons_provider.dart';
import 'package:valorant_thunai/providers/skin_provider.dart';
import 'package:valorant_thunai/providers/preset_provider.dart';
import 'package:valorant_thunai/utils/format_utils.dart';
import 'package:valorant_thunai/utils/weapon_asset_resolver.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';

class PresetCollectionScreen extends ConsumerStatefulWidget {
  final LoadoutPreset preset;

  const PresetCollectionScreen({super.key, required this.preset});

  @override
  ConsumerState<PresetCollectionScreen> createState() =>
      _PresetCollectionScreenState();
}

class _PresetCollectionScreenState
    extends ConsumerState<PresetCollectionScreen> {
  final Set<String> _collapsedSections = {};
  bool _isApplying = false;

  DisplaySettings get _displaySettings => ref.read(displaySettingsProvider);

  void _toggleSection(String key) {
    setState(() {
      if (_collapsedSections.contains(key)) {
        _collapsedSections.remove(key);
      } else {
        _collapsedSections.add(key);
      }
    });
  }

  Future<void> _applyToGame() async {
    setState(() => _isApplying = true);
    try {
      await ref.read(presetsProvider.notifier).applyPresetToGame(widget.preset);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Applied "${widget.preset.name}" to Valorant successfully!',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.watch(displaySettingsProvider);
    final weaponsAsync = ref.watch(weaponsProvider);
    final skinsAsync = ref.watch(skinsMetadataProvider);
    final buddiesAsync = ref.watch(buddiesProvider);
    final cardsAsync = ref.watch(playerCardsProvider);
    final titlesAsync = ref.watch(titlesProvider);
    final spraysAsync = ref.watch(spraysProvider);
    final flexesAsync = ref.watch(allFlexesProvider);

    final allLoaded =
        weaponsAsync.hasValue &&
        skinsAsync.hasValue &&
        buddiesAsync.hasValue &&
        cardsAsync.hasValue &&
        titlesAsync.hasValue &&
        spraysAsync.hasValue &&
        flexesAsync.hasValue;

    final anyError =
        weaponsAsync.hasError ||
        skinsAsync.hasError ||
        buddiesAsync.hasError ||
        cardsAsync.hasError ||
        titlesAsync.hasError ||
        spraysAsync.hasError ||
        flexesAsync.hasError;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.preset.name,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: !allLoaded
          ? Center(
              child: anyError
                  ? Text(
                      'Failed to load item metadata',
                      style: TextStyle(color: theme.colorScheme.error),
                    )
                  : const FunnyLoadingView(),
            )
          : _buildBody(
              theme,
              weapons: weaponsAsync.value!.cast<Map<String, dynamic>>(),
              skinsMap: skinsAsync.value!,
              buddiesMap: buddiesAsync.value!,
              cardsMap: cardsAsync.value!,
              titlesMap: titlesAsync.value!,
              spraysMap: {
                ...spraysAsync.value!,
                for (final flex in flexesAsync.value!)
                  if (flex is Map && flex['uuid'] != null)
                    flex['uuid'] as String: flex,
              },
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _isApplying ? null : _applyToGame,
            icon: _isApplying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_upload_outlined, size: 18),
            label: Text(
              _isApplying ? 'Syncing...' : 'Apply to Game',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    ThemeData theme, {
    required List<Map<String, dynamic>> weapons,
    required Map<String, SkinMetadata> skinsMap,
    required Map<String, dynamic> buddiesMap,
    required Map<String, dynamic> cardsMap,
    required Map<String, dynamic> titlesMap,
    required Map<String, dynamic> spraysMap,
  }) {
    final guns = widget.preset.guns;
    final cardId = widget.preset.identity?['PlayerCardID'] as String?;
    final titleId = widget.preset.identity?['PlayerTitleID'] as String?;
    final card = (cardId != null && cardId.isNotEmpty)
        ? cardsMap[cardId]
        : null;
    final title = (titleId != null && titleId.isNotEmpty)
        ? titlesMap[titleId]
        : null;

    final equippedSprays = (widget.preset.sprays ?? [])
        .cast<Map<dynamic, dynamic>>()
        .map((s) => s['SprayID'] as String?)
        .where((id) => id != null && id.isNotEmpty && spraysMap.containsKey(id))
        .toSet()
        .toList();

    final totalItems =
        guns.length +
        (card != null ? 1 : 0) +
        (title != null ? 1 : 0) +
        equippedSprays.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Created ${FormatUtils.formatDate(widget.preset.createdAt, _displaySettings)}',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$totalItems items configured',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (guns.isNotEmpty)
          _buildSection(
            theme,
            key: 'weapons',
            title: 'Weapon Skins',
            count: guns.length,
            children: guns
                .map(
                  (gun) => _buildWeaponRow(
                    theme,
                    gun,
                    weapons,
                    skinsMap,
                    buddiesMap,
                  ),
                )
                .toList(),
          ),

        if (card != null)
          _buildSection(
            theme,
            key: 'card',
            title: 'Player Card',
            count: 1,
            children: [
              _buildItemRow(
                theme,
                imageUrl: card['wideArt'] ?? card['displayIcon'] ?? '',
                name: card['displayName'] ?? 'Player Card',
              ),
            ],
          ),

        if (equippedSprays.isNotEmpty)
          _buildSection(
            theme,
            key: 'sprays',
            title: 'Sprays',
            count: equippedSprays.length,
            children: equippedSprays.map((id) {
              final spray = spraysMap[id];
              return _buildItemRow(
                theme,
                imageUrl: spray['displayIcon'] ?? spray['fullIcon'] ?? '',
                name: spray['displayName'] ?? 'Spray',
              );
            }).toList(),
          ),

        if (title != null)
          _buildSection(
            theme,
            key: 'title',
            title: 'Player Titles',
            count: 1,
            children: [
              _buildItemRow(
                theme,
                imageUrl: '',
                name: title['displayName'] ?? title['titleText'] ?? 'Title',
                textOnly: true,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSection(
    ThemeData theme, {
    required String key,
    required String title,
    required int count,
    required List<Widget> children,
  }) {
    final collapsed = _collapsedSections.contains(key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _toggleSection(key),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    collapsed
                        ? Icons.keyboard_arrow_right
                        : Icons.keyboard_arrow_down,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (!collapsed)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < children.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    children[i],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeaponRow(
    ThemeData theme,
    GunPresetItem gun,
    List<Map<String, dynamic>> weapons,
    Map<String, SkinMetadata> skinsMap,
    Map<String, dynamic> buddiesMap,
  ) {
    final weaponData = weapons.cast<Map<String, dynamic>?>().firstWhere(
      (w) => (w?['uuid'] as String?)?.toLowerCase() == gun.id.toLowerCase(),
      orElse: () => null,
    );
    final weaponName = weaponData?['displayName'] ?? 'Weapon';
    final meta = skinsMap[gun.skinId] ?? skinsMap[gun.skinLevelId];
    final skinName = meta?.displayName ?? 'Skin';

    final iconUrl = WeaponAssetResolver.resolveSkinImageUrl(
      weapon: weaponData,
      skinId: gun.skinId,
      skinLevelId: gun.skinLevelId,
      chromaId: gun.chromaId,
      skinsMap: skinsMap,
    );

    final chromas = meta?.chromas ?? const <SkinChroma>[];

    final buddyImageUrl = WeaponAssetResolver.resolveBuddyImageUrl(
      charmId: gun.charmId,
      buddiesMap: buddiesMap,
    );
    final buddyName = WeaponAssetResolver.resolveBuddyName(
      charmId: gun.charmId,
      buddiesMap: buddiesMap,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 64,
                  width: double.infinity,
                  child: iconUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: iconUrl,
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                          placeholder: (context, url) => const SizedBox(),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.shield_outlined, size: 32),
                        )
                      : const Align(
                          alignment: Alignment.centerLeft,
                          child: Icon(Icons.shield_outlined, size: 32),
                        ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '$weaponName $skinName',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (chromas.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: chromas.map((chroma) {
                          final isSelected = chroma.uuid == gun.chromaId;
                          final swatchUrl = chroma.swatch ?? chroma.displayIcon;
                          return Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                              border: isSelected
                                  ? Border.all(color: Colors.amber, width: 2)
                                  : null,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (swatchUrl.isNotEmpty)
                                  CachedNetworkImage(
                                    imageUrl: swatchUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        const SizedBox(),
                                    errorWidget: (context, url, error) =>
                                        const SizedBox(),
                                  ),
                                if (isSelected)
                                  const Positioned(
                                    bottom: -1,
                                    right: -1,
                                    child: Icon(
                                      Icons.star,
                                      size: 10,
                                      color: Colors.amber,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
                if (buddyName != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (buddyImageUrl != null && buddyImageUrl.isNotEmpty)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CachedNetworkImage(
                            imageUrl: buddyImageUrl,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const SizedBox(),
                            errorWidget: (context, url, error) =>
                                const SizedBox(),
                          ),
                        )
                      else
                        Icon(
                          Icons.attractions,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      const SizedBox(width: 6),
                      Text(
                        buddyName,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(
    ThemeData theme, {
    required String imageUrl,
    required String name,
    bool textOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          if (!textOnly) ...[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const SizedBox(),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.image_not_supported_outlined,
                        size: 20,
                      ),
                    )
                  : const Icon(Icons.image_not_supported_outlined, size: 20),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
