import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';
import 'package:valorant_thunai/providers/game_info_provider.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';

class AgentsScreen extends ConsumerWidget {
  const AgentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final agentsAsync = ref.watch(gameInfoAgentsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.gameInfoAgentsTitle)),
      body: agentsAsync.when(
        loading: () => const Center(child: FunnyLoadingView()),
        error: (err, st) => Center(child: Text(l10n.gameInfoLoadError)),
        data: (agents) {
          if (agents.isEmpty) {
            return Center(child: Text(l10n.gameInfoLoadError));
          }
          final sorted = [...agents]
            ..sort(
              (a, b) =>
                  (a['displayName'] ?? '').compareTo(b['displayName'] ?? ''),
            );
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.78,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: sorted.length,
            itemBuilder: (context, index) => _AgentCard(agent: sorted[index]),
          );
        },
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  final dynamic agent;
  const _AgentCard({required this.agent});

  @override
  Widget build(BuildContext context) {
    final String name = agent['displayName'] ?? '';
    final String? role = agent['role']?['displayName'];
    final String? portrait =
        agent['fullPortrait'] ?? agent['displayIcon'] ?? agent['bustPortrait'];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AgentDetailScreen(agent: agent)),
          );
        },
        child: Column(
          children: [
            Expanded(
              child: portrait != null
                  ? CachedNetworkImage(
                      imageUrl: portrait,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    )
                  : const Icon(Icons.person_outline, size: 48),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  if (role != null)
                    Text(
                      role,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AgentDetailScreen extends StatelessWidget {
  final dynamic agent;
  const AgentDetailScreen({super.key, required this.agent});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final String name = agent['displayName'] ?? '';
    final String? role = agent['role']?['displayName'];
    final String? roleIcon = agent['role']?['displayIcon'];
    final String? background = agent['background'] ?? agent['fullPortrait'];
    final String? bio = agent['description'];
    final List abilities = agent['abilities'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (background != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: background,
                fit: BoxFit.cover,
              ),
            ),
          if (role != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  if (roleIcon != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CachedNetworkImage(
                        imageUrl: roleIcon,
                        width: 24,
                        height: 24,
                      ),
                    ),
                  Text(
                    role,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          if (bio != null && bio.isNotEmpty)
            Padding(padding: const EdgeInsets.all(16), child: Text(bio)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.gameInfoAbilitiesHeader,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ...abilities.map((a) {
            final abilityName = a['displayName'] ?? '';
            final abilityDesc = a['description'] ?? '';
            final abilityIcon = a['displayIcon'];
            if (abilityName.isEmpty) return const SizedBox.shrink();
            return ListTile(
              leading: abilityIcon != null
                  ? CachedNetworkImage(
                      imageUrl: abilityIcon,
                      width: 36,
                      height: 36,
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              title: Text(abilityName),
              subtitle: Text(abilityDesc),
              isThreeLine: abilityDesc.length > 60,
            );
          }),
        ],
      ),
    );
  }
}
