library;

class PlayerAggStats {
  final String subject;
  int kills = 0;
  int deaths = 0;
  int assists = 0;
  int damageDealt = 0;
  int headshots = 0;
  int bodyshots = 0;
  int legshots = 0;
  int firstKills = 0;
  int firstDeaths = 0;
  int plants = 0;
  int defuses = 0;
  int roundsWithKast = 0;
  int roundsPlayed = 0;
  int totalScore = 0;
  final List<MultiKillRound> multiKills = [];
  final List<ClutchResult> clutches = [];

  PlayerAggStats(this.subject);

  double get acs => roundsPlayed > 0 ? totalScore / roundsPlayed : 0;

  double get adr => roundsPlayed > 0 ? damageDealt / roundsPlayed : 0;
  double get hsPercent {
    final totalShots = headshots + bodyshots + legshots;
    return totalShots > 0 ? (headshots / totalShots) * 100 : 0;
  }

  double get kast =>
      roundsPlayed > 0 ? (roundsWithKast / roundsPlayed) * 100 : 0;
  double get kd => deaths > 0 ? kills / deaths : kills.toDouble();
  double get fkPerRound => roundsPlayed > 0 ? firstKills / roundsPlayed : 0;
}

class HalfStats {
  int kills = 0;
  int deaths = 0;
  int assists = 0;
  int plants = 0;
  int defuses = 0;
  int firstBloods = 0;
  int firstDeaths = 0;
  int roundsPlayed = 0;
}

class ClutchResult {
  final int roundNum;
  final int enemiesFaced;
  final bool won;

  ClutchResult({
    required this.roundNum,
    required this.enemiesFaced,
    required this.won,
  });

  String get label => '1v$enemiesFaced';
}

class MultiKillRound {
  final int roundNum;
  final int kills;
  MultiKillRound({required this.roundNum, required this.kills});
}

class DuelRecord {
  final String opponentPuuid;
  int killsOnOpponent = 0;
  int deathsToOpponent = 0;
  DuelRecord(this.opponentPuuid);
  int get net => killsOnOpponent - deathsToOpponent;
  int get totalEngagements => killsOnOpponent + deathsToOpponent;
}

class PairDuel {
  final String puuidA;
  final String puuidB;
  int aKills = 0;
  int bKills = 0;
  PairDuel(this.puuidA, this.puuidB);
  int get total => aKills + bKills;
  int get imbalance => (aKills - bKills).abs();
}

class RoundEconomyEntry {
  final int roundNum;
  final int loadoutValue;
  final int spent;
  final int remaining;
  final String? weapon;
  final bool won;
  final bool isPistolRound;

  RoundEconomyEntry({
    required this.roundNum,
    required this.loadoutValue,
    required this.spent,
    required this.remaining,
    required this.weapon,
    required this.won,
    required this.isPistolRound,
  });

  String get buyType {
    if (loadoutValue < 5000) return 'ECO';
    if (loadoutValue < 10000) return 'SEMI';
    if (loadoutValue < 20000) return 'BONUS';
    return 'FULL';
  }
}

class RoundPerformanceEntry {
  final int roundNum;
  final int score;
  final int kills;
  final int deaths;
  final int assists;
  final int damage;
  final bool won;
  final bool isAttack;

  RoundPerformanceEntry({
    required this.roundNum,
    required this.score,
    required this.kills,
    required this.deaths,
    required this.assists,
    required this.damage,
    required this.won,
    required this.isAttack,
  });
}

class RoundSummary {
  final int roundNum;
  final String winningTeam;
  final String? resultCode;
  final String? bombPlanter;
  final String? bombDefuser;
  final String? plantSite;
  final int? plantRoundTime;
  final int? defuseRoundTime;
  final List<Map<String, dynamic>> kills;
  final int blueKills;
  final int redKills;

  RoundSummary({
    required this.roundNum,
    required this.winningTeam,
    required this.resultCode,
    required this.bombPlanter,
    required this.bombDefuser,
    required this.plantSite,
    required this.plantRoundTime,
    required this.defuseRoundTime,
    required this.kills,
    required this.blueKills,
    required this.redKills,
  });
}

