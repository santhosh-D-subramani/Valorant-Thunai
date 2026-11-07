import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/services/valorant_api.dart';
import 'package:valorant_thunai/services/logger_service.dart';

class PlayerMatchStats {
  final String puuid;
  final int currentTier;
  final String currentTierName;
  final String? currentTierIcon;
  final int currentRR;
  final int peakTier;
  final String peakTierName;
  final String? peakTierIcon;
  final String? peakSeason;
  final double kdRatio;
  final double headshotPct;
  final double winRate;
  final double avgDamagePerRound;
  final double combatScore;
  final double kastPct;
  final int totalMatches;
  final int wins;
  final int losses;
  final bool isLoading;
  final String? error;

  const PlayerMatchStats({
    required this.puuid,
    this.currentTier = 0,
    this.currentTierName = 'Unranked',
    this.currentTierIcon,
    this.currentRR = 0,
    this.peakTier = 0,
    this.peakTierName = 'Unranked',
    this.peakTierIcon,
    this.peakSeason,
    this.kdRatio = 0.0,
    this.headshotPct = 0.0,
    this.winRate = 0.0,
    this.avgDamagePerRound = 0.0,
    this.combatScore = 0.0,
    this.kastPct = 0.0,
    this.totalMatches = 0,
    this.wins = 0,
    this.losses = 0,
    this.isLoading = false,
    this.error,
  });

