import 'dart:math' as math;

import 'package:valorant_thunai/models/rank_history_entry.dart';

enum RankGoalTrendStatus { notEnoughData, goalReached, trendingAway, onTrack }

class RankGoalEstimate {
  final RankGoalTrendStatus status;

  final double avgRRPerGame;

  final int? estimatedGames;

  final int gamesConsidered;

  const RankGoalEstimate({
    required this.status,
    this.avgRRPerGame = 0,
    this.estimatedGames,
    this.gamesConsidered = 0,
  });
}

int _combinedRank(int tier, int rr) => (tier * 100) + rr;

RankGoalEstimate computeRankGoalEstimate({
  required List<RankHistoryEntry> history,
  required int targetTierId,
  required int currentTierId,
  required int currentRR,
  int lastNGames = 10,
}) {
  if (currentTierId >= targetTierId) {
    return const RankGoalEstimate(status: RankGoalTrendStatus.goalReached);
  }

  final windowSize = math.min(history.length, lastNGames + 1);
  if (windowSize < 2) {
    return const RankGoalEstimate(status: RankGoalTrendStatus.notEnoughData);
  }

  final window = history.sublist(history.length - windowSize);
  final firstCombined = _combinedRank(window.first.tier, window.first.rr);
  final lastCombined = _combinedRank(window.last.tier, window.last.rr);
  final gamesConsidered = window.length - 1;
  final avgPerGame = (lastCombined - firstCombined) / gamesConsidered;

  if (avgPerGame <= 0) {
    return RankGoalEstimate(
      status: RankGoalTrendStatus.trendingAway,
      avgRRPerGame: avgPerGame,
      gamesConsidered: gamesConsidered,
    );
  }

  final remainingCombined =
      (targetTierId * 100) - _combinedRank(currentTierId, currentRR);
  final estimatedGames = (remainingCombined / avgPerGame).ceil().clamp(
    1,
    1 << 30,
  );

  return RankGoalEstimate(
    status: RankGoalTrendStatus.onTrack,
    avgRRPerGame: avgPerGame,
    estimatedGames: estimatedGames,
    gamesConsidered: gamesConsidered,
  );
}
