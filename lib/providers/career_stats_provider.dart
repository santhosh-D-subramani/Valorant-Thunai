import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/services/valorant_api.dart';
import 'package:valorant_thunai/services/logger_service.dart';
import 'package:valorant_thunai/services/riot_auth_service.dart';
import 'package:valorant_thunai/utils/match_stats_calculator.dart';

class CareerActStats {
  final String seasonId;
  final String actLabel;
  int wins = 0;
  int losses = 0;
  int draws = 0;
  int games = 0;
  int peakTier = 0;

  CareerActStats({required this.seasonId, required this.actLabel});

  double get winRate => games > 0 ? (wins / games) * 100 : 0;
}

class CareerStats {
  final int totalMatches;
  final int totalWins;
  final int totalLosses;
  final int totalDraws;
  final double winRate;
  final double kd;
  final double hsPercent;
  final int totalPlaytimeMillis;
  final int currentTier;
  final int currentRR;
  final int peakTier;

  final List<CareerActStats> acts;

  final int competitiveMatches;
  final int competitiveWins;
  final int competitiveLosses;
  final int competitiveDraws;
  final double competitiveWinRate;

  final int matchesAnalyzed;
  final int matchesFetchedFromHistory;

  const CareerStats({
    required this.totalMatches,
    required this.totalWins,
    required this.totalLosses,
    required this.totalDraws,
    required this.winRate,
    required this.kd,
    required this.hsPercent,
    required this.totalPlaytimeMillis,
    required this.currentTier,
    required this.currentRR,
    required this.peakTier,
    required this.acts,
    required this.competitiveMatches,
    required this.competitiveWins,
    required this.competitiveLosses,
    required this.competitiveDraws,
    required this.competitiveWinRate,
    required this.matchesAnalyzed,
    required this.matchesFetchedFromHistory,
  });

  static const empty = CareerStats(
    totalMatches: 0,
    totalWins: 0,
    totalLosses: 0,
    totalDraws: 0,
    winRate: 0,
    kd: 0,
    hsPercent: 0,
    totalPlaytimeMillis: 0,
    currentTier: 0,
    currentRR: 0,
    peakTier: 0,
    acts: [],
    competitiveMatches: 0,
    competitiveWins: 0,
    competitiveLosses: 0,
    competitiveDraws: 0,
    competitiveWinRate: 0,
    matchesAnalyzed: 0,
    matchesFetchedFromHistory: 0,
  );
}

class CareerStatsNotifier extends AsyncNotifier<CareerStats> {
  static const int _maxMatchesToAnalyze = 60;
  static const int _detailFetchConcurrency = 5;

  @override
  Future<CareerStats> build() async {
    return CareerStats.empty;
  }

