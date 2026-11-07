import 'package:flutter/material.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';
import 'package:valorant_thunai/screens/hub/game_info/maps_screen.dart';
import 'package:valorant_thunai/screens/hub/game_info/agents_screen.dart';
import 'package:valorant_thunai/screens/hub/game_info/weapons_screen.dart';

class GameInfoHubScreen extends StatelessWidget {
  const GameInfoHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tiles = <_HubTile>[
      _HubTile(
        icon: Icons.map_outlined,
        title: l10n.gameInfoMapsTitle,
        subtitle: l10n.gameInfoMapsSubtitle,
        color: Colors.tealAccent,
        builder: (_) => const MapsScreen(),
      ),
      _HubTile(
        icon: Icons.groups_outlined,
        title: l10n.gameInfoAgentsTitle,
        subtitle: l10n.gameInfoAgentsSubtitle,
        color: Colors.deepPurpleAccent,
        builder: (_) => const AgentsScreen(),
      ),
      _HubTile(
        icon: Icons.gavel_outlined,
        title: l10n.gameInfoWeaponsTitle,
        subtitle: l10n.gameInfoWeaponsSubtitle,
        color: Colors.orangeAccent,
        builder: (_) => const WeaponsScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.gameInfoHubTitle)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: tiles.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final tile = tiles[index];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: tile.color.withValues(alpha: 0.2),
                foregroundColor: tile.color,
                child: Icon(tile.icon),
              ),
              title: Text(
                tile.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(tile.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: tile.builder));
              },
            ),
          );
        },
      ),
    );
  }
}

class _HubTile {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final WidgetBuilder builder;

  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.builder,
  });
}
