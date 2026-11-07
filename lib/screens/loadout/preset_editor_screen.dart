import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/models/loadout_preset.dart';
import 'package:valorant_thunai/providers/preset_provider.dart';
import 'package:valorant_thunai/providers/skin_provider.dart';
import 'package:valorant_thunai/providers/weapons_provider.dart';
import 'package:valorant_thunai/providers/loadout_provider.dart';
import 'package:valorant_thunai/utils/cache_managers.dart';
import 'package:valorant_thunai/utils/weapon_asset_resolver.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';

import 'widgets/weapon_config_sheet.dart';
import 'widgets/preset_spray_wheel.dart';
import 'item_selection_screen.dart';

class PresetEditorScreen extends ConsumerStatefulWidget {
  final LoadoutPreset? initialPreset;

  const PresetEditorScreen({super.key, this.initialPreset});

  @override
  ConsumerState<PresetEditorScreen> createState() => _PresetEditorScreenState();
}

class _PresetEditorScreenState extends ConsumerState<PresetEditorScreen> {
  late TextEditingController _nameController;
  final Map<String, GunPresetItem> _gunMap = {};
  bool _isSaving = false;
  bool _isRandomizing = false;
  bool _isLoadingActive = false;
  bool _hasManualChanges = false;

  String? _cardId;
  String? _titleId;
  final Map<String, String?> _spraySlotIds = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialPreset?.name ?? '',
    );

    if (widget.initialPreset != null) {
      for (var gun in widget.initialPreset!.guns) {
        _gunMap[gun.id.toLowerCase()] = gun;
      }
      _cardId = widget.initialPreset!.identity?['PlayerCardID'] as String?;
      _titleId = widget.initialPreset!.identity?['PlayerTitleID'] as String?;
      for (final entry in widget.initialPreset!.sprays ?? const []) {
        final slotId = (entry as Map)['EquipSlotID'] as String?;
        final sprayId = entry['SprayID'] as String?;
        if (slotId != null) _spraySlotIds[slotId] = sprayId;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  static const _sprayWheelSlots = [
    (name: 'Top', id: '0814b2fe-4512-60a4-5288-1fbdcec6ca48', index: 0),
    (name: 'Right', id: '04af080a-4071-487b-61c0-5b9c0cfaac74', index: 1),
    (name: 'Bottom', id: '5863985e-43ac-b05d-cb2d-139e72970014', index: 2),
    (name: 'Left', id: 'ec989a55-442a-5a9e-c852-510067ffbb3b', index: 3),
  ];

  String? _resolveEquippedSprayId(
    Map<String, dynamic> loadout,
    String slotId,
    int slotIndex,
  ) {
    final expressions = (loadout['Expressions'] as List?) ?? [];
    final sprays = (loadout['Sprays'] as List?) ?? [];
    final activeExpressions = (loadout['ActiveExpressions'] as List?) ?? [];

    final expr = expressions.cast<Map?>().firstWhere(
      (e) => e?['EquipSlotID'] == slotId,
      orElse: () => null,
    );
    if (expr != null && expr['Action'] != null) {
      return (expr['Action']['ID'] ?? expr['Action']['ItemID']) as String?;
    }

    final spray = sprays.cast<Map?>().firstWhere(
      (s) => s?['EquipSlotID'] == slotId,
      orElse: () => null,
    );
    if (spray != null) return spray['SprayID'] as String?;

    if (slotIndex < activeExpressions.length) {
      final activeExpr = activeExpressions[slotIndex];
      if (activeExpr is Map) {
        return (activeExpr['AssetID'] ?? activeExpr['ID']) as String?;
      }
    }
    return null;
  }

  void _populateFromCurrentLoadout(Map<String, dynamic> currentLoadout) {
    final gunsList = (currentLoadout['Guns'] as List<dynamic>?) ?? [];
    final identity = currentLoadout['Identity'] as Map?;
    setState(() {
      _gunMap.clear();
      for (var item in gunsList) {
        final gun = GunPresetItem.fromJson(Map<String, dynamic>.from(item));
        _gunMap[gun.id.toLowerCase()] = gun;
      }
      _cardId = identity?['PlayerCardID'] as String?;
      _titleId = identity?['PlayerTitleID'] as String?;
      _spraySlotIds.clear();
      for (final slot in _sprayWheelSlots) {
        final sprayId = _resolveEquippedSprayId(
          currentLoadout,
          slot.id,
          slot.index,
        );
        if (sprayId != null) _spraySlotIds[slot.id] = sprayId;
      }
      _hasManualChanges = false;
    });
  }

  Future<void> _handleLoadActive() async {
    if (_hasManualChanges || _gunMap.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Load Active In-Game Setup?'),
          content: const Text(
            'This will fetch your live in-game weapon loadout from Valorant servers and replace your current editor slots.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Load Active'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isLoadingActive = true);
    try {
      await ref.read(loadoutProvider.notifier).fetchLoadout();
      final freshLoadout = ref.read(loadoutProvider).value;

      if (freshLoadout == null || freshLoadout['Guns'] == null) {
        throw Exception('No active weapon loadout found on Valorant server');
      }

      if (!mounted) return;
      _populateFromCurrentLoadout(freshLoadout);
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = 'Active Loadout';
      }

      setState(() => _isLoadingActive = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Loaded live in-game weapons from Valorant!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingActive = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load active loadout: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<({bool guns, bool card, bool sprays, bool title})?>
  _showRandomizeOptionsDialog() {
    bool guns = true;
    bool card = false;
    bool sprays = false;
    bool title = false;

    return showDialog<({bool guns, bool card, bool sprays, bool title})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final anySelected = guns || card || sprays || title;
          return AlertDialog(
            title: const Text('Randomize Loadout'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: guns,
                  title: const Text('Weapon Skins'),
                  onChanged: (v) => setDialogState(() => guns = v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: card,
                  title: const Text('Player Card'),
                  onChanged: (v) => setDialogState(() => card = v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: sprays,
                  title: const Text('Sprays'),
                  onChanged: (v) => setDialogState(() => sprays = v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: title,
                  title: const Text('Player Title'),
                  onChanged: (v) => setDialogState(() => title = v ?? false),
                ),
                if (!anySelected)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Pick at least one category to randomize.',
                      style: TextStyle(color: Colors.red, fontSize: 12),
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
                onPressed: anySelected
                    ? () => Navigator.pop(ctx, (
                        guns: guns,
                        card: card,
                        sprays: sprays,
                        title: title,
                      ))
                    : null,
                child: const Text('Randomize'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleRandomize() async {
    final options = await _showRandomizeOptionsDialog();
    if (options == null) return;

    setState(() => _isRandomizing = true);
    try {
      final randomized = await ref
          .read(presetsProvider.notifier)
          .generateRandomizedPreset(
            name: _nameController.text.trim().isNotEmpty
                ? _nameController.text.trim()
                : 'Randomized Preset',
            randomizeGuns: options.guns,
            randomizeCard: options.card,
            randomizeSprays: options.sprays,
            randomizeTitle: options.title,
          );

      if (!mounted) return;
      setState(() {
        if (options.guns) {
          _gunMap.clear();
          for (var gun in randomized.guns) {
            _gunMap[gun.id.toLowerCase()] = gun;
          }
        }
        if (options.card) {
          _cardId = randomized.identity?['PlayerCardID'] as String? ?? _cardId;
        }
        if (options.title) {
          _titleId =
              randomized.identity?['PlayerTitleID'] as String? ?? _titleId;
        }
        if (options.sprays) {
          for (final entry in randomized.sprays ?? const []) {
            final slotId = entry['EquipSlotID'] as String?;
            final sprayId = entry['SprayID'] as String?;
            if (slotId != null) _spraySlotIds[slotId] = sprayId;
          }
        }
        if (_nameController.text.trim().isEmpty) {
          _nameController.text = 'Randomized Preset';
        }
        _hasManualChanges = false;
        _isRandomizing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Randomized from owned inventory!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRandomizing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to randomize: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildSafeImage(
    String url,
    ThemeData theme, {
    double width = 60,
    double height = 36,
  }) {
    if (url.isEmpty) {
      return Icon(
        Icons.shield_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: CustomCacheManagers.loadoutPresetCacheManager,
      fit: BoxFit.contain,
      errorWidget: (context, errorUrl, error) {
        CustomCacheManagers.loadoutPresetCacheManager.removeFile(errorUrl);
        return Image.network(
          errorUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, err, stack) => Icon(
            Icons.shield_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }

  GunPresetItem _buildDefaultGunItem(Map<String, dynamic> weapon) {
    final defaultSkinUuid = (weapon['defaultSkinUuid'] ?? '').toString();
    final List skins = weapon['skins'] ?? [];

    dynamic defaultSkin;
    if (defaultSkinUuid.isNotEmpty) {
      try {
        defaultSkin = skins.firstWhere(
          (s) =>
              (s['uuid'] ?? '').toString().toLowerCase() ==
              defaultSkinUuid.toLowerCase(),
        );
      } catch (_) {}
    }

    defaultSkin ??= skins.firstWhere((s) {
      final name = (s['displayName'] ?? '').toString().toLowerCase();
      return name.startsWith('standard') || name == 'melee' || name == 'none';
    }, orElse: () => skins.isNotEmpty ? skins[0] : null);

    String skinId = defaultSkinUuid;
    String skinLevelId = defaultSkinUuid;
    String chromaId = defaultSkinUuid;

    if (defaultSkin != null) {
      skinId = defaultSkin['uuid'] ?? defaultSkinUuid;
      final List levels = defaultSkin['levels'] ?? [];
      final List chromas = defaultSkin['chromas'] ?? [];
      if (levels.isNotEmpty) skinLevelId = levels[0]['uuid'] ?? skinId;
      if (chromas.isNotEmpty) chromaId = chromas[0]['uuid'] ?? skinId;
    }

    return GunPresetItem(
      id: weapon['uuid'],
      skinId: skinId,
      skinLevelId: skinLevelId,
      chromaId: chromaId,
    );
  }

  Future<void> _handleSavePreset(List<dynamic> allWeapons) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a preset name'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final List<GunPresetItem> finalGuns = [];
    for (var weapon in allWeapons) {
      final weaponId = (weapon['uuid'] as String).toLowerCase();
      if (_gunMap.containsKey(weaponId)) {
        finalGuns.add(_gunMap[weaponId]!);
      } else {
        finalGuns.add(_buildDefaultGunItem(weapon));
      }
    }

    Map<String, dynamic>? identity;
    if (_cardId != null || _titleId != null) {
      identity = {
        if (_cardId != null) 'PlayerCardID': _cardId,
        if (_titleId != null) 'PlayerTitleID': _titleId,
      };
    }

    final filledSlots = _spraySlotIds.entries
        .where((e) => e.value != null)
        .toList();
    final sprays = filledSlots.isNotEmpty
        ? [
            for (final entry in filledSlots)
              {
                'EquipSlotID': entry.key,
                'SprayID': entry.value,
                'SprayLevelID': null,
              },
          ]
        : null;

    final preset = LoadoutPreset(
      id:
          widget.initialPreset?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      createdAt: widget.initialPreset?.createdAt ?? DateTime.now(),
      guns: finalGuns,
      identity: identity,
      sprays: sprays,
      expressions: widget.initialPreset?.expressions,
    );

    setState(() => _isSaving = true);
    try {
      await ref.read(presetsProvider.notifier).savePreset(preset);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "$name" preset!'),
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

  void _openIdentityPicker({
    required String itemType,
    required String title,
    required ValueChanged<String> onSelected,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemSelectionScreen(
          itemType: itemType,
          title: title,
          onSelected: onSelected,
        ),
      ),
    );
  }

  Widget _buildExtraRow(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String? valueName,
    required VoidCallback onTap,
    VoidCallback? onClear,
    String? imageUrl,
  }) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    cacheManager: CustomCacheManagers.loadoutPresetCacheManager,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        icon,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    errorWidget: (context, url, error) => SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        icon,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      valueName ?? 'Not set — optional',
                      style: TextStyle(
                        fontSize: 12,
                        color: valueName != null
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: valueName != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (valueName != null && onClear != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Clear',
                  onPressed: onClear,
                ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openWeaponPicker({
    required Map<String, dynamic> weapon,
    required Map<String, SkinMetadata> skinsMeta,
    required List<dynamic> allBuddies,
    required Set<String> ownedSkinIds,
    required Set<String> ownedBuddyIds,
    required List<dynamic> buddyEntitlements,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WeaponConfigSheet(
        weapon: weapon,
        currentGunItem: _gunMap[(weapon['uuid'] as String).toLowerCase()],
        skinsMeta: skinsMeta,
        allBuddies: allBuddies,
        ownedSkinIds: ownedSkinIds,
        ownedBuddyIds: ownedBuddyIds,
        buddyEntitlements: buddyEntitlements,
        onSave: (GunPresetItem item) {
          setState(() {
            _gunMap[(weapon['uuid'] as String).toLowerCase()] = item;
            _hasManualChanges = true;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weaponsAsync = ref.watch(weaponsProvider);
    final skinsAsync = ref.watch(skinsMetadataProvider);
    final buddiesAsync = ref.watch(allBuddiesProvider);

    final skinEntitlementsAsync = ref.watch(
      entitlementsProvider(
        'e7c63390-eda7-46e0-bb7a-a6abdacd2433,3ad1b2b2-acdb-4524-852f-954a76ddae0a',
      ),
    );
    final buddyEntitlementsAsync = ref.watch(
      entitlementsProvider('dd3bf334-87f3-40bd-b043-682a57a8dc3a'),
    );

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
          widget.initialPreset != null ? 'Edit Preset' : 'Create Preset',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: weaponsAsync.when(
        loading: () => const Center(child: FunnyLoadingView()),
        error: (e, _) => Center(child: Text('Error loading weapons: $e')),
        data: (weapons) {
          return skinsAsync.when(
            loading: () => const Center(child: FunnyLoadingView()),
            error: (e, _) => Center(child: Text('Error loading skins: $e')),
            data: (skinsMeta) {
              return buddiesAsync.when(
                loading: () => const Center(child: FunnyLoadingView()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (allBuddies) {
                  final ownedSkinIds = skinEntitlementsAsync.maybeWhen(
                    data: (ents) => ents
                        .map((e) => (e['ItemID'] as String).toLowerCase())
                        .toSet(),
                    orElse: () => <String>{},
                  );

                  final buddyEnts = buddyEntitlementsAsync.value ?? [];
                  final ownedBuddyIds = buddyEnts
                      .map((e) => (e['ItemID'] as String).toLowerCase())
                      .toSet();

                  final cardsMap = ref.watch(playerCardsProvider).value ?? {};
                  final titlesMap = ref.watch(titlesProvider).value ?? {};
                  final spraysMap = <String, dynamic>{
                    ...ref.watch(spraysProvider).value ?? {},
                    for (final flex
                        in ref.watch(allFlexesProvider).value ?? const [])
                      if (flex is Map && flex['uuid'] != null)
                        flex['uuid'] as String: flex,
                  };
                  final cardName = _cardId != null
                      ? (cardsMap[_cardId]?['displayName'] as String?)
                      : null;
                  final titleName = _titleId != null
                      ? ((titlesMap[_titleId]?['displayName'] ??
                                titlesMap[_titleId]?['titleText'])
                            as String?)
                      : null;
                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  10,
                                ),
                                child: TextField(
                                  controller: _nameController,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Preset Name',
                                    hintText: 'e.g. Icebox Vandal, Red Theme, Phantom Set',
                                    prefixIcon: const Icon(
                                      Icons.bookmark_outline,
                                    ),
                                    filled: true,
                                    fillColor:
                                        theme.colorScheme.surfaceContainer,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.tonalIcon(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        onPressed: _isRandomizing
                                            ? null
                                            : _handleRandomize,
                                        icon: _isRandomizing
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.casino_outlined,
                                                size: 18,
                                              ),
                                        label: Text(
                                          _isRandomizing
                                              ? 'Rolling...'
                                              : 'Randomize',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        onPressed:
                                            (_isRandomizing || _isLoadingActive)
                                            ? null
                                            : _handleLoadActive,
                                        icon: _isLoadingActive
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.download_outlined,
                                                size: 18,
                                              ),
                                        label: Text(
                                          _isLoadingActive
                                              ? 'Loading...'
                                              : 'Load Active',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 4,
                                ),
                                child: Text(
                                  'EXTRAS (OPTIONAL)',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  children: [
                                    _buildExtraRow(
                                      theme,
                                      icon: Icons.badge_outlined,
                                      label: 'Player Card',
                                      valueName: cardName,
                                      imageUrl: _cardId != null
                                          ? ((cardsMap[_cardId]?['smallArt'] ??
                                                    cardsMap[_cardId]?['displayIcon'])
                                                as String?)
                                          : null,
                                      onTap: () => _openIdentityPicker(
                                        itemType: 'card',
                                        title: 'Choose Player Card',
                                        onSelected: (id) =>
                                            setState(() => _cardId = id),
                                      ),
                                      onClear: () =>
                                          setState(() => _cardId = null),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildExtraRow(
                                      theme,
                                      icon: Icons.title,
                                      label: 'Player Title',
                                      valueName: titleName,
                                      onTap: () => _openIdentityPicker(
                                        itemType: 'title',
                                        title: 'Choose Player Title',
                                        onSelected: (id) =>
                                            setState(() => _titleId = id),
                                      ),
                                      onClear: () =>
                                          setState(() => _titleId = null),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Sprays',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Tap a slot — optional',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: PresetSprayWheel(
                                  slotSprayIds: _spraySlotIds,
                                  spraysMap: spraysMap,
                                  onTapSlot: (slotId, slotName) =>
                                      _openIdentityPicker(
                                        itemType: 'spray',
                                        title: 'Choose $slotName Spray',
                                        onSelected: (id) => setState(
                                          () => _spraySlotIds[slotId] = id,
                                        ),
                                      ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'WEAPONS & SKINS (${weapons.length})',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.1,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Tap any weapon to customize',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 6),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Column(
                                  children: [
                                    for (final weapon in weapons)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: Builder(
                                          builder: (context) {
                                            final weaponId =
                                                (weapon['uuid'] as String)
                                                    .toLowerCase();
                                            final gunItem =
                                                _gunMap[weaponId] ??
                                                _buildDefaultGunItem(weapon);

                                            String skinName = 'Standard';
                                            final meta =
                                                skinsMeta[gunItem
                                                    .skinLevelId] ??
                                                skinsMeta[gunItem.skinId] ??
                                                skinsMeta[gunItem.chromaId];
                                            if (meta != null) {
                                              skinName = meta.displayName;
                                            }

                                            final skinImage =
                                                WeaponAssetResolver.resolveSkinImageUrl(
                                                  weapon: weapon,
                                                  skinId: gunItem.skinId,
                                                  skinLevelId:
                                                      gunItem.skinLevelId,
                                                  chromaId: gunItem.chromaId,
                                                  skinsMap: skinsMeta,
                                                );

                                            final buddyImage =
                                                WeaponAssetResolver.resolveBuddyImageUrl(
                                                  charmId: gunItem.charmId,
                                                  buddiesMap: {
                                                    for (var b in allBuddies)
                                                      if (b
                                                              is Map<
                                                                String,
                                                                dynamic
                                                              > &&
                                                          b['uuid'] != null)
                                                        b['uuid']: b,
                                                  },
                                                );

                                            return Card(
                                              elevation: 0,
                                              color: theme
                                                  .colorScheme
                                                  .surfaceContainer,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                side: BorderSide(
                                                  color: theme
                                                      .colorScheme
                                                      .primary
                                                      .withValues(alpha: 0.5),
                                                ),
                                              ),
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                onTap: () => _openWeaponPicker(
                                                  weapon: weapon,
                                                  skinsMeta: skinsMeta,
                                                  allBuddies: allBuddies,
                                                  ownedSkinIds: ownedSkinIds,
                                                  ownedBuddyIds: ownedBuddyIds,
                                                  buddyEntitlements: buddyEnts,
                                                ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 12,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      SizedBox(
                                                        width: 80,
                                                        height: 44,
                                                        child: Stack(
                                                          clipBehavior:
                                                              Clip.none,
                                                          children: [
                                                            _buildSafeImage(
                                                              skinImage,
                                                              theme,
                                                              width: 80,
                                                              height: 44,
                                                            ),
                                                            if (buddyImage !=
                                                                null)
                                                              Positioned(
                                                                right: -6,
                                                                bottom: -6,
                                                                child: Container(
                                                                  width: 22,
                                                                  height: 22,
                                                                  decoration: BoxDecoration(
                                                                    color: theme
                                                                        .colorScheme
                                                                        .surfaceContainer,
                                                                    shape: BoxShape
                                                                        .circle,
                                                                    border: Border.all(
                                                                      color: theme
                                                                          .colorScheme
                                                                          .surface,
                                                                      width:
                                                                          1.5,
                                                                    ),
                                                                  ),
                                                                  padding:
                                                                      const EdgeInsets.all(
                                                                        2,
                                                                      ),
                                                                  child: _buildSafeImage(
                                                                    buddyImage,
                                                                    theme,
                                                                    width: 18,
                                                                    height: 18,
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 18),

                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              weapon['displayName'] ??
                                                                  '',
                                                              style: GoogleFonts.inter(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurface,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Text(
                                                              skinName,
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: theme
                                                                    .colorScheme
                                                                    .primary,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ],
                                                        ),
                                                      ),

                                                      Icon(
                                                        Icons.edit_outlined,
                                                        size: 18,
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
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
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _isSaving
                                    ? null
                                    : () => _handleSavePreset(weapons),
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(
                                  _isSaving ? 'Saving...' : 'Save Preset',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
