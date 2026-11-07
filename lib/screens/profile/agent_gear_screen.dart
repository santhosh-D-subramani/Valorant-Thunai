import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:valorant_thunai/providers/agent_gear_provider.dart';
import 'package:valorant_thunai/providers/display_settings_provider.dart';
import 'package:valorant_thunai/utils/format_utils.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class AgentGearScreen extends ConsumerWidget {
  const AgentGearScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final agentGearAsync = ref.watch(agentGearProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.agentGearTitle),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(agentGearProvider),
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refreshDataTooltip,
          ),
        ],
      ),
      body: SafeArea(
        child: agentGearAsync.when(
          data: (agents) {
            if (agents.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.hourglass_empty_rounded,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.progressionDataNotAvailable,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: agents.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final agent = agents[index];
                return _AgentGearCard(agent: agent);
              },
            );
          },
          loading: () => const Center(child: FunnyLoadingView()),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.errorLoadingContracts(err.toString()),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: theme.colorScheme.error,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => ref.invalidate(agentGearProvider),
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.refreshDataTooltip),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AgentGearCard extends ConsumerWidget {
  final AgentGearProgress agent;

  const _AgentGearCard({required this.agent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final displaySettings = ref.watch(displaySettingsProvider);
    final progress = agent.totalTiers > 0
        ? agent.completedTiers / agent.totalTiers
        : 0.0;

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AgentGearDetailScreen(agent: agent),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 56,
                  height: 56,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: agent.agentIcon.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: agent.agentIcon,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: FunnyLoadingView(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.person, color: Colors.grey),
                        )
                      : const Icon(Icons.person, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.agentName,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(
                          agent.isMaxed
                              ? Colors.green
                              : theme.colorScheme.primary,
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.agentGearTiersFormat(
                            agent.completedTiers,
                            agent.totalTiers,
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (agent.isMaxed)
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.agentGearMaxed,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Icon(
                                Icons.toll,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.agentGearKcRemaining(
                                  FormatUtils.formatNumber(
                                    agent.kingdomCreditsRemaining,
                                    displaySettings,
                                  ),
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AgentGearDetailScreen extends ConsumerWidget {
  final AgentGearProgress agent;

  const AgentGearDetailScreen({super.key, required this.agent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final displaySettings = ref.watch(displaySettingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(agent.contractDisplayName)),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: agent.rewards.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final reward = agent.rewards[index];
            return Card(
              color: theme.colorScheme.surfaceContainerLow,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 48,
                        height: 48,
                        color: theme.colorScheme.surfaceContainerHighest,
                        padding: const EdgeInsets.all(4),
                        child: reward.icon.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: reward.icon,
                                fit: BoxFit.contain,
                                placeholder: (context, url) => const Center(
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: FunnyLoadingView(strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey,
                                    ),
                              )
                            : const Icon(
                                Icons.card_giftcard,
                                color: Colors.grey,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.agentGearTierFormat(reward.tier),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            reward.name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!reward.isComplete &&
                              reward.kingdomCreditsCost > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.toll,
                                  size: 12,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  FormatUtils.formatNumber(
                                    reward.kingdomCreditsCost,
                                    displaySettings,
                                  ),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (reward.isComplete)
                      const Icon(Icons.check_circle, color: Colors.green)
                    else
                      Icon(
                        Icons.lock_outline,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
