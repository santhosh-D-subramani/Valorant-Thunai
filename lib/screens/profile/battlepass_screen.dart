import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:valorant_thunai/providers/battlepass_provider.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class BattlepassScreen extends ConsumerWidget {
  const BattlepassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dataAsync = ref.watch(battlepassProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.battlepassScreenTitle)),
      body: SafeArea(
        child: dataAsync.when(
          data: (data) {
            if (data == null || data.tiers.isEmpty) {
              return Center(
                child: Text(
                  l10n.battlepassNoDataAvailable,
                  style: GoogleFonts.inter(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }

            final List<List<BattlepassTier>> chapterGroups = [];
            String? lastChapterKey;
            for (final tier in data.tiers) {
              final key = '${tier.chapterName}-${tier.isEpilogue}';
              if (lastChapterKey != key || chapterGroups.isEmpty) {
                chapterGroups.add([]);
                lastChapterKey = key;
              }
              chapterGroups.last.add(tier);
            }

            int chapterNumber = 0;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: chapterGroups.length,
              itemBuilder: (context, chapterIndex) {
                final group = chapterGroups[chapterIndex];
                final isEpilogue = group.first.isEpilogue;
                if (!isEpilogue) chapterNumber++;
                final chapterLabel = isEpilogue
                    ? l10n.battlepassEpilogueLabel
                    : l10n.battlepassChapterLabel(chapterNumber);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Text(
                        chapterLabel,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...group.map(
                      (tier) =>
                          _TierCard(tier: tier, hasPremium: data.hasPremium),
                    ),
                  ],
                );
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
                    err.toString(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: theme.colorScheme.error,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => ref.invalidate(battlepassProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
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

class _TierCard extends StatelessWidget {
  final BattlepassTier tier;
  final bool hasPremium;

  const _TierCard({required this.tier, required this.hasPremium});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: tier.isUnlocked
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      color: isDark
          ? theme.colorScheme.surfaceContainerHigh
          : theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Text(
                    '${tier.tierNumber}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Icon(
                    tier.isUnlocked ? Icons.lock_open : Icons.lock_outline,
                    size: 16,
                    color: tier.isUnlocked
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RewardTile(
                label: l10n.battlepassFreeTrack,
                reward: tier.freeReward,
                unlocked: tier.isUnlocked,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RewardTile(
                label: l10n.battlepassPremiumTrack,
                reward: tier.premiumReward,
                unlocked: tier.isUnlocked && hasPremium,
                lockedByPremium: tier.premiumReward != null && !hasPremium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  final String label;
  final BattlepassReward? reward;
  final bool unlocked;
  final bool lockedByPremium;

  const _RewardTile({
    required this.label,
    required this.reward,
    required this.unlocked,
    this.lockedByPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (reward == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '—',
            style: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }

    return Opacity(
      opacity: unlocked ? 1.0 : 0.45,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 32,
                  height: 32,
                  color: theme.colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.all(2),
                  child: reward!.icon.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: reward!.icon,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const SizedBox(
                            width: 12,
                            height: 12,
                            child: FunnyLoadingView(strokeWidth: 2),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.image_not_supported,
                            size: 16,
                            color: Colors.grey,
                          ),
                        )
                      : const Icon(
                          Icons.emoji_events,
                          size: 16,
                          color: Colors.grey,
                        ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reward!.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11),
                ),
              ),
            ],
          ),
          if (lockedByPremium) ...[
            const SizedBox(height: 2),
            Text(
              l10n.battlepassPremiumLocked,
              style: GoogleFonts.inter(
                fontSize: 9,
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
