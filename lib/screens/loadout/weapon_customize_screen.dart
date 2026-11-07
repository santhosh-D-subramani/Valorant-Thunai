import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/utils/cache_managers.dart';
import 'package:valorant_thunai/utils/weapon_asset_resolver.dart';
import 'package:valorant_thunai/providers/skin_provider.dart';
import 'package:valorant_thunai/providers/weapons_provider.dart';
import 'package:valorant_thunai/providers/loadout_provider.dart';
import 'package:valorant_thunai/screens/loadout/item_selection_screen.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class WeaponCustomizeScreen extends ConsumerWidget {
  final String weaponId;
  final String weaponName;
  final String? currentSkinId;
  final String? currentSkinLevelId;
  final String? currentChromaId;
  final String? currentCharmId;
  final String? currentCharmLevelId;

  const WeaponCustomizeScreen({
    super.key,
    required this.weaponId,
    required this.weaponName,
    this.currentSkinId,
    this.currentSkinLevelId,
    this.currentChromaId,
    this.currentCharmId,
    this.currentCharmLevelId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final skinsAsync = ref.watch(skinsMetadataProvider);
    final buddiesAsync = ref.watch(buddiesProvider);
    final weaponsAsync = ref.watch(weaponsProvider);
    final loadoutAsync = ref.watch(loadoutProvider);

    String? activeSkinId = currentSkinId;
    String? activeSkinLevelId = currentSkinLevelId;
    String? activeChromaId = currentChromaId;
    String? activeCharmId = currentCharmId;

    loadoutAsync.whenData((loadout) {
      final gunsLoadout = loadout['Guns'] as List<dynamic>? ?? [];
      final equippedGun = gunsLoadout.firstWhere(
        (g) => (g['ID'] as String).toLowerCase() == weaponId.toLowerCase(),
        orElse: () => null,
      );
      if (equippedGun != null) {
        activeSkinId = equippedGun['SkinID'];
        activeSkinLevelId = equippedGun['SkinLevelID'];
        activeChromaId = equippedGun['ChromaID'];
        activeCharmId = equippedGun['CharmID'];
      }
    });

    String displaySkinName = l10n.standardWeaponSkin(weaponName);
    if (activeSkinLevelId != null && skinsAsync.value != null) {
      final skinsMap = skinsAsync.value!;
      if (skinsMap.containsKey(activeSkinLevelId)) {
        displaySkinName = skinsMap[activeSkinLevelId]!.displayName;
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.customizeWeaponTitle(weaponName),
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              displaySkinName,
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  skinsAsync.maybeWhen(
                    data: (skins) {
                      final fallbackWeapon = weaponsAsync.value?.firstWhere(
                        (w) =>
                            (w['uuid'] as String).toLowerCase() ==
                            weaponId.toLowerCase(),
                        orElse: () => null,
                      );

                      final imageUrl = WeaponAssetResolver.resolveSkinImageUrl(
                        weapon: fallbackWeapon,
                        skinId: activeSkinId,
                        skinLevelId: activeSkinLevelId,
                        chromaId: activeChromaId,
                        skinsMap: skins,
                      );

                      List<SkinChroma> chromas = [];
                      SkinMetadata? skinMeta;
                      if (activeSkinLevelId != null &&
                          skins.containsKey(activeSkinLevelId)) {
                        skinMeta = skins[activeSkinLevelId];
                      } else if (activeSkinId != null &&
                          skins.containsKey(activeSkinId)) {
                        skinMeta = skins[activeSkinId];
                      }
                      if (skinMeta != null) {
                        chromas = skinMeta.chromas;
                      }

                      return Column(
                        children: [
                          Container(
                            height: 200,
                            padding: const EdgeInsets.all(24),
                            child: Hero(
                              tag: 'weapon_$weaponId',
                              child: imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      cacheManager: CustomCacheManagers
                                          .loadoutPresetCacheManager,
                                      fit: BoxFit.contain,
                                    )
                                  : Icon(
                                      Icons.image,
                                      size: 64,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                            ),
                          ),
                          if (chromas.length > 1) ...[
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: chromas.map((chroma) {
                                  final isSelected =
                                      chroma.uuid == activeChromaId;
                                  return GestureDetector(
                                    onTap: () {
                                      if (!isSelected &&
                                          activeSkinId != null &&
                                          activeSkinLevelId != null) {
                                        ref
                                            .read(loadoutProvider.notifier)
                                            .equipSkin(
                                              weaponId,
                                              activeSkinId!,
                                              activeSkinLevelId!,
                                              chroma.uuid,
                                            );
                                      }
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 12),
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[800],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child:
                                            chroma.swatch != null &&
                                                chroma.swatch!.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: chroma.swatch!,
                                                cacheManager: CustomCacheManagers
                                                    .loadoutPresetCacheManager,
                                                fit: BoxFit.cover,
                                              )
                                            : Icon(
                                                Icons.palette,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                                size: 20,
                                              ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      );
                    },
                    orElse: () => Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const Divider(color: Colors.grey, height: 1),
                  _buildOptionRow(
                    context: context,
                    title: l10n.changeSkinOption,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ItemSelectionScreen(
                            weaponId: weaponId,
                            itemType: 'skin',
                            title: l10n.chooseSkinTitle,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.gunBuddyTitle,
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    height: 120,
                    padding: const EdgeInsets.all(16),
                    child: buddiesAsync.maybeWhen(
                      data: (buddies) {
                        String imageUrl = '';
                        String buddyName = l10n.noBuddyText;
                        if (activeCharmId != null &&
                            activeCharmId!.isNotEmpty) {
                          final buddy = buddies[activeCharmId];
                          if (buddy != null) {
                            imageUrl = buddy['displayIcon'] ?? '';
                            buddyName =
                                buddy['displayName'] ?? l10n.gunBuddyTitle;
                          }
                        }

                        return Column(
                          children: [
                            if (imageUrl.isNotEmpty)
                              Expanded(
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  cacheManager: CustomCacheManagers
                                      .loadoutPresetCacheManager,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            if (imageUrl.isEmpty)
                              Expanded(
                                child: Icon(
                                  Icons.sentiment_dissatisfied,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  size: 32,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              buddyName,
                              style: GoogleFonts.inter(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      },
                      orElse: () => Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const Divider(color: Colors.grey, height: 1),
                  _buildOptionRow(
                    context: context,
                    title: l10n.changeBuddyOption,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ItemSelectionScreen(
                            weaponId: weaponId,
                            itemType: 'buddy',
                            title: l10n.chooseBuddyTitle,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRow({
    required String title,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return ListTile(
      onTap: onTap,
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