class MatchAnalysis {
  final Map<String, PlayerAggStats> playerStats;
  final HalfStats attack;
  final HalfStats defense;
  final List<ClutchResult> clutches;
  final List<MultiKillRound> multiKills;
  final Map<String, DuelRecord> duels;
  final List<PairDuel> allDuels;
  final List<RoundEconomyEntry> economy;
  final List<RoundPerformanceEntry> performance;
  final List<RoundSummary> rounds;
  final Map<String, List<Map<String, dynamic>>> allKillsByRound;

  MatchAnalysis({
    required this.playerStats,
    required this.attack,
    required this.defense,
    required this.clutches,
    required this.multiKills,
    required this.duels,
    required this.allDuels,
    required this.economy,
    required this.performance,
    required this.rounds,
    required this.allKillsByRound,
  });

  static double lobbyAverage(
    Iterable<PlayerAggStats> all,
    double Function(PlayerAggStats) metric,
  ) {
    final withRounds = all.where((p) => p.roundsPlayed > 0).toList();
    if (withRounds.isEmpty) return 0;
    final total = withRounds.fold<double>(0, (sum, p) => sum + metric(p));
    return total / withRounds.length;
  }
}

class MatchStatsCalculator {
  static String attackTeamForRound(
    int roundNum,
    String firstHalfAttackTeam,
    String otherTeam,
  ) {
    if (roundNum < 12) return firstHalfAttackTeam;
    if (roundNum < 24) return otherTeam;
    final ot = roundNum - 24;
    return ot % 2 == 0 ? firstHalfAttackTeam : otherTeam;
  }

  static String _pairKey(String a, String b) => ([a, b]..sort()).join('|');

