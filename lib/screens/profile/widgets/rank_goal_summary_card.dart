import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/providers/profile_provider.dart';
import 'package:valorant_thunai/providers/rank_goal_provider.dart';
import 'package:valorant_thunai/screens/profile/rank_goal_screen.dart';
import 'package:valorant_thunai/screens/profile/widgets/rank_history_card.dart';
import 'package:valorant_thunai/utils/rank_goal_estimator.dart';
import 'package:valorant_thunai/theme/app_theme.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class RankGoalSummaryCard extends ConsumerWidget {
  const RankGoalSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final puuid = ref.watch(authProvider).user?.puuid;
    final goalAsync = ref.watch(rankGoalProvider);
    final profileAsync = ref.watch(profileProvider);

    final goal = goalAsync.value;
    final profileData = profileAsync.value;
    if (puuid == null || goal == null || profileData == null) {
      return const SizedBox.shrink();
    }

    final historyAsync = ref.watch(rankHistoryProvider(puuid));
    final history = historyAsync.value ?? const [];

    final currentTierId = profileData.currentTier;
    final currentRR = profileData.currentRR;
    final targetTierName =
        profileData.competitiveTiers[goal.targetTierId]?['tierName'] ??
        l10n.unknownItem;

    final estimate = computeRankGoalEstimate(
      history: history,
      targetTierId: goal.targetTierId,
      currentTierId: currentTierId,
      currentRR: currentRR,
    );

    final remainingRR = ((goal.targetTierId - currentTierId) * 100) - currentRR;

    String progressLine;
    Color progressColor = theme.colorScheme.primary;
    switch (estimate.status) {
      case RankGoalTrendStatus.goalReached:
        progressLine = l10n.goalAchieved;
        progressColor = Colors.green;
        break;
      case RankGoalTrendStatus.notEnoughData:
        progressLine = l10n.rankGoalNotEnoughData;
        break;
      case RankGoalTrendStatus.trendingAway:
        progressLine = l10n.rankGoalTrendingAway;
        progressColor = theme.colorScheme.error;
        break;
      case RankGoalTrendStatus.onTrack:
        progressLine = l10n.rankGoalEstimatedGames(estimate.estimatedGames!);
        break;
    }

    return Card(
      child: InkWell(
        borderRadius: AppRadius.brXl,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RankGoalScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.emoji_events, color: progressColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.rankGoalSummaryCardTitle,
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.rankGoalSummaryTargetLabel(targetTierName),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      remainingRR > 0
                          ? '${l10n.rrToGo(remainingRR)} · $progressLine'
                          : progressLine,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: progressColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
