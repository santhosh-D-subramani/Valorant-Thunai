import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/utils/cache_managers.dart';
import 'package:valorant_thunai/utils/weapon_asset_resolver.dart';
import 'package:valorant_thunai/providers/loadout_provider.dart';
import 'package:valorant_thunai/providers/weapons_provider.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class ItemSelectionScreen extends ConsumerStatefulWidget {
  final String? weaponId;
  final String itemType;
  final String title;
  final String? slotId;

  final ValueChanged<String>? onSelected;

  const ItemSelectionScreen({
    super.key,
    this.weaponId,
    required this.itemType,
    required this.title,
    this.slotId,
    this.onSelected,
  });

  @override
  ConsumerState<ItemSelectionScreen> createState() =>
      _ItemSelectionScreenState();
}

class _ItemSelectionScreenState extends ConsumerState<ItemSelectionScreen> {
  static const _defaultFlexIds = {
    '90f0a554-41b3-355b-6846-74a27aa3f7b9',
    'af52b5a0-4a4c-03b2-c9d7-8187a08a2675',
  };

  String searchQuery = '';
  int selectedTabIndex = 0;
  int sprayCategoryIndex = 0;
  bool isSaving = false;

  bool _isDefaultFlex(Map<dynamic, dynamic> flex) {
    return _defaultFlexIds.contains(flex['uuid']?.toString().toLowerCase());
  }