  static MatchAnalysis analyze({
    required Map<String, dynamic> matchDetails,
    required String targetPuuid,
  }) {
    final players = (matchDetails['players'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final roundResults = (matchDetails['roundResults'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    final teamBySubject = <String, String>{
      for (final p in players)
        (p['subject']?.toString() ?? ''): (p['teamId'] ?? '').toString(),
    };

    final playerStats = <String, PlayerAggStats>{
      for (final p in players)
        (p['subject']?.toString() ?? ''): PlayerAggStats(
          p['subject']?.toString() ?? '',
        ),
    };

    final targetTeam = teamBySubject[targetPuuid] ?? '';
    final otherTeam = targetTeam == 'Blue' ? 'Red' : 'Blue';

    final attack = HalfStats();
    final defense = HalfStats();
    final duels = <String, DuelRecord>{};
    final pairDuels = <String, PairDuel>{};
    final economy = <RoundEconomyEntry>[];
    final performance = <RoundPerformanceEntry>[];
    final rounds = <RoundSummary>[];
    final allKillsByRound = <String, List<Map<String, dynamic>>>{};

    final blueRoster = players.where((p) => p['teamId'] == 'Blue').length;
    final redRoster = players.where((p) => p['teamId'] == 'Red').length;

    for (final round in roundResults) {
      final roundNum = round['roundNum'] as int? ?? 0;
      final winningTeam = round['winningTeam']?.toString() ?? '';
      final bombPlanter = round['bombPlanter']?.toString();
      final bombDefuser = round['bombDefuser']?.toString();
      final psList = (round['playerStats'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      final attackTeamThisRound = targetTeam.isEmpty
          ? ''
          : attackTeamForRound(roundNum, targetTeam, otherTeam);
      final targetIsAttack = attackTeamThisRound == targetTeam;

      final roundKills = <Map<String, dynamic>>[];
      for (final ps in psList) {
        roundKills.addAll(
          (ps['kills'] as List? ?? []).cast<Map<String, dynamic>>(),
        );
      }
      roundKills.sort(
        (a, b) => ((a['roundTime'] as int?) ?? 0).compareTo(
          (b['roundTime'] as int?) ?? 0,
        ),
      );
      allKillsByRound[roundNum.toString()] = roundKills;

      final firstKillerId = roundKills.isNotEmpty
          ? roundKills.first['killer']?.toString()
          : null;
      final firstVictimId = roundKills.isNotEmpty
          ? roundKills.first['victim']?.toString()
          : null;

      var blueKillCount = 0;
      var redKillCount = 0;
      for (final k in roundKills) {
        final killerTeam = teamBySubject[k['killer']?.toString()];
        if (killerTeam == 'Blue') {
          blueKillCount += 1;
        } else if (killerTeam == 'Red') {
          redKillCount += 1;
        }
      }
      rounds.add(
        RoundSummary(
          roundNum: roundNum,
          winningTeam: winningTeam,
          resultCode: (round['roundResult'] ?? round['roundResultCode'])
              ?.toString(),
          bombPlanter: bombPlanter,
          bombDefuser: bombDefuser,
          plantSite: round['plantSite']?.toString(),
          plantRoundTime: round['plantRoundTime'] as int?,
          defuseRoundTime: round['defuseRoundTime'] as int?,
          kills: roundKills,
          blueKills: blueKillCount,
          redKills: redKillCount,
        ),
      );

      final deadThisRound = <String>{};
      for (final k in roundKills) {
        final victim = k['victim']?.toString();
        if (victim != null) deadThisRound.add(victim);
      }

      final roundDamageBySubject = <String, int>{};
      for (final ps in psList) {
        final subject = ps['subject']?.toString() ?? '';
        final agg = playerStats.putIfAbsent(
          subject,
          () => PlayerAggStats(subject),
        );
        agg.roundsPlayed += 1;

        final psKills = (ps['kills'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        agg.kills += psKills.length;
        if (subject == firstKillerId) agg.firstKills += 1;
        if (deadThisRound.contains(subject)) {
          agg.deaths += 1;
          if (subject == firstVictimId) agg.firstDeaths += 1;
        }
        if (bombPlanter == subject) agg.plants += 1;
        if (bombDefuser == subject) agg.defuses += 1;
        if (psKills.length >= 2) {
          agg.multiKills.add(
            MultiKillRound(roundNum: roundNum, kills: psKills.length),
          );
        }

        for (final k in psKills) {
          final assistants = (k['assistants'] as List? ?? []);
          for (final a in assistants) {
            final aid = a?.toString();
            if (aid != null) {
              playerStats.putIfAbsent(aid, () => PlayerAggStats(aid)).assists +=
                  1;
            }
          }
          final victim = k['victim']?.toString();
          if (victim == null) continue;

          if (subject == targetPuuid) {
            duels
                    .putIfAbsent(victim, () => DuelRecord(victim))
                    .killsOnOpponent +=
                1;
          } else if (victim == targetPuuid) {
            duels
                    .putIfAbsent(subject, () => DuelRecord(subject))
                    .deathsToOpponent +=
                1;
          }

          final key = _pairKey(subject, victim);
          final pair = pairDuels.putIfAbsent(
            key,
            () => PairDuel(subject, victim),
          );
          if (pair.puuidA == subject) {
            pair.aKills += 1;
          } else {
            pair.bKills += 1;
          }
        }

        final damageList = (ps['damage'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        var roundDamage = 0;
        for (final d in damageList) {
          roundDamage += (d['damage'] as num? ?? 0).toInt();
          agg.headshots += (d['headshots'] as num? ?? 0).toInt();
          agg.bodyshots += (d['bodyshots'] as num? ?? 0).toInt();
          agg.legshots += (d['legshots'] as num? ?? 0).toInt();
        }
        agg.damageDealt += roundDamage;
        agg.totalScore += (ps['score'] as num? ?? 0).toInt();
        roundDamageBySubject[subject] = roundDamage;

        final gotAssist = roundKills.any(
          (k) => (k['assistants'] as List? ?? [])
              .map((e) => e.toString())
              .contains(subject),
        );
        if (psKills.isNotEmpty ||
            gotAssist ||
            !deadThisRound.contains(subject)) {
          agg.roundsWithKast += 1;
        }
      }

      for (final subject in teamBySubject.keys) {
        final myTeam = teamBySubject[subject];
        if (myTeam == null || myTeam.isEmpty) continue;
        if (!psList.any((ps) => ps['subject'] == subject)) continue;

        var blueAlive = blueRoster;
        var redAlive = redRoster;
        var clutchEnemiesFaced = 0;
        var inClutch = false;
        var died = false;
        for (final k in roundKills) {
          final victim = k['victim']?.toString();
          final victimTeam = teamBySubject[victim];
          if (victimTeam == 'Blue') {
            blueAlive -= 1;
          } else if (victimTeam == 'Red') {
            redAlive -= 1;
          }
          if (victim == subject) died = true;

          final myAlive = myTeam == 'Blue' ? blueAlive : redAlive;
          final enemyAlive = myTeam == 'Blue' ? redAlive : blueAlive;
          if (!inClutch && !died && myAlive == 1 && enemyAlive >= 1) {
            inClutch = true;
            clutchEnemiesFaced = enemyAlive;
          }
        }
        if (inClutch && clutchEnemiesFaced > 0) {
          final won = winningTeam == myTeam && !died;
          playerStats
              .putIfAbsent(subject, () => PlayerAggStats(subject))
              .clutches
              .add(
                ClutchResult(
                  roundNum: roundNum,
                  enemiesFaced: clutchEnemiesFaced,
                  won: won,
                ),
              );
        }
      }

      if (targetTeam.isNotEmpty &&
          psList.any((ps) => ps['subject'] == targetPuuid)) {
        final myPs = psList.firstWhere(
          (p) => p['subject'] == targetPuuid,
          orElse: () => {},
        );
        final myKillsCount = ((myPs['kills'] as List?) ?? []).length;
        final myDamage = roundDamageBySubject[targetPuuid] ?? 0;
        final myAssists = roundKills
            .where(
              (k) => (k['assistants'] as List? ?? [])
                  .map((e) => e.toString())
                  .contains(targetPuuid),
            )
            .length;
        final economyData = myPs['economy'] as Map<String, dynamic>? ?? {};
        final score = (myPs['score'] as num? ?? 0).toInt();
        final won = winningTeam == targetTeam;

        performance.add(
          RoundPerformanceEntry(
            roundNum: roundNum,
            score: score,
            kills: myKillsCount,
            deaths: deadThisRound.contains(targetPuuid) ? 1 : 0,
            assists: myAssists,
            damage: myDamage,
            won: won,
            isAttack: targetIsAttack,
          ),
        );
        economy.add(
          RoundEconomyEntry(
            roundNum: roundNum,
            loadoutValue: (economyData['loadoutValue'] as num? ?? 0).toInt(),
            spent: (economyData['spent'] as num? ?? 0).toInt(),
            remaining: (economyData['remaining'] as num? ?? 0).toInt(),
            weapon: economyData['weapon']?.toString(),
            won: won,
            isPistolRound: roundNum == 0 || roundNum == 12,
          ),
        );

        final half = targetIsAttack ? attack : defense;
        half.roundsPlayed += 1;
        half.kills += myKillsCount;
        if (deadThisRound.contains(targetPuuid)) half.deaths += 1;
        half.assists += myAssists;
        if (bombPlanter == targetPuuid) half.plants += 1;
        if (bombDefuser == targetPuuid) half.defuses += 1;
        if (firstKillerId == targetPuuid) half.firstBloods += 1;
        if (firstVictimId == targetPuuid) half.firstDeaths += 1;
      }
    }

    final myMultiKills = playerStats[targetPuuid]?.multiKills ?? const [];
    final myClutches = playerStats[targetPuuid]?.clutches ?? const [];

    return MatchAnalysis(
      playerStats: playerStats,
      attack: attack,
      defense: defense,
      clutches: myClutches,
      multiKills: myMultiKills,
      duels: duels,
      allDuels: pairDuels.values.toList(),
      economy: economy,
      performance: performance,
      rounds: rounds,
      allKillsByRound: allKillsByRound,
    );
  }
}
