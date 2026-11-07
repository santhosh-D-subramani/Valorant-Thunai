import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/models/loadout_preset.dart';
import 'package:valorant_thunai/providers/weapons_provider.dart';
import 'package:valorant_thunai/providers/preset_provider.dart';
import 'package:valorant_thunai/providers/skin_provider.dart';
import 'package:valorant_thunai/utils/weapon_asset_resolver.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:valorant_thunai/providers/auto_loadout_provider.dart';
import 'package:valorant_thunai/screens/loadout/widgets/preset_preview_sheet.dart';
import 'package:valorant_thunai/screens/loadout/preset_editor_screen.dart';
import 'package:valorant_thunai/screens/loadout/preset_collection_screen.dart';
import 'package:valorant_thunai/utils/preset_sharing.dart';
import 'package:share_plus/share_plus.dart';

class LoadoutPresetsScreen extends ConsumerStatefulWidget {
  const LoadoutPresetsScreen({super.key});

  @override
  ConsumerState<LoadoutPresetsScreen> createState() =>
      _LoadoutPresetsScreenState();
}

class _LoadoutPresetsScreenState extends ConsumerState<LoadoutPresetsScreen> {
  static const String vandalId = '9c82e19d-4575-0200-1a81-3eacf00cf872';
  static const String phantomId = 'ee8e8d15-496b-07ac-e5f6-8fae5d4c7b1a';
  static const String operatorId = 'a03b24d3-4319-996d-0f8c-94bbfba1dfc7';
  static const String meleeId = '2f59173c-4bed-b6c3-2191-dea9b58be9c7';

