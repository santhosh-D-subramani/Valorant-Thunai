import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/providers/bundle_providers.dart';
import 'package:valorant_thunai/providers/display_settings_provider.dart';
import 'package:valorant_thunai/providers/loadout_provider.dart';
import 'package:valorant_thunai/providers/skin_provider.dart';
import 'package:valorant_thunai/screens/media/skin_details_screen.dart';
import 'package:valorant_thunai/screens/accessories/accessory_inspector.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/utils/cache_managers.dart';
import 'package:valorant_thunai/utils/format_utils.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class ResolvedBundleItem {
  final String name;
  final String imageUrl;
  final String type;
  final dynamic metadata;
  final int price;
  final int basePrice;
  final String itemId;

  ResolvedBundleItem({
    required this.name,
    required this.imageUrl,
    required this.type,
    required this.metadata,
    required this.price,
    required this.basePrice,
    this.itemId = '',
  });
}

const _kSkinEntitlementTypeIds =
    'e7c63390-eda7-46e0-bb7a-a6abdacd2433,3ad1b2b2-acdb-4524-852f-954a76ddae0a';

class BundleDetailPage extends ConsumerWidget {
  final String uuid;
  final Map<String, dynamic>? storefrontBundleData;

  const BundleDetailPage({
    super.key,
    required this.uuid,
    this.storefrontBundleData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final displaySettings = ref.watch(displaySettingsProvider);
    final bundleAsync = ref.watch(bundleDetailProvider(uuid));

    final skinsMap = ref.watch(skinsMetadataProvider).value ?? {};
    final cardsMap = ref.watch(playerCardsProvider).value ?? {};
    final buddiesMap = ref.watch(buddiesProvider).value ?? {};
    final spraysMap = ref.watch(spraysProvider).value ?? {};

    final colorScheme = Theme.of(context).colorScheme;
    final bundleTitle = bundleAsync.value?['displayName'] as String?;

    final isLoggedIn = ref.watch(authProvider).user != null;
    final skinEntitlementsAsync = ref.watch(
      entitlementsProvider(_kSkinEntitlementTypeIds),
    );
    final Set<String> ownedSkinUuids = (skinEntitlementsAsync.value ?? [])
        .map((e) => (e['ItemID'] ?? e['itemId'] ?? '').toString().toLowerCase())
        .toSet();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          bundleTitle != null && bundleTitle.isNotEmpty
              ? bundleTitle
              : l10n.bundleDetailsTitle,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: bundleAsync.when(
        loading: () => const Center(child: FunnyLoadingView()),
        error: (e, _) => Center(child: Text(l10n.errorMessage(e.toString()))),
        data: (bundle) {
          final image =
              bundle['verticalPromoImage'] ??
              bundle['displayIcon2'] ??
              bundle['displayIcon'] ??
              '';
          final bundleIcon =
              bundle['displayIcon'] ??
              bundle['displayIcon2'] ??
              bundle['verticalPromoImage'] ??
              '';

          final itemsList = storefrontBundleData != null
              ? storefrontBundleData!['Items'] as List? ?? []
              : [];

          final List<ResolvedBundleItem> resolvedItems = [];
          for (var bundleItem in itemsList) {
            final itemObj = bundleItem['Item'];
            if (itemObj == null) continue;
            final itemId = itemObj['ItemID'] as String? ?? '';
            final price = bundleItem['DiscountedPrice'] as int? ?? 0;
            final basePrice = bundleItem['BasePrice'] as int? ?? price;

            if (skinsMap.containsKey(itemId)) {
              final skin = skinsMap[itemId]!;
              resolvedItems.add(
                ResolvedBundleItem(
                  name: skin.displayName,
                  imageUrl: skin.displayIcon,
                  type: 'skin',
                  metadata: skin,
                  price: price,
                  basePrice: basePrice,
                  itemId: itemId.toLowerCase(),
                ),
              );
            } else if (cardsMap.containsKey(itemId)) {
              final card = cardsMap[itemId]!;
              resolvedItems.add(
                ResolvedBundleItem(
                  name: card['displayName'] ?? 'Player Card',
                  imageUrl: card['wideArt'] ?? card['displayIcon'] ?? '',
                  type: 'card',
                  metadata: card,
                  price: price,
                  basePrice: basePrice,
                ),
              );
            } else if (buddiesMap.containsKey(itemId)) {
              final buddy = buddiesMap[itemId]!;
              resolvedItems.add(
                ResolvedBundleItem(
                  name: buddy['displayName'] ?? 'Buddy',
                  imageUrl: buddy['displayIcon'] ?? '',
                  type: 'buddy',
                  metadata: buddy,
                  price: price,
                  basePrice: basePrice,
                ),
              );
            } else if (spraysMap.containsKey(itemId)) {
              final spray = spraysMap[itemId]!;
              resolvedItems.add(
                ResolvedBundleItem(
                  name: spray['displayName'] ?? 'Spray',
                  imageUrl: spray['displayIcon'] ?? spray['fullIcon'] ?? '',
                  type: 'spray',
                  metadata: spray,
                  price: price,
                  basePrice: basePrice,
                ),
              );
            }
          }

          final skinItems = resolvedItems
              .where((i) => i.type == 'skin')
              .toList();
          final ownedSkinCount = skinItems
              .where((i) => ownedSkinUuids.contains(i.itemId))
              .length;
          final showSkinCoverage = isLoggedIn && skinItems.isNotEmpty;

          int totalPrice = 0;
          if (storefrontBundleData != null) {
            final discountedCost = storefrontBundleData!['TotalDiscountedCost'];
            if (discountedCost is Map) {
              totalPrice =
                  discountedCost['85ad13f7-3d1b-1612-dae0-a682f310051c'] ??
                  discountedCost['85ad13f73d1b1612dae0a682f310051c'] ??
                  0;
              if (totalPrice == 0 && discountedCost.isNotEmpty) {
                final values = discountedCost.values.toList();
                if (values.isNotEmpty && values[0] is int) {
                  totalPrice = values[0];
                }
              }
            } else if (discountedCost is int) {
              totalPrice = discountedCost;
            }

            if (totalPrice == 0 &&
                storefrontBundleData!['TotalBaseCost'] is Map) {
              final baseCost = storefrontBundleData!['TotalBaseCost'];
              totalPrice =
                  baseCost['85ad13f7-3d1b-1612-dae0-a682f310051c'] ??
                  baseCost['85ad13f73d1b1612dae0a682f310051c'] ??
                  0;
            }
          }

          if (totalPrice == 0 && resolvedItems.isNotEmpty) {
            totalPrice = resolvedItems.fold<int>(
              0,
              (sum, item) => sum + item.price,
            );
          }

          final int totalIndividualPrice = resolvedItems.fold<int>(
            0,
            (sum, item) => sum + item.basePrice,
          );
          final int roiSavings = totalIndividualPrice - totalPrice;
          final double roiPercent = totalIndividualPrice > 0
              ? (roiSavings / totalIndividualPrice) * 100
              : 0;
          final bool showRoi =
              storefrontBundleData != null &&
              totalIndividualPrice > 0 &&
              totalPrice > 0;

          return Stack(
            children: [
              if (image.isNotEmpty)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: image,
                    cacheManager: CustomCacheManagers.bundleCacheManager,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),

              if (image.isNotEmpty)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colorScheme.surface.withValues(alpha: 0),
                          colorScheme.surface.withValues(alpha: 0.54),
                          colorScheme.surface,
                        ],
                        stops: const [0.0, 0.40, 0.85],
                      ),
                    ),
                  ),
                ),

              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 140),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (bundleIcon.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 72,
                                height: 72,
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                padding: const EdgeInsets.all(4),
                                child: CachedNetworkImage(
                                  imageUrl: bundleIcon,
                                  cacheManager:
                                      CustomCacheManagers.bundleCacheManager,
                                  fit: BoxFit.contain,
                                  errorWidget: (_, _, _) => Icon(
                                    Icons.inventory_2_outlined,
                                    color: colorScheme.primary,
                                    size: 30,
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: colorScheme.primary,
                                size: 30,
                              ),
                            ),
                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.fullBundleTitle,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    bundle['displayName'] != null &&
                                            bundle['displayName']
                                                .toString()
                                                .isNotEmpty
                                        ? bundle['displayName']
                                              .toString()
                                              .toUpperCase()
                                        : 'BUNDLE',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: colorScheme.primary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (totalPrice > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  FormatUtils.formatNumber(
                                    totalPrice,
                                    displaySettings,
                                  ),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                CachedNetworkImage(
                                  imageUrl: 'https://media.valorant-api.com/currencies/85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741/displayicon.png',
                                  cacheManager:
                                      CustomCacheManagers.bundleCacheManager,
                                  width: 14,
                                  height: 14,
                                  fit: BoxFit.contain,
                                  errorWidget: (_, _, _) =>
                                      const Icon(Icons.circle, size: 8),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    if (showRoi) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: roiSavings > 0
                              ? Colors.green.withValues(alpha: 0.12)
                              : colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: roiSavings > 0
                                ? Colors.green.withValues(alpha: 0.4)
                                : colorScheme.outlineVariant.withValues(
                                    alpha: 0.4,
                                  ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              roiSavings > 0
                                  ? Icons.trending_down
                                  : Icons.info_outline,
                              color: roiSavings > 0
                                  ? Colors.green
                                  : colorScheme.onSurfaceVariant,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                roiSavings > 0
                                    ? l10n.bundleRoiSavings(
                                        '$roiSavings',
                                        roiPercent.toStringAsFixed(0),
                                      )
                                    : l10n.bundleRoiNoSavings,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: roiSavings > 0
                                      ? Colors.green
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (bundle['description'] != null &&
                        bundle['description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        bundle['description'],
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],

                    if (bundle['promoDescription'] != null &&
                        bundle['promoDescription'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        bundle['promoDescription'],
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ],

                    if (showSkinCoverage) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 18,
                              color: colorScheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.bundleSkinCoverage(
                                  ownedSkinCount,
                                  skinItems.length,
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    Text(
                      l10n.bundleItemsTitle,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (resolvedItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n.bundleItemsFeaturedInfo,
                                style: GoogleFonts.inter(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: resolvedItems.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = resolvedItems[index];

                          return InkWell(
                            onTap: item.type == 'skin'
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SkinDetailsScreen(
                                          skin: item.metadata,
                                        ),
                                      ),
                                    );
                                  }
                                : (item.type == 'card' && item.metadata != null
                                      ? () => AccessoryInspector.showPlayerCard(
                                          context,
                                          item.metadata,
                                        )
                                      : (item.type == 'spray' &&
                                                item.metadata != null
                                            ? () =>
                                                  AccessoryInspector.showSpray(
                                                    context,
                                                    item.metadata,
                                                  )
                                            : null)),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.outlineVariant.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (item.imageUrl.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        width: 72,
                                        height: 72,
                                        color: colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.5),
                                        padding: const EdgeInsets.all(4),
                                        child: CachedNetworkImage(
                                          imageUrl: item.imageUrl,
                                          cacheManager: CustomCacheManagers
                                              .bundleCacheManager,
                                          fit: BoxFit.contain,
                                          errorWidget: (_, _, _) =>
                                              const Icon(Icons.image, size: 30),
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.image, size: 30),
                                    ),
                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorScheme.error.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            item.type.toUpperCase(),
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: colorScheme.error,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            item.price > 0
                                                ? FormatUtils.formatNumber(
                                                    item.price,
                                                    displaySettings,
                                                  )
                                                : l10n.freePriceLabel,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          CachedNetworkImage(
                                            imageUrl: 'https://media.valorant-api.com/currencies/85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741/displayicon.png',
                                            cacheManager: CustomCacheManagers
                                                .bundleCacheManager,
                                            width: 14,
                                            height: 14,
                                            fit: BoxFit.contain,
                                            errorWidget: (_, _, _) =>
                                                const Icon(
                                                  Icons.circle,
                                                  size: 8,
                                                ),
                                          ),
                                        ],
                                      ),
                                      if (item.type == 'skin') ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(
                                              l10n.watchVideoLabel,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: colorScheme.error,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            Icon(
                                              Icons.play_circle_outline,
                                              color: colorScheme.error,
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

typedef BundleDetailScreen = BundleDetailPage;
