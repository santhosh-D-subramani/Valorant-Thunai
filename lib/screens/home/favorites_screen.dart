import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:valorant_thunai/providers/display_settings_provider.dart';
import 'package:valorant_thunai/providers/skin_provider.dart';
import 'package:valorant_thunai/screens/media/skin_details_screen.dart';
import 'package:valorant_thunai/screens/accessories/accessory_inspector.dart';
import 'package:valorant_thunai/screens/bundles/bundle_detail_screen.dart';
import 'package:valorant_thunai/utils/format_utils.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final displaySettings = ref.watch(displaySettingsProvider);
    final favoritesMap = ref.watch(favoritesProvider);
    final activeFavorites =
        favoritesMap.values.where((e) => e.isFavorite).toList()
          ..sort((a, b) => b.originalDate.compareTo(a.originalDate));

    final skinsMap = ref.watch(skinsMetadataProvider).value ?? {};
    final buddiesMap = ref.watch(buddiesProvider).value ?? {};
    final spraysMap = ref.watch(spraysProvider).value ?? {};
    final cardsMap = ref.watch(playerCardsProvider).value ?? {};
    final bundlesMap = ref.watch(bundlesMetadataProvider).value ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.favoritesTitle,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (activeFavorites.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(l10n.clearAllFavoritesTitle),
                    content: Text(l10n.clearAllFavoritesContent),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () {
                          ref
                              .read(favoritesProvider.notifier)
                              .clearAllFavorites();
                          Navigator.pop(context);
                        },
                        child: Text(
                          l10n.deleteButton,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: activeFavorites.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite_border,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noFavoritesYet,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.8,
                        ),
                    itemCount: activeFavorites.length,
                    itemBuilder: (context, index) {
                      final favoriteItem = activeFavorites[index];
                      final itemId = favoriteItem.id;
                      String displayName = l10n.noName;
                      String displayIcon = '';
                      String itemType = 'Unknown';
                      dynamic resolvedItem;

                      if (skinsMap.containsKey(itemId)) {
                        final skin = skinsMap[itemId]!;
                        displayName = skin.displayName;
                        displayIcon = skin.displayIcon;
                        itemType = 'Skin';
                        resolvedItem = skin;
                      } else if (cardsMap.containsKey(itemId)) {
                        final card = cardsMap[itemId]!;
                        displayName = card['displayName'] ?? 'Card';
                        displayIcon =
                            card['wideArt'] ?? card['displayIcon'] ?? '';
                        itemType = 'Player Card';
                        resolvedItem = card;
                      } else if (buddiesMap.containsKey(itemId)) {
                        final buddy = buddiesMap[itemId]!;
                        displayName = buddy['displayName'] ?? 'Buddy';
                        displayIcon = buddy['displayIcon'] ?? '';
                        itemType = 'Gun Buddy';
                        resolvedItem = buddy;
                      } else if (bundlesMap.containsKey(itemId)) {
                        final bundle = bundlesMap[itemId]!;
                        displayName = bundle.displayName;
                        displayIcon = bundle.displayIcon;
                        itemType = 'Bundle';
                        resolvedItem = bundle;
                      } else if (spraysMap.containsKey(itemId)) {
                        final spray = spraysMap[itemId]!;
                        displayName = spray['displayName'] ?? 'Spray';
                        displayIcon =
                            spray['displayIcon'] ?? spray['fullIcon'] ?? '';
                        itemType = 'Spray';
                        resolvedItem = spray;
                      }

                      final cardBgColor = Theme.of(context).cardColor;

                      return GestureDetector(
                        onTap: itemType == 'Skin' && resolvedItem != null
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SkinDetailsScreen(skin: resolvedItem),
                                  ),
                                );
                              }
                            : (itemType == 'Player Card' && resolvedItem != null
                                  ? () => AccessoryInspector.showPlayerCard(
                                      context,
                                      resolvedItem,
                                    )
                                  : (itemType == 'Spray' && resolvedItem != null
                                        ? () => AccessoryInspector.showSpray(
                                            context,
                                            resolvedItem,
                                          )
                                        : (itemType == 'Bundle'
                                              ? () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        BundleDetailPage(
                                                          uuid: itemId,
                                                        ),
                                                  ),
                                                )
                                              : null))),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        itemType.toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.redAccent,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () => ref
                                          .read(favoritesProvider.notifier)
                                          .toggleFavorite(itemId),
                                      child: const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 22,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                if (displayIcon.isNotEmpty)
                                  Center(
                                    child: Image.network(
                                      displayIcon,
                                      height: 64,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                const Spacer(),
                                Text(
                                  displayName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.addedDatePrefix(
                                    FormatUtils.formatDate(
                                      favoriteItem.originalDate,
                                      displaySettings,
                                    ),
                                  ),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
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
    );
  }
}