  void _showPresetPreview(LoadoutPreset preset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PresetPreviewSheet(preset: preset),
    );
  }

  void _showPresetCollection(LoadoutPreset preset) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PresetCollectionScreen(preset: preset)),
    );
  }

  Future<void> _handleRenamePreset(LoadoutPreset preset) async {
    final controller = TextEditingController(text: preset.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Preset'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Preset Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != preset.name) {
      try {
        final updated = LoadoutPreset(
          id: preset.id,
          name: newName,
          createdAt: preset.createdAt,
          guns: preset.guns,
          identity: preset.identity,
          sprays: preset.sprays,
          expressions: preset.expressions,
        );
        await ref.read(presetsProvider.notifier).savePreset(updated);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleSharePreset(LoadoutPreset preset) async {
    final code = PresetSharing.encode(preset);
    await SharePlus.instance.share(
      ShareParams(
        text: code,
        subject: 'ValShop loadout preset: ${preset.name}',
      ),
    );
  }

  Future<void> _handleImportPreset(BuildContext context) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Preset'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Paste a preset code someone shared with you.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Preset code',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (code == null || code.isEmpty || !context.mounted) return;

    final decoded = PresetSharing.decode(code);
    if (decoded == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That doesn\'t look like a valid preset code.'),
        ),
      );
      return;
    }

    final existing = ref.read(presetsProvider).value ?? [];
    final uniqueName = PresetSharing.uniqueImportName(decoded.name, existing);
    final toSave = uniqueName == decoded.name
        ? decoded
        : LoadoutPreset(
            id: decoded.id,
            name: uniqueName,
            createdAt: decoded.createdAt,
            guns: decoded.guns,
            identity: decoded.identity,
            sprays: decoded.sprays,
            expressions: decoded.expressions,
          );

    if (!context.mounted) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PresetPreviewSheet(preset: toSave, isImportPreview: true),
    );

    if (confirmed != true) return;

    try {
      await ref.read(presetsProvider.notifier).savePreset(toSave);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Imported "${toSave.name}"')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleDeletePreset(LoadoutPreset preset) async {
    final autoState = ref.read(autoLoadoutProvider).value;
    final dependentRules =
        autoState?.rules
            .where(
              (r) => r.presetId == preset.id || r.presetName == preset.name,
            )
            .toList() ??
        [];

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Preset?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${preset.name}"?'),
            if (dependentRules.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This preset is mapped to ${dependentRules.length} Auto Loadout (Beta) rule(s) (${dependentRules.map((r) => r.targetName).join(', ')}). Those rules will remain configured but will require remapping.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await ref.read(presetsProvider.notifier).deletePreset(preset.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presetsAsync = ref.watch(presetsProvider);
    final skinsAsync = ref.watch(skinsMetadataProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Loadout Presets',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Import preset code',
            onPressed: () => _handleImportPreset(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Card(
                elevation: 0,
                color: theme.colorScheme.tertiaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PresetEditorScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 26,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create Preset',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onTertiaryContainer,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Builder, Active & Random',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onTertiaryContainer
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: theme.colorScheme.onTertiaryContainer
                              .withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Text(
                'SAVED PRESETS',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),

          presetsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: FunnyLoadingView()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Error loading presets: $e')),
            ),
            data: (presets) {
              if (presets.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.dashboard_customize_outlined,
                          size: 64,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No presets created yet',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Save your current loadout or randomize a fresh set from your owned inventory.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final preset = presets[index];
                    return _buildPresetCard(
                      theme: theme,
                      preset: preset,
                      skinsAsync: skinsAsync,
                    );
                  }, childCount: presets.length),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPresetCard({
    required ThemeData theme,
    required LoadoutPreset preset,
    required AsyncValue<Map<String, SkinMetadata>> skinsAsync,
  }) {
    final skinsMap = skinsAsync.value ?? {};

    String? getSkinIcon(String weaponId) {
      final match = preset.guns.firstWhere(
        (g) => g.id.toLowerCase() == weaponId.toLowerCase(),
        orElse: () =>
            GunPresetItem(id: '', skinId: '', skinLevelId: '', chromaId: ''),
      );
      if (match.id.isEmpty) return null;

      final weapons = ref.watch(weaponsProvider).value ?? [];
      final weaponMatch = weapons.cast<Map<String, dynamic>?>().firstWhere(
        (w) =>
            w != null &&
            (w['uuid'] as String).toLowerCase() == weaponId.toLowerCase(),
        orElse: () => null,
      );

      return WeaponAssetResolver.resolveSkinImageUrl(
        weapon: weaponMatch,
        skinId: match.skinId,
        skinLevelId: match.skinLevelId,
        chromaId: match.chromaId,
        skinsMap: skinsMap,
      );
    }

    final vandalIcon = getSkinIcon(vandalId);
    final phantomIcon = getSkinIcon(phantomId);
    final operatorIcon = getSkinIcon(operatorId);
    final meleeIcon = getSkinIcon(meleeId);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showPresetCollection(preset),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      preset.name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    onSelected: (action) {
                      if (action == 'collection') {
                        _showPresetCollection(preset);
                      } else if (action == 'preview') {
                        _showPresetPreview(preset);
                      } else if (action == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PresetEditorScreen(initialPreset: preset),
                          ),
                        );
                      } else if (action == 'rename') {
                        _handleRenamePreset(preset);
                      } else if (action == 'share') {
                        _handleSharePreset(preset);
                      } else if (action == 'delete') {
                        _handleDeletePreset(preset);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'collection',
                        child: Row(
                          children: [
                            Icon(Icons.grid_view_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('View Collection'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'preview',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Preview & Sync'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Share Preset'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.tune, size: 18),
                            SizedBox(width: 8),
                            Text('Edit Loadout'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Rename'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  _buildWeaponThumb(theme, 'Vandal', vandalIcon),
                  const SizedBox(width: 8),
                  _buildWeaponThumb(theme, 'Phantom', phantomIcon),
                  const SizedBox(width: 8),
                  _buildWeaponThumb(theme, 'Operator', operatorIcon),
                  const SizedBox(width: 8),
                  _buildWeaponThumb(theme, 'Melee', meleeIcon),
                ],
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _showPresetPreview(preset),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Apply Preset (Sync)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeaponThumb(ThemeData theme, String label, String? iconUrl) {
    return Expanded(
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: iconUrl != null && iconUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: iconUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const SizedBox(),
                errorWidget: (context, url, error) => Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
      ),
    );
  }
}
