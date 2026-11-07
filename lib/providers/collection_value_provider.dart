import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/providers/loadout_provider.dart';
import 'package:valorant_thunai/providers/skin_provider.dart';

const List<String> kSkinEntitlementItemTypeIds = [
  'e7c63390-eda7-46e0-bb7a-a6abdacd2433',
  '3ad1b2b2-acdb-4524-852f-954a76ddae0a',
];

final String skinEntitlementFamilyKey = kSkinEntitlementItemTypeIds.join(',');

const Map<String, int> kContentTierVpPrice = {
  '12683d76-48d7-84a3-4e09-6985794f0445': 875,
  '0cebb8be-46d7-c12a-d306-e9907bfc5a25': 1275,
  '60bca009-4182-7998-dee7-b8a2558dc369': 1775,
  '411e4a55-4e59-7757-41f0-86a53f101bb5': 2175,
  'e046854e-406c-37f4-6607-19a9ba8426fc': 2475,
};

const Map<String, String> kContentTierFallbackNames = {
  '12683d76-48d7-84a3-4e09-6985794f0445': 'Select',
  '0cebb8be-46d7-c12a-d306-e9907bfc5a25': 'Deluxe',
  '60bca009-4182-7998-dee7-b8a2558dc369': 'Premium',
  '411e4a55-4e59-7757-41f0-86a53f101bb5': 'Ultra',
  'e046854e-406c-37f4-6607-19a9ba8426fc': 'Exclusive',
};

const Map<String, String> kContentTierFallbackColors = {
  '12683d76-48d7-84a3-4e09-6985794f0445': '5a9fe233',
  '0cebb8be-46d7-c12a-d306-e9907bfc5a25': '00958733',
  '60bca009-4182-7998-dee7-b8a2558dc369': 'd1548d33',
  '411e4a55-4e59-7757-41f0-86a53f101bb5': 'fad66333',
  'e046854e-406c-37f4-6607-19a9ba8426fc': 'f5955b33',
};

class CollectionRarityBreakdown {
  final String tierUuid;
  final String tierName;
  final String color;
  final String displayIcon;
  final int ownedCount;
  final int unitPriceVp;
  final int totalValueVp;

  const CollectionRarityBreakdown({
    required this.tierUuid,
    required this.tierName,
    required this.color,
    required this.displayIcon,
    required this.ownedCount,
    required this.unitPriceVp,
    required this.totalValueVp,
  });
}

class CollectionValue {
  final int totalValueVp;
  final int totalSkinsOwned;
  final List<CollectionRarityBreakdown> breakdown;

  const CollectionValue({
    required this.totalValueVp,
    required this.totalSkinsOwned,
    required this.breakdown,
  });

  static const empty = CollectionValue(
    totalValueVp: 0,
    totalSkinsOwned: 0,
    breakdown: [],
  );
}

final collectionValueProvider = FutureProvider<CollectionValue>((ref) async {
  final skinEntitlements = await ref.watch(
    entitlementsProvider(skinEntitlementFamilyKey).future,
  );
  final skinsMeta = await ref.watch(skinsMetadataProvider.future);
  final tiers = await ref.watch(contentTiersProvider.future);

  final Map<String, SkinMetadata> ownedSkinsByName = {};
  for (final ent in skinEntitlements) {
    if (ent is! Map) continue;
    final itemId = (ent['ItemID'] ?? ent['itemId'] ?? '')
        .toString()
        .toLowerCase();
    if (itemId.isEmpty) continue;
    final meta = skinsMeta[itemId];
    if (meta == null || meta.displayName.isEmpty) continue;
    ownedSkinsByName[meta.displayName] = meta;
  }

  final Map<String, int> countByTier = {};
  for (final meta in ownedSkinsByName.values) {
    final tierUuid = meta.contentTierUuid;
    if (tierUuid == null) continue;
    countByTier[tierUuid] = (countByTier[tierUuid] ?? 0) + 1;
  }

  final List<CollectionRarityBreakdown> breakdown = [];
  int totalValue = 0;
  for (final entry in kContentTierVpPrice.entries) {
    final tierUuid = entry.key;
    final unitPrice = entry.value;
    final count = countByTier[tierUuid] ?? 0;
    final value = count * unitPrice;
    totalValue += value;

    final tierMeta = tiers[tierUuid];
    breakdown.add(
      CollectionRarityBreakdown(
        tierUuid: tierUuid,
        tierName: (tierMeta?.displayName.isNotEmpty ?? false)
            ? tierMeta!.displayName
            : (kContentTierFallbackNames[tierUuid] ?? tierUuid),
        color: (tierMeta?.color.isNotEmpty ?? false)
            ? tierMeta!.color
            : (kContentTierFallbackColors[tierUuid] ?? 'FFFFFFFF'),
        displayIcon: tierMeta?.displayIcon ?? '',
        ownedCount: count,
        unitPriceVp: unitPrice,
        totalValueVp: value,
      ),
    );
  }

  return CollectionValue(
    totalValueVp: totalValue,
    totalSkinsOwned: ownedSkinsByName.length,
    breakdown: breakdown,
  );
});