  String _getItemTypeId() {
    switch (widget.itemType) {
      case 'skin':
        return 'e7c63390-eda7-46e0-bb7a-a6abdacd2433,3ad1b2b2-acdb-4524-852f-954a76ddae0a';
      case 'buddy':
        return 'dd3bf334-87f3-40bd-b043-682a57a8dc3a';
      case 'title':
        return 'de7caa6b-adf7-4588-bbd1-143831e786c6';
      case 'card':
        return '3f296c07-64c3-494c-923b-fe692a4fa1bd';
      case 'spray':
        return 'd5f120f8-ff8c-4aac-92ea-f2b5acbe9475';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final itemTypeId = _getItemTypeId();
    final entitlementsAsync = ref.watch(entitlementsProvider(itemTypeId));

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
          widget.title,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: TextField(
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.searchPlaceholder,
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: entitlementsAsync.maybeWhen(
                  data: (entitlements) {
                    final ownedCount = entitlements.length;
                    int finalOwnedCount = ownedCount;
                    if (widget.itemType == 'spray') {
                      final ownedIds = entitlements
                          .map((e) => (e['ItemID'] as String).toLowerCase())
                          .toSet();
                      if (sprayCategoryIndex == 2) {
                        final flexesAsync = ref.watch(allFlexesProvider);
                        finalOwnedCount = flexesAsync.maybeWhen(
                          data: (flexes) => flexes.where((f) {
                            return _isDefaultFlex(f) ||
                                ownedIds.contains(
                                  (f['uuid'] as String).toLowerCase(),
                                );
                          }).length,
                          orElse: () => 0,
                        );
                      } else {
                        final spraysAsync = ref.watch(allSpraysProvider);
                        finalOwnedCount = spraysAsync.maybeWhen(
                          data: (sprays) => sprays.where((spray) {
                            if (spray['category'] ==
                                'EAresSprayCategory::Contextual') {
                              return false;
                            }
                            final isAnimated =
                                spray['animationGif'] != null ||
                                spray['animationPng'] != null;
                            if (sprayCategoryIndex == 0 && isAnimated) {
                              return false;
                            }
                            if (sprayCategoryIndex == 1 && !isAnimated) {
                              return false;
                            }

                            final List levels = spray['levels'] ?? [];
                            final bool ownsLevel = levels.any(
                              (lvl) => ownedIds.contains(
                                (lvl['uuid'] as String).toLowerCase(),
                              ),
                            );
                            final displayName =
                                spray['displayName'] as String? ?? '';
                            final isDefaultOrNone =
                                displayName.toLowerCase() == 'none' ||
                                displayName.toLowerCase() == 'standard';
                            return isDefaultOrNone ||
                                ownedIds.contains(
                                  (spray['uuid'] as String).toLowerCase(),
                                ) ||
                                ownsLevel;
                          }).length,
                          orElse: () => 0,
                        );
                      }
                    }

                    return Column(
                      children: [
                        if (widget.itemType == 'spray')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: SegmentedButton<int>(
                              style: SegmentedButton.styleFrom(
                                backgroundColor: Theme.of(context).cardColor,
                                selectedBackgroundColor: Colors.red,
                                selectedForegroundColor: Colors.white,
                                foregroundColor: Colors.grey,
                              ),
                              segments: [
                                ButtonSegment(
                                  value: 0,
                                  label: Text(l10n.sprayCategoryTab),
                                  icon: const Icon(Icons.format_paint),
                                ),
                                ButtonSegment(
                                  value: 1,
                                  label: Text(l10n.gifSprayCategoryTab),
                                  icon: const Icon(Icons.gif_box),
                                ),
                                ButtonSegment(
                                  value: 2,
                                  label: Text(l10n.flexCategoryTab),
                                  icon: const Icon(Icons.emoji_emotions),
                                ),
                              ],
                              selected: {sprayCategoryIndex},
                              onSelectionChanged: (newSelection) {
                                setState(() {
                                  sprayCategoryIndex = newSelection.first;
                                });
                              },
                            ),
                          ),
                        SegmentedButton<int>(
                          style: SegmentedButton.styleFrom(
                            backgroundColor: Theme.of(context).cardColor,
                            selectedBackgroundColor: Colors.red,
                            selectedForegroundColor: Colors.white,
                            foregroundColor: Colors.grey,
                          ),
                          segments: [
                            ButtonSegment(
                              value: 0,
                              label: Text(l10n.totalTab),
                              icon: const Icon(Icons.all_inclusive),
                            ),
                            ButtonSegment(
                              value: 1,
                              label: Text(l10n.ownedCountTab(finalOwnedCount)),
                              icon: const Icon(Icons.check_circle_outline),
                            ),
                          ],
                          selected: {selectedTabIndex},
                          onSelectionChanged: (newSelection) {
                            setState(() {
                              selectedTabIndex = newSelection.first;
                            });
                          },
                        ),
                      ],
                    );
                  },
                  orElse: () => const SizedBox(),
                ),
              ),

              Expanded(child: _buildList(entitlementsAsync)),
            ],
          ),
          if (isSaving)
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildList(AsyncValue<List<dynamic>> entitlementsAsync) {
    final l10n = AppLocalizations.of(context)!;
    return entitlementsAsync.when(
      loading: () => const Center(child: FunnyLoadingView()),
      error: (err, _) => Center(
        child: Text(
          l10n.errorMessage(err.toString()),
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (entitlements) {
        final ownedIds = entitlements
            .map((e) => (e['ItemID'] as String).toLowerCase())
            .toSet();

        if (widget.itemType == 'skin') {
          return _buildSkinsList(ownedIds);
        } else if (widget.itemType == 'buddy') {
          return _buildBuddiesList(ownedIds, entitlements);
        } else if (widget.itemType == 'title') {
          return _buildTitlesList(ownedIds);
        } else if (widget.itemType == 'spray') {
          if (sprayCategoryIndex == 2) {
            return _buildFlexList(ownedIds);
          }
          return _buildSpraysList(ownedIds);
        } else if (widget.itemType == 'card') {
          return _buildCardsList(ownedIds);
        } else {
          return Center(
            child: Text(
              l10n.unknownItemType,
              style: const TextStyle(color: Colors.white),
            ),
          );
        }
      },
    );
  }

  Widget _buildSkinsList(Set<String> ownedIds) {
    final l10n = AppLocalizations.of(context)!;
    final weaponsAsync = ref.watch(weaponsProvider);
    return weaponsAsync.when(
      loading: () => const Center(child: FunnyLoadingView()),
      error: (e, _) => Center(
        child: Text(
          l10n.errorMessage(e.toString()),
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (weapons) {
        final weapon = weapons.firstWhere(
          (w) =>
              (w['uuid'] as String).toLowerCase() ==
              widget.weaponId?.toLowerCase(),
          orElse: () => null,
        );
        if (weapon == null) {
          return Center(
            child: Text(
              l10n.weaponNotFoundMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        }
        final List skinsList = weapon['skins'] ?? [];
        final defaultSkinUuid = (weapon['defaultSkinUuid'] as String? ?? '')
            .toLowerCase();

        bool isDefaultSkin(Map<dynamic, dynamic> skin) {
          final name = (skin['displayName'] ?? '').toString().toLowerCase();
          final uuid = (skin['uuid'] ?? '').toString().toLowerCase();
          return name.startsWith('standard') ||
              name == 'melee' ||
              name == 'none' ||
              (defaultSkinUuid.isNotEmpty && uuid == defaultSkinUuid);
        }

        final filteredSkins = skinsList.where((skin) {
          final nameMatches = (skin['displayName'] as String)
              .toLowerCase()
              .contains(searchQuery);
          if (!nameMatches) return false;

          if (selectedTabIndex == 1) {
            final bool isDef = isDefaultSkin(skin);
            if (isDef) return true;

            final List levels = skin['levels'] ?? [];
            final List chromas = skin['chromas'] ?? [];
            final bool ownsSkinLevel = levels.any(
              (lvl) => ownedIds.contains((lvl['uuid'] as String).toLowerCase()),
            );
            final bool ownsChroma = chromas.any(
              (c) => ownedIds.contains((c['uuid'] as String).toLowerCase()),
            );
            final bool ownsRoot = ownedIds.contains(
              (skin['uuid'] as String).toLowerCase(),
            );
            return ownsSkinLevel || ownsChroma || ownsRoot;
          }
          return true;
        }).toList();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filteredSkins.length,
          separatorBuilder: (context, index) =>
              Divider(color: Theme.of(context).dividerColor),
          itemBuilder: (context, index) {
            final skin = filteredSkins[index];
            final List levels = skin['levels'] ?? [];
            final List chromas = skin['chromas'] ?? [];

            final String levelId = levels.isNotEmpty
                ? levels[0]['uuid']
                : skin['uuid'];
            final String chromaId = chromas.isNotEmpty
                ? chromas[0]['uuid']
                : skin['uuid'];

            final bool isDef = isDefaultSkin(skin);
            final bool ownsSkinLevel = levels.any(
              (lvl) => ownedIds.contains((lvl['uuid'] as String).toLowerCase()),
            );
            final bool ownsChroma = chromas.any(
              (c) => ownedIds.contains((c['uuid'] as String).toLowerCase()),
            );
            final bool ownsRoot = ownedIds.contains(
              (skin['uuid'] as String).toLowerCase(),
            );
            final bool isOwned =
                isDef || ownsSkinLevel || ownsChroma || ownsRoot;

            String displayIcon = WeaponAssetResolver.extractSkinDisplayIcon(
              skin,
            );
            if (displayIcon.isEmpty) {
              displayIcon =
                  weapon['displayIcon'] ?? weapon['killStreamIcon'] ?? '';
            }

            final String skinId = skin['uuid'];
            final String displayName = skin['displayName'] ?? '';
            return ListTile(
              title: Text(
                displayName,
                style: GoogleFonts.inter(
                  color: isOwned
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: SizedBox(
                width: 80,
                height: 40,
                child: CachedNetworkImage(
                  imageUrl: displayIcon,
                  cacheManager: CustomCacheManagers.loadoutPresetCacheManager,
                  fit: BoxFit.contain,
                  errorWidget: (context, url, error) => Icon(
                    Icons.broken_image,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              trailing: isOwned
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : Icon(
                      Icons.lock,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              onTap: isOwned
                  ? () => _selectSkin(skinId, levelId, chromaId)
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildBuddiesList(Set<String> ownedIds, List<dynamic> entitlements) {
    final l10n = AppLocalizations.of(context)!;
    final buddiesAsync = ref.watch(allBuddiesProvider);
    return buddiesAsync.when(
      loading: () => const Center(child: FunnyLoadingView()),
      error: (e, _) => Center(
        child: Text(
          l10n.errorMessage(e.toString()),
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (buddies) {
        final filtered = buddies.where((buddy) {
          final nameMatches = (buddy['displayName'] as String)
              .toLowerCase()
              .contains(searchQuery);
          if (!nameMatches) return false;

          if (selectedTabIndex == 1) {
            final List levels = buddy['levels'] ?? [];
            final String displayName = buddy['displayName'] ?? '';
            final bool isDefaultOrNone =
                displayName.toLowerCase() == 'none' ||
                displayName.toLowerCase() == 'standard';
            return isDefaultOrNone ||
                levels.any(
                  (lvl) =>
                      ownedIds.contains((lvl['uuid'] as String).toLowerCase()),
                );
          }
          return true;
        }).toList();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (context, index) =>
              Divider(color: Theme.of(context).dividerColor),
          itemBuilder: (context, index) {
            final buddy = filtered[index];
            final List levels = buddy['levels'] ?? [];
            final String levelId = levels.isNotEmpty
                ? levels[0]['uuid']
                : buddy['uuid'];

            final String displayName = buddy['displayName'] ?? '';
            final bool isDefaultOrNone =
                displayName.toLowerCase() == 'none' ||
                displayName.toLowerCase() == 'standard';
            final bool isOwned =
                isDefaultOrNone ||
                levels.any(
                  (lvl) =>
                      ownedIds.contains((lvl['uuid'] as String).toLowerCase()),
                );

            String? instanceId;
            if (isOwned) {
              final ent = entitlements.firstWhere(
                (e) => levels.any(
                  (lvl) =>
                      (lvl['uuid'] as String).toLowerCase() ==
                      (e['ItemID'] as String).toLowerCase(),
                ),
                orElse: () => null,
              );
              instanceId = ent?['InstanceID'];
            }

            return ListTile(
              title: Text(
                buddy['displayName'] ?? '',
                style: GoogleFonts.inter(
                  color: isOwned
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: SizedBox(
                width: 50,
                height: 50,
                child: CachedNetworkImage(
                  imageUrl: buddy['displayIcon'] ?? '',
                  cacheManager: CustomCacheManagers.loadoutPresetCacheManager,
                  fit: BoxFit.contain,
                  errorWidget: (context, url, error) => Icon(
                    Icons.broken_image,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              trailing: isOwned
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : Icon(
                      Icons.lock,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              onTap: isOwned
                  ? () => _selectBuddy(buddy['uuid'], levelId, instanceId ?? '')
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildTitlesList(Set<String> ownedIds) {
    final l10n = AppLocalizations.of(context)!;
    final titlesAsync = ref.watch(allTitlesProvider);
    return titlesAsync.when(
      loading: () => const Center(child: FunnyLoadingView()),
      error: (e, _) => Center(
        child: Text(
          l10n.errorMessage(e.toString()),
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (titles) {
        final filtered = titles.where((title) {
          final String titleText =
              title['titleText'] ?? title['displayName'] ?? '';
          final nameMatches = titleText.toLowerCase().contains(searchQuery);
          if (!nameMatches) return false;

          if (selectedTabIndex == 1) {
            final String titleText =
                title['titleText'] ?? title['displayName'] ?? '';
            final bool isDefaultOrNone =
                titleText.toLowerCase() == 'none' ||
                titleText.toLowerCase() == 'standard';
            return isDefaultOrNone ||
                ownedIds.contains((title['uuid'] as String).toLowerCase());
          }
          return true;
        }).toList();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (context, index) =>
              Divider(color: Theme.of(context).dividerColor),
          itemBuilder: (context, index) {
            final title = filtered[index];
            final String titleText =
                title['titleText'] ?? title['displayName'] ?? '';
            final String uuid = title['uuid'];
            final bool isDefaultOrNone =
                titleText.toLowerCase() == 'none' ||
                titleText.toLowerCase() == 'standard';
            final bool isOwned =
                isDefaultOrNone || ownedIds.contains(uuid.toLowerCase());

            return ListTile(
              title: Text(
                titleText.isEmpty ? l10n.noTitleText : titleText,
                style: GoogleFonts.inter(
                  color: isOwned
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: isOwned
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : Icon(
                      Icons.lock,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              onTap: isOwned ? () => _selectTitle(uuid) : null,
            );
          },
        );
      },
    );
  }

  Widget _buildSpraysList(Set<String> ownedIds) {
    final l10n = AppLocalizations.of(context)!;
    final spraysAsync = ref.watch(allSpraysProvider);
    return spraysAsync.when(
      loading: () => const Center(child: FunnyLoadingView()),
      error: (e, _) => Center(
        child: Text(
          l10n.errorMessage(e.toString()),
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (sprays) {
        final filtered = sprays.where((spray) {
          final nameMatches = (spray['displayName'] as String)
              .toLowerCase()
              .contains(searchQuery);
          if (!nameMatches) return false;

          final isFlex = spray['category'] == 'EAresSprayCategory::Contextual';
          if (isFlex) return false;

          final isAnimated =
              spray['animationGif'] != null || spray['animationPng'] != null;
          if (sprayCategoryIndex == 0 && isAnimated) return false;
          if (sprayCategoryIndex == 1 && !isAnimated) return false;

          if (selectedTabIndex == 1) {
            final List levels = spray['levels'] ?? [];
            final bool ownsLevel = levels.any(
              (lvl) => ownedIds.contains((lvl['uuid'] as String).toLowerCase()),
            );
            final String displayName = spray['displayName'] ?? '';
            final bool isDefaultOrNone =
                displayName.toLowerCase() == 'none' ||
                displayName.toLowerCase() == 'standard';
            return isDefaultOrNone ||
                ownedIds.contains((spray['uuid'] as String).toLowerCase()) ||
                ownsLevel;
          }
          return true;
        }).toList();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (context, index) =>
              Divider(color: Theme.of(context).dividerColor),
          itemBuilder: (context, index) {
            final spray = filtered[index];
            final String uuid = spray['uuid'];
            final List levels = spray['levels'] ?? [];
            final bool ownsLevel = levels.any(
              (lvl) => ownedIds.contains((lvl['uuid'] as String).toLowerCase()),
            );
            final String displayName = spray['displayName'] ?? '';
            final bool isDefaultOrNone =
                displayName.toLowerCase() == 'none' ||
                displayName.toLowerCase() == 'standard';
            final bool isOwned =
                isDefaultOrNone ||
                ownedIds.contains(uuid.toLowerCase()) ||
                ownsLevel;

            return ListTile(
              title: Text(
                spray['displayName'] ?? '',
                style: GoogleFonts.inter(
                  color: isOwned
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: SizedBox(
                width: 50,
                height: 50,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CachedNetworkImage(
                      imageUrl:
                          spray['fullTransparentIcon'] ??
                          spray['displayIcon'] ??
                          '',
                      cacheManager:
                          CustomCacheManagers.loadoutPresetCacheManager,
                      fit: BoxFit.contain,
                      errorWidget: (context, url, error) => Icon(
                        Icons.broken_image,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (spray['animationGif'] != null ||
                        spray['animationPng'] != null)
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.timelapse,
                            size: 12,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              trailing: isOwned
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : Icon(
                      Icons.lock,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              onTap: isOwned ? () => _selectSpray(uuid) : null,
            );
          },
        );
      },
    );
  }

  Widget _buildCardsList(Set<String> ownedIds) {
    final l10n = AppLocalizations.of(context)!;
    final cardsAsync = ref.watch(allCardsProvider);
    return cardsAsync.when(
      loading: () => const Center(child: FunnyLoadingView()),
      error: (e, _) => Center(
        child: Text(
          l10n.errorMessage(e.toString()),
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (cards) {
        final filtered = cards.where((card) {
          final nameMatches = (card['displayName'] as String)
              .toLowerCase()
              .contains(searchQuery);
          if (!nameMatches) return false;

          if (selectedTabIndex == 1) {
            final String displayName = card['displayName'] ?? '';
            final bool isDefaultOrNone =
                displayName.toLowerCase() == 'none' ||
                displayName.toLowerCase() == 'standard';
            return isDefaultOrNone ||
                ownedIds.contains((card['uuid'] as String).toLowerCase());
          }
          return true;
        }).toList();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (context, index) =>
              Divider(color: Theme.of(context).dividerColor),
          itemBuilder: (context, index) {
            final card = filtered[index];
            final String uuid = card['uuid'];
            final String displayName = card['displayName'] ?? '';
            final bool isDefaultOrNone =
                displayName.toLowerCase() == 'none' ||
                displayName.toLowerCase() == 'standard';
            final bool isOwned =
                isDefaultOrNone || ownedIds.contains(uuid.toLowerCase());

            return ListTile(
              title: Text(
                card['displayName'] ?? '',
                style: GoogleFonts.inter(
                  color: isOwned
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: SizedBox(
                width: 40,
                height: 80,
                child: CachedNetworkImage(
                  imageUrl: card['smallArt'] ?? card['displayIcon'] ?? '',
                  cacheManager: CustomCacheManagers.loadoutPresetCacheManager,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Icon(
                    Icons.broken_image,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              trailing: isOwned
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : Icon(
                      Icons.lock,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              onTap: isOwned ? () => _selectCard(uuid) : null,
            );
          },
        );
      },
    );
  }

  Widget _buildFlexList(Set<String> ownedIds) {
    final l10n = AppLocalizations.of(context)!;
    final flexesAsync = ref.watch(allFlexesProvider);
    return flexesAsync.when(
      loading: () => const Center(child: FunnyLoadingView()),
      error: (e, _) => Center(
        child: Text(
          l10n.errorMessage(e.toString()),
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (flexes) {
        final filtered = flexes.where((flex) {
          final nameMatches = (flex['displayName'] as String)
              .toLowerCase()
              .contains(searchQuery);
          if (!nameMatches) return false;

          if (selectedTabIndex == 1) {
            return _isDefaultFlex(flex) ||
                ownedIds.contains((flex['uuid'] as String).toLowerCase());
          }
          return true;
        }).toList();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (context, index) =>
              Divider(color: Theme.of(context).dividerColor),
          itemBuilder: (context, index) {
            final flex = filtered[index];
            final String uuid = flex['uuid'];
            final bool isOwned =
                _isDefaultFlex(flex) || ownedIds.contains(uuid.toLowerCase());

            return ListTile(
              title: Text(
                flex['displayName'] ?? '',
                style: GoogleFonts.inter(
                  color: isOwned
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: SizedBox(
                width: 50,
                height: 50,
                child: CachedNetworkImage(
                  imageUrl: flex['displayIcon'] ?? '',
                  cacheManager: CustomCacheManagers.loadoutPresetCacheManager,
                  fit: BoxFit.contain,
                  errorWidget: (context, url, error) => Icon(
                    Icons.broken_image,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              trailing: isOwned
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : Icon(
                      Icons.lock,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              onTap: isOwned ? () => _selectSpray(uuid) : null,
            );
          },
        );
      },
    );
  }

  Future<void> _selectSkin(
    String skinId,
    String skinLevelId,
    String chromaId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => isSaving = true);
    try {
      await ref
          .read(loadoutProvider.notifier)
          .equipSkin(widget.weaponId!, skinId, skinLevelId, chromaId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToEquipSkin(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _selectBuddy(
    String charmId,
    String charmLevelId,
    String charmInstanceId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => isSaving = true);
    try {
      await ref
          .read(loadoutProvider.notifier)
          .equipBuddy(widget.weaponId!, charmId, charmLevelId, charmInstanceId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToEquipBuddy(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _selectTitle(String titleId) async {
    if (widget.onSelected != null) {
      widget.onSelected!(titleId);
      Navigator.pop(context);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() => isSaving = true);
    try {
      await ref.read(loadoutProvider.notifier).equipTitle(titleId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToEquipTitle(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _selectSpray(String sprayId) async {
    if (widget.onSelected != null) {
      widget.onSelected!(sprayId);
      Navigator.pop(context);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() => isSaving = true);
    try {
      await ref
          .read(loadoutProvider.notifier)
          .equipSpray(widget.slotId!, sprayId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToEquipSpray(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _selectCard(String cardId) async {
    if (widget.onSelected != null) {
      widget.onSelected!(cardId);
      Navigator.pop(context);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() => isSaving = true);
    try {
      await ref.read(loadoutProvider.notifier).equipCard(cardId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToEquipCard(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }
}
