import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:valorant_thunai/models/loadout_preset.dart';
import 'package:valorant_thunai/providers/skin_provider.dart';
import 'package:valorant_thunai/utils/cache_managers.dart';
import 'package:valorant_thunai/utils/weapon_asset_resolver.dart';

class WeaponConfigSheet extends StatefulWidget {
  final Map<String, dynamic> weapon;
  final GunPresetItem? currentGunItem;
  final Map<String, SkinMetadata> skinsMeta;
  final List<dynamic> allBuddies;
  final Set<String> ownedSkinIds;
  final Set<String> ownedBuddyIds;
  final List<dynamic> buddyEntitlements;
  final ValueChanged<GunPresetItem> onSave;

  const WeaponConfigSheet({
    super.key,
    required this.weapon,
    this.currentGunItem,
    required this.skinsMeta,
    required this.allBuddies,
    required this.ownedSkinIds,
    required this.ownedBuddyIds,
    required this.buddyEntitlements,
    required this.onSave,
  });

  @override
  State<WeaponConfigSheet> createState() => _WeaponConfigSheetState();
}

class _WeaponConfigSheetState extends State<WeaponConfigSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedSkinId;
  String? _selectedLevelId;
  String? _selectedChromaId;
  String? _selectedCharmId;
  String? _selectedCharmLevelId;
  String? _selectedCharmInstanceId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final gun = widget.currentGunItem;
    if (gun != null) {
      _selectedSkinId = gun.skinId;
      _selectedLevelId = gun.skinLevelId;
      _selectedChromaId = gun.chromaId;
      _selectedCharmId = gun.charmId;
      _selectedCharmLevelId = gun.charmLevelId;
      _selectedCharmInstanceId = gun.charmInstanceId;
    } else {
      final List skins = widget.weapon['skins'] ?? [];
      final defaultSkinUuid = widget.weapon['defaultSkinUuid'] as String? ?? '';
      final defaultSkin = skins.firstWhere((s) {
        final name = (s['displayName'] ?? '').toString().toLowerCase();
        final uuid = (s['uuid'] ?? '').toString().toLowerCase();
        return name.startsWith('standard') ||
            name == 'melee' ||
            name == 'none' ||
            (defaultSkinUuid.isNotEmpty &&
                uuid == defaultSkinUuid.toLowerCase());
      }, orElse: () => skins.isNotEmpty ? skins[0] : null);

      if (defaultSkin != null) {
        _selectedSkinId = defaultSkin['uuid'] ?? defaultSkinUuid;
        final List levels = defaultSkin['levels'] ?? [];
        final List chromas = defaultSkin['chromas'] ?? [];
        _selectedLevelId = levels.isNotEmpty
            ? levels[0]['uuid']
            : _selectedSkinId;
        _selectedChromaId = chromas.isNotEmpty
            ? chromas[0]['uuid']
            : _selectedSkinId;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  void _applySelection() {
    final item = GunPresetItem(
      id: widget.weapon['uuid'],
      skinId: _selectedSkinId ?? widget.weapon['defaultSkinUuid'] ?? '',
      skinLevelId: _selectedLevelId ?? _selectedSkinId ?? '',
      chromaId: _selectedChromaId ?? _selectedLevelId ?? _selectedSkinId ?? '',
      charmId: _selectedCharmId,
      charmLevelId: _selectedCharmLevelId,
      charmInstanceId: _selectedCharmInstanceId,
    );
    widget.onSave(item);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List allSkins = widget.weapon['skins'] ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Customize ${widget.weapon['displayName']}',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Skins & Chromas'),
              Tab(text: 'Gun Buddy'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSkinsTab(allSkins, theme),

                _buildBuddiesTab(theme),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _applySelection,
                child: const Text('Apply Weapon Selection'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkinsTab(List allSkins, ThemeData theme) {
    final defaultSkinUuid = (widget.weapon['defaultSkinUuid'] ?? '').toString();
    final weaponUuid = (widget.weapon['uuid'] ?? '').toString();

    dynamic defaultSkin;
    if (defaultSkinUuid.isNotEmpty) {
      try {
        defaultSkin = allSkins.firstWhere(
          (s) =>
              (s['uuid'] ?? '').toString().toLowerCase() ==
              defaultSkinUuid.toLowerCase(),
        );
      } catch (_) {}
    }

    defaultSkin ??= allSkins.firstWhere((s) {
      final name = (s['displayName'] ?? '').toString().toLowerCase();
      return name.startsWith('standard') || name == 'melee' || name == 'none';
    }, orElse: () => allSkins.isNotEmpty ? allSkins[0] : null);

    final defaultSkinId = (defaultSkin?['uuid'] ?? defaultSkinUuid)
        .toString()
        .toLowerCase();

    final filteredOwned = allSkins.where((skin) {
      final skinId = (skin['uuid'] as String? ?? '').toLowerCase();
      final name = (skin['displayName'] as String? ?? '').toLowerCase();
      if (name.startsWith('standard') ||
          name == 'melee' ||
          name == 'none' ||
          (defaultSkinUuid.isNotEmpty &&
              skinId == defaultSkinUuid.toLowerCase()) ||
          (weaponUuid.isNotEmpty && skinId == weaponUuid.toLowerCase()) ||
          (defaultSkinId.isNotEmpty && skinId == defaultSkinId)) {
        return false;
      }

      final List levels = skin['levels'] ?? [];
      final List chromas = skin['chromas'] ?? [];
      final ownsLevel = levels.any(
        (l) =>
            widget.ownedSkinIds.contains((l['uuid'] as String).toLowerCase()),
      );
      final ownsChroma = chromas.any(
        (c) =>
            widget.ownedSkinIds.contains((c['uuid'] as String).toLowerCase()),
      );
      final ownsRoot = widget.ownedSkinIds.contains(skinId);
      return ownsLevel || ownsChroma || ownsRoot;
    }).toList();

    final selSkinId = (_selectedSkinId ?? '').toLowerCase();
    final isStandardSelected =
        selSkinId.isEmpty ||
        selSkinId == defaultSkinUuid.toLowerCase() ||
        selSkinId == weaponUuid.toLowerCase() ||
        selSkinId == defaultSkinId;

    final defLevels = defaultSkin?['levels'] as List? ?? [];
    final defChromas = defaultSkin?['chromas'] as List? ?? [];
    final defaultLevelId = defLevels.isNotEmpty
        ? (defLevels[0]['uuid'] as String?)
        : null;
    final defaultChromaId = defChromas.isNotEmpty
        ? (defChromas[0]['uuid'] as String?)
        : null;

    String defaultIcon = WeaponAssetResolver.resolveSkinImageUrl(
      weapon: widget.weapon,
      skinId: defaultSkin?['uuid'] ?? defaultSkinUuid,
      skinLevelId: defaultLevelId,
      chromaId: defaultChromaId,
      skinsMap: widget.skinsMeta,
    );
    if (defaultIcon.isEmpty) {
      defaultIcon = WeaponAssetResolver.extractSkinDisplayIcon(defaultSkin);
    }
    if (defaultIcon.isEmpty) {
      defaultIcon =
          widget.weapon['displayIcon'] as String? ??
          widget.weapon['killStreamIcon'] as String? ??
          '';
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filteredOwned.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            color: isStandardSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                : theme.colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isStandardSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: isStandardSelected ? 2 : 1,
              ),
            ),
            child: ListTile(
              leading: SizedBox(
                width: 60,
                height: 36,
                child: _buildSafeImage(
                  defaultIcon,
                  theme,
                  width: 60,
                  height: 36,
                ),
              ),
              title: Text(
                'Standard (Default)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isStandardSelected
                      ? FontWeight.bold
                      : FontWeight.w600,
                  color: isStandardSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                'Standard default factory weapon appearance',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: isStandardSelected
                  ? Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      size: 20,
                    )
                  : null,
              onTap: () {
                final defLevels = defaultSkin?['levels'] as List? ?? [];
                final defChromas = defaultSkin?['chromas'] as List? ?? [];
                setState(() {
                  _selectedSkinId = defaultSkin?['uuid'] ?? defaultSkinUuid;
                  _selectedLevelId = defLevels.isNotEmpty
                      ? defLevels[0]['uuid']
                      : _selectedSkinId;
                  _selectedChromaId = defChromas.isNotEmpty
                      ? defChromas[0]['uuid']
                      : _selectedSkinId;
                });
              },
            ),
          );
        }

        final skin = filteredOwned[index - 1];
        final skinId = skin['uuid'] as String;
        final isSelectedSkin = _selectedSkinId == skinId;
        final List chromas = skin['chromas'] ?? [];
        final List levels = skin['levels'] ?? [];

        String displayIcon = WeaponAssetResolver.extractSkinDisplayIcon(skin);
        if (displayIcon.isEmpty) {
          displayIcon = WeaponAssetResolver.resolveSkinImageUrl(
            weapon: widget.weapon,
            skinId: skinId,
            skinsMap: widget.skinsMeta,
          );
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          color: isSelectedSkin
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
              : theme.colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isSelectedSkin
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: isSelectedSkin ? 2 : 1,
            ),
          ),
          child: ExpansionTile(
            key: Key(skinId),
            initiallyExpanded: isSelectedSkin,
            leading: SizedBox(
              width: 60,
              height: 36,
              child: _buildSafeImage(displayIcon, theme, width: 60, height: 36),
            ),
            title: Text(
              skin['displayName'] ?? '',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelectedSkin ? FontWeight.bold : FontWeight.w600,
                color: isSelectedSkin
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
              ),
            ),
            trailing: isSelectedSkin
                ? Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                    size: 20,
                  )
                : null,
            onExpansionChanged: (expanded) {
              if (expanded) {
                setState(() {
                  _selectedSkinId = skinId;
                  _selectedLevelId = levels.isNotEmpty
                      ? levels[0]['uuid']
                      : skinId;
                  _selectedChromaId = chromas.isNotEmpty
                      ? chromas[0]['uuid']
                      : skinId;
                });
              }
            },
            children: [
              if (chromas.length > 1) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chromas / Variants',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: chromas.map<Widget>((c) {
                          final cId = c['uuid'] as String;
                          final isSelectedChroma = _selectedChromaId == cId;
                          final cSwatch = c['swatch'] as String?;

                          return ChoiceChip(
                            label: Text(
                              c['displayName'] ?? 'Variant',
                              style: const TextStyle(fontSize: 11),
                            ),
                            avatar: cSwatch != null && cSwatch.isNotEmpty
                                ? CircleAvatar(
                                    backgroundImage: CachedNetworkImageProvider(
                                      cSwatch,
                                    ),
                                    radius: 8,
                                  )
                                : null,
                            selected: isSelectedChroma,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedSkinId = skinId;
                                  _selectedLevelId = levels.isNotEmpty
                                      ? levels.last['uuid']
                                      : skinId;
                                  _selectedChromaId = cId;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBuddiesTab(ThemeData theme) {
    final filtered = widget.allBuddies.where((b) {
      final name = (b['displayName'] as String? ?? '').toLowerCase();
      if (name == 'none' || name == 'standard') return false;

      final List levels = b['levels'] ?? [];
      return levels.any(
        (l) =>
            widget.ownedBuddyIds.contains((l['uuid'] as String).toLowerCase()),
      );
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          final isNoneSelected =
              _selectedCharmId == null || _selectedCharmId!.isEmpty;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            color: isNoneSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                : theme.colorScheme.surfaceContainer,
            child: ListTile(
              leading: const Icon(Icons.block),
              title: const Text('None (No Gun Buddy)'),
              trailing: isNoneSelected
                  ? Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      size: 20,
                    )
                  : null,
              onTap: () {
                setState(() {
                  _selectedCharmId = null;
                  _selectedCharmLevelId = null;
                  _selectedCharmInstanceId = null;
                });
              },
            ),
          );
        }

        final buddy = filtered[index - 1];
        final buddyId = buddy['uuid'] as String;
        final isSelected = _selectedCharmId == buddyId;
        final List levels = buddy['levels'] ?? [];
        final levelId = levels.isNotEmpty ? levels[0]['uuid'] : buddyId;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
              : theme.colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ListTile(
            leading: SizedBox(
              width: 40,
              height: 40,
              child: _buildSafeImage(
                buddy['displayIcon'] ?? '',
                theme,
                width: 40,
                height: 40,
              ),
            ),
            title: Text(
              buddy['displayName'] ?? '',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            trailing: isSelected
                ? Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                    size: 20,
                  )
                : null,
            onTap: () {
              String? instanceId;
              final match = widget.buddyEntitlements
                  .cast<Map<String, dynamic>?>()
                  .firstWhere(
                    (e) =>
                        e != null &&
                        levels.any(
                          (lvl) =>
                              (lvl['uuid'] as String).toLowerCase() ==
                              (e['ItemID'] as String).toLowerCase(),
                        ),
                    orElse: () => null,
                  );
              instanceId = match?['InstanceID'];

              setState(() {
                _selectedCharmId = buddyId;
                _selectedCharmLevelId = levelId;
                _selectedCharmInstanceId = instanceId ?? '';
              });
            },
          ),
        );
      },
    );
  }
}