  Future<void> load({
    required RiotUser user,
    Map<String, String> actLabelsBySeasonId = const {},
    int currentTier = 0,
    int currentRR = 0,
    int peakTierFromRankHistory = 0,
  }) async {
    state = const AsyncLoading();
    try {
      final api = ref.read(valorantApiProvider);

      final historyData = await api.getMatchHistory(
        shard: user.shard,
        puuid: user.puuid,
        accessToken: user.accessToken,
        entitlementsToken: user.entitlementsToken,
        startIndex: 0,
        endIndex: _maxMatchesToAnalyze,
      );

      final List historyList = historyData?['History'] ?? [];
      final matchIds = historyList
          .map((m) => m['MatchID']?.toString())
          .whereType<String>()
          .toList();

      int totalWins = 0, totalLosses = 0, totalDraws = 0;
      int totalKills = 0, totalDeaths = 0;
      int totalHeadshots = 0, totalBodyshots = 0, totalLegshots = 0;
      int totalPlaytimeMillis = 0;
      int matchesAnalyzed = 0;

      int compMatches = 0, compWins = 0, compLosses = 0, compDraws = 0;

      final actsBySeasonId = <String, CareerActStats>{};

      for (var i = 0; i < matchIds.length; i += _detailFetchConcurrency) {
        final batch = matchIds.skip(i).take(_detailFetchConcurrency);
        final results = await Future.wait(
          batch.map((matchId) async {
            try {
              return await api.getMatchDetails(
                shard: user.shard,
                matchId: matchId,
                accessToken: user.accessToken,
                entitlementsToken: user.entitlementsToken,
              );
            } catch (e) {
              LoggerService.log(
                'Career stats: failed to load match $matchId: $e',
                tag: 'CareerStats',
              );
              return null;
            }
          }),
        );

        for (final details in results) {
          if (details == null) continue;
          final matchInfo = details['matchInfo'] as Map<String, dynamic>? ?? {};
          final players = (details['players'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          final me = players.firstWhere(
            (p) => p['subject']?.toString() == user.puuid,
            orElse: () => {},
          );
          if (me.isEmpty) continue;

          matchesAnalyzed++;

          final queueId = (matchInfo['queueID']?.toString() ?? '')
              .toLowerCase();
          final isCompetitive = queueId == 'competitive';
          final gameLength =
              (matchInfo['gameLengthMillis'] as num?)?.toInt() ?? 0;
          totalPlaytimeMillis += gameLength;

          final myTeamId = me['teamId']?.toString();
          final teams = (details['teams'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          bool hasWon = false;
          bool isDraw = false;
          if (teams.isNotEmpty && myTeamId != null) {
            final myTeamEntry = teams.firstWhere(
              (t) => t['teamId']?.toString() == myTeamId,
              orElse: () => {},
            );
            hasWon = myTeamEntry['won'] == true;
            isDraw = teams.length == 2 && teams.every((t) => t['won'] != true);
          }

          final analysis = MatchStatsCalculator.analyze(
            matchDetails: details,
            targetPuuid: user.puuid,
          );
          final myAgg = analysis.playerStats[user.puuid];
          if (myAgg != null) {
            totalKills += myAgg.kills;
            totalDeaths += myAgg.deaths;
            totalHeadshots += myAgg.headshots;
            totalBodyshots += myAgg.bodyshots;
            totalLegshots += myAgg.legshots;
          }

          if (hasWon) {
            totalWins++;
          } else if (isDraw) {
            totalDraws++;
          } else {
            totalLosses++;
          }

          if (isCompetitive) {
            compMatches++;
            if (hasWon) {
              compWins++;
            } else if (isDraw) {
              compDraws++;
            } else {
              compLosses++;
            }

            final seasonId = matchInfo['seasonId']?.toString() ?? '';
            if (seasonId.isNotEmpty) {
              final act = actsBySeasonId.putIfAbsent(
                seasonId,
                () => CareerActStats(
                  seasonId: seasonId,
                  actLabel: actLabelsBySeasonId[seasonId] ?? seasonId,
                ),
              );
              act.games++;
              if (hasWon) {
                act.wins++;
              } else if (isDraw) {
                act.draws++;
              } else {
                act.losses++;
              }
              final myTier = (me['competitiveTier'] as num?)?.toInt() ?? 0;
              if (myTier > act.peakTier) act.peakTier = myTier;
            }
          }
        }
      }

      final totalShots = totalHeadshots + totalBodyshots + totalLegshots;
      final matchDerivedPeakTier = actsBySeasonId.values.fold<int>(
        0,
        (max, a) => a.peakTier > max ? a.peakTier : max,
      );
      final overallPeakTier = [
        matchDerivedPeakTier,
        peakTierFromRankHistory,
        currentTier,
      ].reduce((a, b) => a > b ? a : b);

      final acts = actsBySeasonId.values.toList();

      state = AsyncData(
        CareerStats(
          totalMatches: matchesAnalyzed,
          totalWins: totalWins,
          totalLosses: totalLosses,
          totalDraws: totalDraws,
          winRate: matchesAnalyzed > 0
              ? (totalWins / matchesAnalyzed) * 100
              : 0,
          kd: totalDeaths > 0
              ? totalKills / totalDeaths
              : totalKills.toDouble(),
          hsPercent: totalShots > 0 ? (totalHeadshots / totalShots) * 100 : 0,
          totalPlaytimeMillis: totalPlaytimeMillis,
          currentTier: currentTier,
          currentRR: currentRR,
          peakTier: overallPeakTier,
          acts: acts,
          competitiveMatches: compMatches,
          competitiveWins: compWins,
          competitiveLosses: compLosses,
          competitiveDraws: compDraws,
          competitiveWinRate: compMatches > 0
              ? (compWins / compMatches) * 100
              : 0,
          matchesAnalyzed: matchesAnalyzed,
          matchesFetchedFromHistory: matchIds.length,
        ),
      );
    } catch (e, st) {
      LoggerService.log('Career stats load failed: $e', tag: 'CareerStats');
      state = AsyncError(e, st);
    }
  }
}

final careerStatsProvider =
    AsyncNotifierProvider<CareerStatsNotifier, CareerStats>(() {
      return CareerStatsNotifier();
    });