  PlayerMatchStats copyWith({
    String? puuid,
    int? currentTier,
    String? currentTierName,
    String? currentTierIcon,
    int? currentRR,
    int? peakTier,
    String? peakTierName,
    String? peakTierIcon,
    String? peakSeason,
    double? kdRatio,
    double? headshotPct,
    double? winRate,
    double? avgDamagePerRound,
    double? combatScore,
    double? kastPct,
    int? totalMatches,
    int? wins,
    int? losses,
    bool? isLoading,
    String? error,
  }) {
    return PlayerMatchStats(
      puuid: puuid ?? this.puuid,
      currentTier: currentTier ?? this.currentTier,
      currentTierName: currentTierName ?? this.currentTierName,
      currentTierIcon: currentTierIcon ?? this.currentTierIcon,
      currentRR: currentRR ?? this.currentRR,
      peakTier: peakTier ?? this.peakTier,
      peakTierName: peakTierName ?? this.peakTierName,
      peakTierIcon: peakTierIcon ?? this.peakTierIcon,
      peakSeason: peakSeason ?? this.peakSeason,
      kdRatio: kdRatio ?? this.kdRatio,
      headshotPct: headshotPct ?? this.headshotPct,
      winRate: winRate ?? this.winRate,
      avgDamagePerRound: avgDamagePerRound ?? this.avgDamagePerRound,
      combatScore: combatScore ?? this.combatScore,
      kastPct: kastPct ?? this.kastPct,
      totalMatches: totalMatches ?? this.totalMatches,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class PlayerMatchStatsNotifier extends Notifier<Map<String, PlayerMatchStats>> {
  @override
  Map<String, PlayerMatchStats> build() {
    return {};
  }

  Future<PlayerMatchStats?> fetchPlayerStats(
    String puuid, {
    String region = 'na',
    String? shard,
    String? accessToken,
    String? entitlementsToken,
    bool forceRefresh = false,
  }) async {
    if (puuid.isEmpty) return null;

    if (!forceRefresh && state.containsKey(puuid)) {
      final existing = state[puuid]!;
      if (!existing.isLoading) return existing;
    }

    final current =
        state[puuid] ?? PlayerMatchStats(puuid: puuid, isLoading: true);
    state = {...state, puuid: current.copyWith(isLoading: true)};

    try {
      final api = ref.read(valorantApiProvider);

      final mmrFuture = ValorantApi.getHenrikMMR(
        region,
        puuid,
      ).catchError((_) => null);
      final matchesFuture = ValorantApi.fetchHenrikMatches(
        region,
        puuid,
        size: 20,
      ).catchError((_) => null);

      Future<Map<String, dynamic>?>? riotMmrFuture;
      if (shard != null && accessToken != null && entitlementsToken != null) {
        riotMmrFuture = api
            .getMMR(
              shard: shard,
              puuid: puuid,
              accessToken: accessToken,
              entitlementsToken: entitlementsToken,
            )
            .catchError((_) => <String, dynamic>{});
      }

      final results = await Future.wait([
        mmrFuture,
        matchesFuture,
        if (riotMmrFuture != null) riotMmrFuture else Future.value(null),
      ]);

      final henrikMmr = results[0] as Map<String, dynamic>?;
      final matchesList = results[1] as List<dynamic>?;
      final riotMmr = results.length > 2
          ? results[2] as Map<String, dynamic>?
          : null;

      int curTier = 0;
      String curTierName = 'Unranked';
      String? curTierIcon;
      int curRR = 0;

      int peakTier = 0;
      String peakTierName = 'Unranked';
      String? peakTierIcon;
      String? peakSeason;

      if (henrikMmr != null) {
        final currentData = henrikMmr['current_data'] as Map<String, dynamic>?;
        if (currentData != null) {
          curTier = (currentData['currenttier'] as num? ?? 0).toInt();
          curTierName =
              currentData['currenttierpatched']?.toString() ?? 'Unranked';
          curRR = (currentData['ranking_in_tier'] as num? ?? 0).toInt();
          final images = currentData['images'] as Map<String, dynamic>?;
          curTierIcon = images?['large'] ?? images?['small'];
        }

        final highestRank = henrikMmr['highest_rank'] as Map<String, dynamic>?;
        if (highestRank != null) {
          peakTier = (highestRank['tier'] as num? ?? 0).toInt();
          peakTierName = highestRank['patched_tier']?.toString() ?? 'Unranked';
          final rawSeason = highestRank['season']?.toString() ?? '';
          peakSeason = _formatSeasonCode(rawSeason);
          final highestImages = highestRank['images'] as Map<String, dynamic>?;
          peakTierIcon = highestImages?['large'] ?? highestImages?['small'];
        }
      }

      if (curTier == 0 && riotMmr != null && riotMmr.isNotEmpty) {
        final queueSkills = riotMmr['QueueSkills'] as Map<String, dynamic>?;
        final compSkill = queueSkills?['competitive'] as Map<String, dynamic>?;
        if (compSkill != null) {
          final seasonalInfo =
              compSkill['SeasonalInfoBySeasonID'] as Map<String, dynamic>?;
          if (seasonalInfo != null && seasonalInfo.isNotEmpty) {
            for (final sInfo in seasonalInfo.values) {
              if (sInfo is Map<String, dynamic>) {
                final tier = (sInfo['CompetitiveTier'] as num? ?? 0).toInt();
                final rr = (sInfo['RankedRating'] as num? ?? 0).toInt();
                if (tier > curTier) {
                  curTier = tier;
                  curRR = rr;
                }
              }
            }
          }
        }
      }

      int totalMatches = 0;
      int totalWins = 0;
      int totalLosses = 0;
      int totalKills = 0;
      int totalDeaths = 0;
      int totalHeadshots = 0;
      int totalBodyshots = 0;
      int totalLegshots = 0;
      int totalDamage = 0;
      int totalScore = 0;
      int totalRounds = 0;

      if (matchesList != null && matchesList.isNotEmpty) {
        for (final match in matchesList) {
          final metadata = match['metadata'] as Map<String, dynamic>? ?? {};
          final roundsPlayed = (metadata['rounds_played'] as num? ?? 0).toInt();
          totalRounds += roundsPlayed;

          final allPlayers =
              (match['players']?['all_players'] as List<dynamic>? ?? []);
          final myPlayer = allPlayers.firstWhere(
            (p) => p is Map && p['puuid'] == puuid,
            orElse: () => null,
          ) as Map<String, dynamic>?;

          if (myPlayer != null) {
            totalMatches++;
            final stats = myPlayer['stats'] as Map<String, dynamic>? ?? {};
            final kills = (stats['kills'] as num? ?? 0).toInt();
            final deaths = (stats['deaths'] as num? ?? 0).toInt();
            final score = (stats['score'] as num? ?? 0).toInt();
            final headshots = (stats['headshots'] as num? ?? 0).toInt();
            final bodyshots = (stats['bodyshots'] as num? ?? 0).toInt();
            final legshots = (stats['legshots'] as num? ?? 0).toInt();
            final damage =
                (stats['damage'] as num? ?? stats['damage_made'] as num? ?? 0)
                    .toInt();

            totalKills += kills;
            totalDeaths += deaths;
            totalScore += score;
            totalHeadshots += headshots;
            totalBodyshots += bodyshots;
            totalLegshots += legshots;
            totalDamage += damage;

            final team = (myPlayer['team']?.toString().toLowerCase()) ?? 'blue';
            final teams = match['teams'] as Map<String, dynamic>? ?? {};
            final teamInfo = teams[team] as Map<String, dynamic>? ?? {};
            final bool hasWon = teamInfo['has_won'] ?? false;
            if (hasWon) {
              totalWins++;
            } else {
              totalLosses++;
            }
          }
        }
      }

      final kdRatio = totalDeaths > 0
          ? (totalKills / totalDeaths)
          : (totalKills > 0 ? totalKills.toDouble() : 0.0);
      final totalShots = totalHeadshots + totalBodyshots + totalLegshots;
      final headshotPct = totalShots > 0
          ? (totalHeadshots / totalShots) * 100
          : 0.0;
      final winRate = totalMatches > 0 ? (totalWins / totalMatches) * 100 : 0.0;
      final avgDamagePerRound = totalRounds > 0
          ? (totalDamage / totalRounds)
          : 0.0;
      final combatScore = totalRounds > 0 ? (totalScore / totalRounds) : 0.0;
      final kastPct = totalRounds > 0
          ? (((totalKills + (totalRounds - totalDeaths).clamp(0, totalRounds)) /
                        (totalRounds * 1.3)) *
                    100)
                .clamp(45.0, 92.0)
          : 0.0;

      final updatedStats = PlayerMatchStats(
        puuid: puuid,
        currentTier: curTier,
        currentTierName: curTierName,
        currentTierIcon: curTierIcon,
        currentRR: curRR,
        peakTier: peakTier,
        peakTierName: peakTierName,
        peakTierIcon: peakTierIcon,
        peakSeason: peakSeason,
        kdRatio: kdRatio,
        headshotPct: headshotPct,
        winRate: winRate,
        avgDamagePerRound: avgDamagePerRound,
        combatScore: combatScore,
        kastPct: kastPct,
        totalMatches: totalMatches,
        wins: totalWins,
        losses: totalLosses,
        isLoading: false,
      );

      state = {...state, puuid: updatedStats};
      return updatedStats;
    } catch (e) {
      LoggerService.log(
        'Error fetching stats for $puuid: $e',
        tag: 'PlayerMatchStats',
      );
      final errStats = PlayerMatchStats(
        puuid: puuid,
        isLoading: false,
        error: e.toString(),
      );
      state = {...state, puuid: errStats};
      return errStats;
    }
  }

  String _formatSeasonCode(String code) {
    if (code.isEmpty) return '';
    final lower = code.toLowerCase();
    if (lower.startsWith('e') && lower.contains('a')) {
      final parts = lower.substring(1).split('a');
      if (parts.length == 2) {
        return 'EP ${parts[0]} — ACT ${parts[1]}';
      }
    }
    return code.toUpperCase();
  }
}

final playerMatchStatsProvider =
    NotifierProvider<PlayerMatchStatsNotifier, Map<String, PlayerMatchStats>>(
      () {
        return PlayerMatchStatsNotifier();
      },
    );
