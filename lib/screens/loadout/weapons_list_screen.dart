import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/utils/cache_managers.dart';
import 'package:valorant_thunai/utils/weapon_asset_resolver.dart';
import 'package:valorant_thunai/providers/loadout_provider.dart';
import 'package:valorant_thunai/providers/weapons_provider.dart';
import 'package:valorant_thunai/providers/skin_provider.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:valorant_thunai/screens/loadout/weapon_customize_screen.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class WeaponsListScreen extends ConsumerWidget {
  const WeaponsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final loadoutAsync = ref.watch(loadoutProvider);
    final weaponsAsync = ref.watch(weaponsProvider);
    final skinsAsync = ref.watch(skinsMetadataProvider);
    final buddiesAsync = ref.watch(buddiesProvider);

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
          l10n.weaponsTitle,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: loadoutAsync.when(
        loading: () => const Center(child: FunnyLoadingView()),
        error: (e, _) => Center(
          child: Text(
            l10n.errorMessage(e.toString()),
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (loadout) {
          return weaponsAsync.when(
            loading: () => const Center(child: FunnyLoadingView()),
            error: (e, _) => Center(
              child: Text(
                l10n.errorMessage(e.toString()),
                style: const TextStyle(color: Colors.red),
              ),
            ),
            data: (weapons) {
              return skinsAsync.when(
                loading: () => const Center(child: FunnyLoadingView()),
                error: (e, _) => Center(
                  child: Text(
                    l10n.errorMessage(e.toString()),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                data: (skins) {
                  return buddiesAsync.when(
                    loading: () => const Center(child: FunnyLoadingView()),
                    error: (e, _) => Center(
                      child: Text(
                        l10n.errorMessage(e.toString()),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    data: (buddies) {
                      final guns = weapons
                          .where(
                            (w) =>
                                w['uuid'] !=
                                '2f59173c-4bed-b6c3-2191-dea9b58be9c7',
                          )
                          .toList();

                      return ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: guns.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 24),
                        itemBuilder: (context, index) {
                          final weapon = guns[index];
                          final weaponId = weapon['uuid'];

                          final gunsLoadout =
                              loadout['Guns'] as List<dynamic>? ?? [];
                          final equippedGun = gunsLoadout.firstWhere(
                            (g) =>
                                (g['ID'] as String).toLowerCase() ==
                                weaponId.toLowerCase(),
                            orElse: () => null,
                          );

                          String? skinLevelId = equippedGun?['SkinLevelID'];
                          String? chromaId = equippedGun?['ChromaID'];
                          String? charmId = equippedGun?['CharmID'];

                          final skinImageUrl =
                              WeaponAssetResolver.resolveSkinImageUrl(
                                weapon: weapon,
                                skinLevelId: skinLevelId,
                                chromaId: chromaId,
                                skinsMap: skins,
                              );

                          final buddyImageUrl =
                              WeaponAssetResolver.resolveBuddyImageUrl(
                                charmId: charmId,
                                buddiesMap: buddies,
                              );

                          return Card(
                            elevation: 0,
                            color: Theme.of(context).cardColor,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: Theme.of(context).dividerColor,
                                width: 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => WeaponCustomizeScreen(
                                      weaponId: weaponId,
                                      weaponName: weapon['displayName'],
                                      currentSkinId: equippedGun?['SkinID'],
                                      currentSkinLevelId: skinLevelId,
                                      currentChromaId: equippedGun?['ChromaID'],
                                      currentCharmId: charmId,
                                      currentCharmLevelId:
                                          equippedGun?['CharmLevelID'],
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          weapon['displayName'] ?? '',
                                          style: GoogleFonts.inter(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 100,
                                      child: Row(
                                        children: [
                                          if (buddyImageUrl != null)
                                            SizedBox(
                                              width: 48,
                                              height: 48,
                                              child: CachedNetworkImage(
                                                imageUrl: buddyImageUrl,
                                                cacheManager: CustomCacheManagers
                                                    .loadoutPresetCacheManager,
                                                fit: BoxFit.contain,
                                              ),
                                            )
                                          else
                                            const SizedBox(width: 48),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Hero(
                                              tag: 'weapon_$weaponId',
                                              child: CachedNetworkImage(
                                                imageUrl: skinImageUrl,
                                                cacheManager: CustomCacheManagers
                                                    .loadoutPresetCacheManager,
                                                fit: BoxFit.contain,
                                                alignment:
                                                    Alignment.centerRight,
                                                errorWidget:
                                                    (
                                                      context,
                                                      url,
                                                      error,
                                                    ) => Icon(
                                                      Icons.broken_image,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
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
