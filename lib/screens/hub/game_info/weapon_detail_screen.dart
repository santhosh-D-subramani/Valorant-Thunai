import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class WeaponDetailScreen extends StatelessWidget {
  final dynamic weapon;
  const WeaponDetailScreen({super.key, required this.weapon});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final String name = weapon['displayName'] ?? '';
    final String? icon =
        weapon['displayIcon'] ?? weapon['shopData']?['displayIcon'];
    final Map<String, dynamic>? shopData =
        weapon['shopData'] as Map<String, dynamic>?;
    final Map<String, dynamic>? stats =
        weapon['weaponStats'] as Map<String, dynamic>?;
    final List skins = weapon['skins'] as List? ?? [];
    final int cost = (shopData?['cost'] ?? 0) as int;
    final String category = shopData?['categoryText'] ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (icon != null)
            Center(
              child: SizedBox(
                height: 140,
                child: CachedNetworkImage(imageUrl: icon, fit: BoxFit.contain),
              ),
            ),
          const SizedBox(height: 16),
          _SummaryRow(
            category: category,
            cost: cost,
            skinCount: skins.length,
            l10n: l10n,
          ),
          const SizedBox(height: 20),
          if (stats != null) ...[
            Text(
              l10n.gameInfoStatSheetHeader,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _StatSheet(stats: stats, l10n: l10n),
          ] else
            Text(l10n.gameInfoNoStatsAvailable),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String category;
  final int cost;
  final int skinCount;
  final AppLocalizations l10n;
  const _SummaryRow({
    required this.category,
    required this.cost,
    required this.skinCount,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (category.isNotEmpty)
          Chip(
            avatar: const Icon(Icons.category_outlined, size: 18),
            label: Text(category),
          ),
        if (cost > 0)
          Chip(
            avatar: const Icon(Icons.paid_outlined, size: 18),
            label: Text(l10n.gameInfoVpPrice(cost)),
          ),
        Chip(
          avatar: const Icon(Icons.palette_outlined, size: 18),
          label: Text(l10n.gameInfoSkinCount(skinCount)),
        ),
      ],
    );
  }
}

class _StatSheet extends StatelessWidget {
  final Map<String, dynamic> stats;
  final AppLocalizations l10n;
  const _StatSheet({required this.stats, required this.l10n});

  String _fmt(num? v, {int decimals = 2}) =>
      v == null ? '-' : v.toStringAsFixed(decimals);

  @override
  Widget build(BuildContext context) {
    final fireRate = stats['fireRate'] as num?;
    final magSize = stats['magazineSize'] as num?;
    final runSpeed = stats['runSpeedMultiplier'] as num?;
    final equipTime = stats['equipTimeSeconds'] as num?;
    final reloadTime = stats['reloadTimeSeconds'] as num?;
    final firstBulletAccuracy = stats['firstBulletAccuracy'] as num?;
    final wallPenetration = stats['wallPenetration'] as String?;
    final adsStats = stats['adsStats'] as Map<String, dynamic>?;
    final adsRunSpeed = adsStats?['runSpeedMultiplier'] as num?;
    final damageRanges = stats['damageRanges'] as List? ?? [];

    final rows = <(String, String)>[
      (
        l10n.gameInfoStatFireRate,
        fireRate != null ? '${_fmt(fireRate)} /s' : '-',
      ),
      (
        l10n.gameInfoStatMagazineSize,
        magSize != null ? magSize.toString() : '-',
      ),
      (
        l10n.gameInfoStatEquipTime,
        equipTime != null ? '${_fmt(equipTime)} s' : '-',
      ),
      (
        l10n.gameInfoStatReloadTime,
        reloadTime != null ? '${_fmt(reloadTime)} s' : '-',
      ),
      (
        l10n.gameInfoStatFirstShotAccuracy,
        firstBulletAccuracy != null ? _fmt(firstBulletAccuracy) : '-',
      ),
      (
        l10n.gameInfoStatRunSpeed,
        runSpeed != null ? '${_fmt(runSpeed)}x' : '-',
      ),
      (
        l10n.gameInfoStatWalkSpeed,
        adsRunSpeed != null ? '${_fmt(adsRunSpeed)}x' : '-',
      ),
      if (wallPenetration != null)
        (l10n.gameInfoStatWallPenetration, wallPenetration),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: rows
                  .map(
                    (r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(r.$1),
                          Text(
                            r.$2,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        if (damageRanges.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.gameInfoDamageRangesHeader,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _DamageRangeTable(damageRanges: damageRanges, l10n: l10n),
        ],
      ],
    );
  }
}

class _DamageRangeTable extends StatelessWidget {
  final List damageRanges;
  final AppLocalizations l10n;
  const _DamageRangeTable({required this.damageRanges, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(l10n.gameInfoStatRange)),
          DataColumn(label: Text(l10n.gameInfoStatHeadDamage)),
          DataColumn(label: Text(l10n.gameInfoStatBodyDamage)),
          DataColumn(label: Text(l10n.gameInfoStatLegDamage)),
        ],
        rows: damageRanges.map((range) {
          final start = (range['rangeStartMeters'] as num?) ?? 0;
          final end = (range['rangeEndMeters'] as num?) ?? 0;
          final head = range['headDamage'] as num?;
          final body = range['bodyDamage'] as num?;
          final leg = range['legDamage'] as num?;
          return DataRow(
            cells: [
              DataCell(Text('${start.toInt()}-${end.toInt()}m')),
              DataCell(Text(head?.toStringAsFixed(0) ?? '-')),
              DataCell(Text(body?.toStringAsFixed(0) ?? '-')),
              DataCell(Text(leg?.toStringAsFixed(0) ?? '-')),
            ],
          );
        }).toList(),
      ),
    );
  }
}
