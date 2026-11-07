import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';
import 'package:valorant_thunai/providers/game_info_provider.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:valorant_thunai/screens/hub/game_info/weapon_detail_screen.dart';

class WeaponsScreen extends ConsumerWidget {
  const WeaponsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final groupedAsync = ref.watch(gameInfoWeaponsByCategoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.gameInfoWeaponsTitle)),
      body: groupedAsync.when(
        loading: () => const Center(child: FunnyLoadingView()),
        error: (err, st) => Center(child: Text(l10n.gameInfoLoadError)),
        data: (grouped) {
          if (grouped.isEmpty) {
            return Center(child: Text(l10n.gameInfoLoadError));
          }
          final categories = grouped.keys.toList()..sort();
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final weapons = grouped[category]!;
              return _CategorySection(category: category, weapons: weapons);
            },
          );
        },
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String category;
  final List<dynamic> weapons;
  const _CategorySection({required this.category, required this.weapons});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            category,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        ...weapons.map((weapon) => _WeaponTile(weapon: weapon)),
      ],
    );
  }
}

class _WeaponTile extends StatelessWidget {
  final dynamic weapon;
  const _WeaponTile({required this.weapon});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final String name = weapon['displayName'] ?? '';
    final String? icon =
        weapon['displayIcon'] ?? weapon['shopData']?['displayIcon'];
    final int cost = (weapon['shopData']?['cost'] ?? 0) as int;
    final int skinCount = (weapon['skins'] as List? ?? []).length;

    return ListTile(
      leading: SizedBox(
        width: 56,
        height: 40,
        child: icon != null
            ? CachedNetworkImage(imageUrl: icon, fit: BoxFit.contain)
            : const Icon(Icons.gavel_outlined),
      ),
      title: Text(name),
      subtitle: Text(
        cost > 0
            ? l10n.gameInfoWeaponPriceSkins(cost, skinCount)
            : l10n.gameInfoWeaponSkinsOnly(skinCount),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => WeaponDetailScreen(weapon: weapon)),
        );
      },
    );
  }
}
