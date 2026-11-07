import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';
import 'package:valorant_thunai/providers/game_info_provider.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';

class MapsScreen extends ConsumerWidget {
  const MapsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mapsAsync = ref.watch(gameInfoMapsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.gameInfoMapsTitle)),
      body: mapsAsync.when(
        loading: () => const Center(child: FunnyLoadingView()),
        error: (err, st) => Center(child: Text(l10n.gameInfoLoadError)),
        data: (maps) {
          if (maps.isEmpty) {
            return Center(child: Text(l10n.gameInfoLoadError));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: maps.length,
            itemBuilder: (context, index) => _MapCard(map: maps[index]),
          );
        },
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  final dynamic map;
  const _MapCard({required this.map});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final String name = map['displayName'] ?? '';
    final String? splash = map['splash'] ?? map['listViewIcon'];
    final String? minimap = map['displayIcon'];
    final List callouts = map['callouts'] as List? ?? [];
    final coordinates = map['coordinates'] as String?;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => _MapDetailScreen(map: map)));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (splash != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: splash,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: const Icon(Icons.map_outlined, size: 40),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (minimap != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: CachedNetworkImage(
                        imageUrl: minimap,
                        width: 40,
                        height: 40,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          l10n.gameInfoCalloutCount(callouts.length),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (coordinates != null)
                          Text(
                            coordinates,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapDetailScreen extends StatelessWidget {
  final dynamic map;
  const _MapDetailScreen({required this.map});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final String name = map['displayName'] ?? '';
    final String? splash = map['splash'];
    final String? minimap = map['displayIcon'];
    final List callouts = map['callouts'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListView(
        children: [
          if (splash != null)
            CachedNetworkImage(imageUrl: splash, fit: BoxFit.cover),
          if (minimap != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: minimap,
                  width: 280,
                  height: 280,
                ),
              ),
            ),
          if (callouts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.gameInfoCalloutsHeader,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ...callouts.map((c) {
            final regionName = c['regionName'] ?? '';
            final superRegionName = c['superRegionName'] ?? '';
            return ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(regionName),
              subtitle: superRegionName.isNotEmpty
                  ? Text(superRegionName)
                  : null,
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
