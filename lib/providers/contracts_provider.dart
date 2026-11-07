import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'auth_provider.dart';

import 'package:valorant_thunai/services/valorant_api.dart';
import 'package:valorant_thunai/services/logger_service.dart';
import 'package:valorant_thunai/services/xp_forecast_service.dart';

import 'skin_provider.dart';

class MissionProgress {
  final String id;
  final String title;
  final String type;
  final int xpGrant;
  final int progress;
  final int progressToComplete;
  final bool isComplete;
  final DateTime expirationTime;

  MissionProgress({
    required this.id,
    required this.title,
    required this.type,
    required this.xpGrant,
    required this.progress,
    required this.progressToComplete,
    required this.isComplete,
    required this.expirationTime,
  });
}

String formatMissionTitle(String title, int target) {
  if (target <= 0) return title;

  switch (title) {
    case 'Get Headshots':
      return 'Get $target Headshots';
    case 'Deal Damage':
      return 'Deal $target Damage';
    case 'Use Your Ultimate':
      return 'Use Your Ultimate $target times';
    default:
      return '$title ($target)';
  }
}

class PassProgress {
  final String contractId;
  final String displayName;
  final int currentLevel;
  final int totalLevels;
  final int currentLevelXp;
  final int nextLevelXpNeeded;
  final double percentage;
  final String? activeRewardName;
  final String? activeRewardIcon;
  final String? activeRewardType;
  final DateTime? expirationTime;
  final BattlepassForecast forecast;

  PassProgress({
    required this.contractId,
    required this.displayName,
    required this.currentLevel,
    required this.totalLevels,
    required this.currentLevelXp,
    required this.nextLevelXpNeeded,
    required this.percentage,
    this.activeRewardName,
    this.activeRewardIcon,
    this.activeRewardType,
    this.expirationTime,
    this.forecast = const BattlepassForecast(),
  });

  PassProgress copyWith({BattlepassForecast? forecast}) => PassProgress(
    contractId: contractId,
    displayName: displayName,
    currentLevel: currentLevel,
    totalLevels: totalLevels,
    currentLevelXp: currentLevelXp,
    nextLevelXpNeeded: nextLevelXpNeeded,
    percentage: percentage,
    activeRewardName: activeRewardName,
    activeRewardIcon: activeRewardIcon,
    activeRewardType: activeRewardType,
    expirationTime: expirationTime,
    forecast: forecast ?? this.forecast,
  );
}

class AgentContractsData {
  final int unlockedCount;
  final int completedCount;
  final int totalAgents;
  final int currentProgressXp;
  final int totalNeededXp;
  final int kingdomCreditsBalance;

  AgentContractsData({
    required this.unlockedCount,
    required this.completedCount,
    required this.totalAgents,
    required this.currentProgressXp,
    required this.totalNeededXp,
    required this.kingdomCreditsBalance,
  });
}

class RecentMatchXp {
  final String matchId;
  final DateTime matchTime;
  final int totalXp;
  final Map<String, int> xpBreakdown;

  RecentMatchXp({
    required this.matchId,
    required this.matchTime,
    required this.totalXp,
    required this.xpBreakdown,
  });
}

class ContractsData {
  final int activeDailyCheckpoints;
  final int dailyResetSeconds;
  final int weeklyResetSeconds;
  final List<MissionProgress> activeWeeklyMissions;
  final Map<int, List<Map<String, dynamic>>> futureWeeklyMissions;
  final PassProgress? battlePass;
  final PassProgress? eventPass;
  final AgentContractsData agentContracts;
  final List<RecentMatchXp> recentXpHistory;

  ContractsData({
    required this.activeDailyCheckpoints,
    required this.dailyResetSeconds,
    required this.weeklyResetSeconds,
    required this.activeWeeklyMissions,
    required this.futureWeeklyMissions,
    this.battlePass,
    this.eventPass,
    required this.agentContracts,
    required this.recentXpHistory,
  });
}

final staticContractsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  try {
    final response = await http.get(
      Uri.parse('https://valorant-api.com/v1/contracts'),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['data'];
      return {for (var item in data) item['uuid']: item};
    }
    LoggerService.log(
      'Failed to load static contracts, status: ${response.statusCode}',
      tag: 'Contracts',
    );
  } catch (e) {
    LoggerService.log('Error loading static contracts: $e', tag: 'Contracts');
  }
  return <String, dynamic>{};
});

final staticMissionsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  try {
    final response = await http.get(
      Uri.parse('https://valorant-api.com/v1/missions'),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['data'];
      return {for (var item in data) item['uuid']: item};
    }
    LoggerService.log(
      'Failed to load static missions, status: ${response.statusCode}',
      tag: 'Contracts',
    );
  } catch (e) {
    LoggerService.log('Error loading static missions: $e', tag: 'Contracts');
  }
  return <String, dynamic>{};
});

final playableAgentsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  try {
    final response = await http.get(
      Uri.parse('https://valorant-api.com/v1/agents?isPlayableCharacter=true'),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['data'];
      return {for (final item in data) item['uuid']: item};
    }
    LoggerService.log(
      'Failed to load playable agents, status: ${response.statusCode}',
      tag: 'Contracts',
    );
  } catch (e) {
    LoggerService.log('Error loading playable agents: $e', tag: 'Contracts');
  }
  return <String, dynamic>{};
});

const _agentItemTypeId = '01bb38e1-da47-4e6a-9b3d-945fe4655707';

final contractsProvider = FutureProvider<ContractsData?>((ref) async {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null || authState.hasSessionExpired) {
    LoggerService.log(
      'User is null (${user == null}) or session expired (${authState.hasSessionExpired}) in contractsProvider',
      tag: 'Contracts',
    );
    return null;
  }

  final api = ref.read(valorantApiProvider);

  try {
    await ref.read(authProvider.notifier).checkAndRefreshSession();
  } catch (e) {
    LoggerService.log('checkAndRefreshSession notice: $e', tag: 'Contracts');
  }

  final currentUser = ref.read(authProvider).user ?? user;

  Map<String, dynamic> dynamicContractsData = {};
  try {
    dynamicContractsData = await api.getContracts(
      shard: currentUser.shard,
      puuid: currentUser.puuid,
      accessToken: currentUser.accessToken,
      entitlementsToken: currentUser.entitlementsToken,
    );
  } catch (e) {
    LoggerService.log(
      'getContracts initial attempt failed: $e',
      tag: 'Contracts',
    );
    if (e.toString().contains('400') ||
        e.toString().contains('401') ||
        e.toString().contains('expired') ||
        e.toString().contains('Unauthorized')) {
      LoggerService.log(
        'Attempting force token refresh for contracts...',
        tag: 'Contracts',
      );
      try {
        await ref
            .read(authProvider.notifier)
            .checkAndRefreshSession(force: true);
        final refreshedUser = ref.read(authProvider).user;
        if (refreshedUser != null) {
          dynamicContractsData = await api.getContracts(
            shard: refreshedUser.shard,
            puuid: refreshedUser.puuid,
            accessToken: refreshedUser.accessToken,
            entitlementsToken: refreshedUser.entitlementsToken,
          );
        }
      } catch (retryError) {
        LoggerService.log(
          'getContracts retry failed: $retryError',
          tag: 'Contracts',
        );
      }
    }
  }

  if (dynamicContractsData.isEmpty) {
    LoggerService.log(
      'dynamicContractsData is empty, returning null',
      tag: 'Contracts',
    );
    return null;
  }

  final results = await Future.wait<dynamic>(<Future<dynamic>>[
    ref.watch(staticContractsProvider.future).catchError((e) {
      LoggerService.log('staticContractsProvider error: $e', tag: 'Contracts');
      return <String, dynamic>{};
    }),
    ref.watch(staticMissionsProvider.future).catchError((e) {
      LoggerService.log('staticMissionsProvider error: $e', tag: 'Contracts');
      return <String, dynamic>{};
    }),
    http.get(Uri.parse('https://valorant-api.com/v1/seasons')).catchError((e) {
      LoggerService.log('seasons fetch error: $e', tag: 'Contracts');
      return http.Response('{}', 400);
    }),
    ref
        .watch(skinsMetadataProvider.future)
        .catchError((_) => <String, SkinMetadata>{}),
    ref
        .watch(playerCardsProvider.future)
        .catchError((_) => <String, dynamic>{}),
    ref.watch(buddiesProvider.future).catchError((_) => <String, dynamic>{}),
    ref.watch(spraysProvider.future).catchError((_) => <String, dynamic>{}),
    ref.watch(titlesProvider.future).catchError((_) => <String, dynamic>{}),
    api
        .getEntitlements(
          currentUser.puuid,
          currentUser.shard,
          currentUser.accessToken,
          currentUser.entitlementsToken,
          _agentItemTypeId,
        )
        .catchError((e) {
          LoggerService.log('getEntitlements error: $e', tag: 'Contracts');
          return <dynamic>[];
        }),
    ref.watch(playableAgentsProvider.future).catchError((e) {
      LoggerService.log('playableAgentsProvider error: $e', tag: 'Contracts');
      return <String, dynamic>{};
    }),
  ]);

  final staticContracts = results[0] as Map<String, dynamic>;
  final staticMissions = results[1] as Map<String, dynamic>;
  final seasonsRes = results[2] as http.Response;

  final skins = results[3] as Map<String, SkinMetadata>;
  final cards = results[4] as Map<String, dynamic>;
  final buddies = results[5] as Map<String, dynamic>;
  final sprays = results[6] as Map<String, dynamic>;
  final titles = results[7] as Map<String, dynamic>;
  final agentEntitlements = results[8] as List<dynamic>;
  final playableAgents = results[9] as Map<String, dynamic>;

  if (dynamicContractsData.isEmpty) return null;

  final missionMetadata = dynamicContractsData['MissionMetadata'] ?? {};
  final DateTime weeklyRefillTime =
      DateTime.tryParse(missionMetadata['WeeklyRefillTime'] ?? '') ??
      DateTime.now();
  final weeklyResetSeconds = weeklyRefillTime
      .difference(DateTime.now())
      .inSeconds
      .clamp(0, 9999999);

  final playerMissions = dynamicContractsData['Missions'] as List? ?? [];
  final List<MissionProgress> activeWeekly = [];
  int completedDailies = 0;
  DateTime? dailyExpiration;

  int asInt(dynamic value, [int fallback = 0]) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  for (var pm in playerMissions) {
    final String id = pm['ID'] ?? '';
    final bool complete = pm['Complete'] ?? false;
    final String expStr = pm['ExpirationTime'] ?? '';
    final DateTime expTime = DateTime.tryParse(expStr) ?? DateTime.now();

    final staticData = staticMissions[id];
    if (staticData == null) continue;

    final String type = staticData['type'] ?? '';
    final String title = staticData['title'] ?? 'Mission';
    final int xp = staticData['xpGrant'] ?? 0;

    final objectives = pm['Objectives'] as Map? ?? {};
    final staticObjectives = staticData['objectives'] as List? ?? [];
    int progressVal = 0;
    int targetVal = 1;

    if (staticObjectives.isNotEmpty) {
      final objUuid = staticObjectives[0]['objectiveUuid'];
      progressVal = asInt(objectives[objUuid]);
      targetVal = asInt(
        staticData['progressToComplete'] ?? staticObjectives[0]['value'],
        1,
      );
    }

    final mission = MissionProgress(
      id: id,
      title: formatMissionTitle(title, targetVal),
      type: type,
      xpGrant: xp,
      progress: progressVal,
      progressToComplete: targetVal,
      isComplete: complete,
      expirationTime: expTime,
    );

    if (type.contains('Daily')) {
      if (dailyExpiration == null || expTime.isBefore(dailyExpiration)) {
        dailyExpiration = expTime;
      }
      if (complete) {
        completedDailies++;
      }
    } else if (type.contains('Weekly')) {
      activeWeekly.add(mission);
    }
  }

  final now = DateTime.now().toUtc();
  var nextDailyCheckpointReset = DateTime.utc(now.year, now.month, now.day, 20);
  if (!nextDailyCheckpointReset.isAfter(now)) {
    nextDailyCheckpointReset = nextDailyCheckpointReset.add(
      const Duration(days: 1),
    );
  }

  final dailyResetSeconds = (dailyExpiration ?? nextDailyCheckpointReset)
      .difference(DateTime.now())
      .inSeconds
      .clamp(0, 9999999);

  final int activeDailyCheckpoints = completedDailies.clamp(0, 4);
  final activeMissionsIds = playerMissions
      .map((pm) => pm['ID'] as String)
      .toSet();
  final List<Map<String, dynamic>> allFutureWeeklies = [];

  DateTime actStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime actEndDate = DateTime.now().add(const Duration(days: 49));
  String activeActUuid = '';

  if (seasonsRes.statusCode == 200) {
    try {
      final json = jsonDecode(seasonsRes.body);
      final List seasonsList = json['data'] ?? [];
      final now = DateTime.now();

      final activeAct = seasonsList.firstWhere((s) {
        if (s['type'] != 'EAresSeasonType::Act' && s['type'] != 'EA_Act') {
          return false;
        }
        final start = DateTime.tryParse(s['startTime'] ?? '');
        final end = DateTime.tryParse(s['endTime'] ?? '');
        if (start != null && end != null) {
          return now.isAfter(start) && now.isBefore(end);
        }
        return false;
      }, orElse: () => null);

      if (activeAct != null) {
        activeActUuid = activeAct['uuid'];
        actStartDate =
            DateTime.tryParse(activeAct['startTime'] ?? '') ?? actStartDate;
        actEndDate =
            DateTime.tryParse(activeAct['endTime'] ?? '') ?? actEndDate;
      }
    } catch (_) {}
  }

  staticMissions.forEach((uuid, data) {
    final String type = data['type'] ?? '';
    final String activationDateStr = data['activationDate'] ?? '';
    final DateTime? activationDate = DateTime.tryParse(activationDateStr);

    if (type.contains('Weekly') && activationDate != null) {
      if (activationDate.isAfter(actStartDate) &&
          activationDate.isBefore(actEndDate)) {
        if (!activeMissionsIds.contains(uuid) &&
            activationDate.isAfter(DateTime.now())) {
          final objectives = data['objectives'] as List? ?? [];
          final firstObjective = objectives.isNotEmpty
              ? objectives.first as Map?
              : null;
          final target = asInt(
            data['progressToComplete'] ?? firstObjective?['value'],
          );
          allFutureWeeklies.add({
            ...data,
            'displayTitle': formatMissionTitle(
              data['title']?.toString() ?? 'Mission',
              target,
            ),
          });
        }
      }
    }
  });

  final Map<int, List<Map<String, dynamic>>> futureWeeklyMissions = {};
  for (var fWeekly in allFutureWeeklies) {
    final activationDate = DateTime.parse(fWeekly['activationDate']);
    final differenceDays = activationDate.difference(DateTime.now()).inDays;
    final int weeksOffset = (differenceDays / 7).ceil().clamp(1, 10);

    futureWeeklyMissions.putIfAbsent(weeksOffset, () => []).add(fWeekly);
  }

  Map<String, String> resolveReward(String type, String uuid) {
    String name = 'Reward';
    String icon = '';

    if (type.contains('Skin')) {
      final meta = skins[uuid];
      name = meta?.displayName ?? 'Weapon Skin';
      icon =
          meta?.displayIcon ??
          'https://media.valorant-api.com/weapons/skins/$uuid/displayicon.png';
    } else if (type.contains('Card')) {
      final item = cards[uuid];
      name = item?['displayName'] ?? 'Player Card';
      icon =
          item?['largeArt'] ??
          item?['displayIcon'] ??
          'https://media.valorant-api.com/playercards/$uuid/displayicon.png';
    } else if (type.contains('Spray')) {
      final item = sprays[uuid];
      name = item?['displayName'] ?? 'Spray';
      icon =
          item?['displayIcon'] ??
          'https://media.valorant-api.com/sprays/$uuid/displayicon.png';
    } else if (type.contains('Charm')) {
      final item = buddies[uuid];
      name = item?['displayName'] ?? 'Gun Buddy';
      icon =
          item?['displayIcon'] ??
          'https://media.valorant-api.com/buddies/$uuid/displayicon.png';
    } else if (type.contains('Title')) {
      final item = titles[uuid];
      name = item?['titleText'] ?? 'Title';
      icon =
          'https://media.valorant-api.com/playertitles/$uuid/displayicon.png';
    } else if (type.contains('Currency')) {
      if (uuid == '85ca954a-41f2-ce94-9b45-8ca3dd39a00d') {
        name = 'Kingdom Credits';
        icon = 'https://media.valorant-api.com/currencies/85ca954a-41f2-ce94-9b45-8ca3dd39a00d/displayicon.png';
      } else {
        name = 'Credits';
        icon =
            'https://media.valorant-api.com/currencies/$uuid/displayicon.png';
      }
    }
    return {'name': name, 'icon': icon};
  }

  final playerContracts = dynamicContractsData['Contracts'] as List? ?? [];
  PassProgress? battlePass;
  PassProgress? eventPass;
  final List<PassProgress> seasonPassCandidates = [];
  final Map<String, Map<String, int>> passXpTotals = {};

  final playableAgentIds = playableAgents.keys
      .map((id) => id.toString().toLowerCase())
      .toSet();
  final ownedAgentIds = agentEntitlements
      .map((entitlement) => (entitlement as Map?)?['ItemID']?.toString())
      .whereType<String>()
      .map((id) => id.toLowerCase())
      .where(playableAgentIds.contains)
      .toSet();

  final int totalAgentUnlocked = ownedAgentIds.length;
  int totalAgentCompleted = 0;
  int currentAgentProgressXp = 0;
  int currentAgentTotalXp = 100000;

  for (var pc in playerContracts) {
    final String defId = pc['ContractDefinitionID'] ?? '';
    final int reachedLevel = pc['ProgressionLevelReached'] ?? 0;
    final int towardsNext = pc['ProgressionTowardsNextLevel'] ?? 0;

    final staticDef = staticContracts[defId];
    if (staticDef == null) continue;

    final String displayName = staticDef['displayName'] ?? 'Contract';
    final content = staticDef['content'] ?? {};
    final String relationType = content['relationType'] ?? '';

    final List chapters = content['chapters'] as List? ?? [];
    int totalLevelsCount = 0;
    final List<Map<String, dynamic>> allLevels = [];

    for (var ch in chapters) {
      final List lvls = ch['levels'] as List? ?? [];
      totalLevelsCount += lvls.length;
      for (var l in lvls) {
        allLevels.add(l);
      }
    }

    if (allLevels.isEmpty) continue;

    final int currentLvlIndex = reachedLevel.clamp(0, allLevels.length - 1);
    final nextLevelXp = allLevels[currentLvlIndex]['xp'] as int? ?? 10000;
    final percentage = nextLevelXp > 0
        ? (towardsNext / nextLevelXp) * 100
        : 0.0;

    final activeLevelReward = allLevels[currentLvlIndex]['reward'] ?? {};
    final rewType = activeLevelReward['type'] ?? '';
    final rewUuid = activeLevelReward['uuid'] ?? '';
    final resolvedReward = resolveReward(rewType, rewUuid);

    final DateTime bpExpDate = actEndDate;

    if (relationType == 'Season' || relationType == 'Event') {
      int totalXpEarnedInPass = 0;
      for (int i = 0; i < currentLvlIndex; i++) {
        totalXpEarnedInPass += (allLevels[i]['xp'] as int? ?? 0);
      }
      totalXpEarnedInPass += towardsNext;

      int totalXpForFullPass = 0;
      for (var lvl in allLevels) {
        totalXpForFullPass += (lvl['xp'] as int? ?? 0);
      }

      passXpTotals[defId] = {
        'earned': totalXpEarnedInPass,
        'total': totalXpForFullPass,
      };
    }

    final progress = PassProgress(
      contractId: defId,
      displayName: displayName,
      currentLevel: reachedLevel,
      totalLevels: totalLevelsCount,
      currentLevelXp: towardsNext,
      nextLevelXpNeeded: nextLevelXp,
      percentage: percentage,
      activeRewardName: resolvedReward['name'],
      activeRewardIcon: resolvedReward['icon'],
      activeRewardType: rewType,
      expirationTime: bpExpDate,
    );

    if (relationType == 'Season') {
      seasonPassCandidates.add(progress);
      if (activeActUuid.isNotEmpty &&
          content['relationUuid'] == activeActUuid) {
        battlePass = progress;
      }
    } else if (relationType == 'Event') {
      eventPass = progress;
    } else if (relationType == 'Agent') {
      if (reachedLevel == 10) {
        totalAgentCompleted++;
      }

      final bool isActive = pc['IsActive'] ?? false;
      if (isActive) {
        currentAgentProgressXp =
            pc['ContractProgression']?['TotalProgressionEarned'] ?? 0;
        int totalXpNeeded = 0;
        for (var lvl in allLevels) {
          totalXpNeeded += (lvl['xp'] as int? ?? 0);
        }
        currentAgentTotalXp = totalXpNeeded > 0 ? totalXpNeeded : 1219000;
      }
    }
  }

  if (battlePass == null && seasonPassCandidates.isNotEmpty) {
    battlePass = seasonPassCandidates.last;
  }

  if (battlePass != null) {
    final totals = passXpTotals[battlePass.contractId];
    if (totals != null) {
      final earned = totals['earned'] ?? 0;
      final total = totals['total'] ?? 0;
      final remaining = (total - earned).clamp(0, total);
      try {
        await XpForecastService.recordSnapshot(battlePass.contractId, earned);
        final forecast = await XpForecastService.computeForecast(
          battlePass.contractId,
          remainingXp: remaining,
        );
        battlePass = battlePass.copyWith(forecast: forecast);
      } catch (e) {
        LoggerService.log(
          'XP forecast computation failed: $e',
          tag: 'Contracts',
        );
      }
    }
  }

  int kingdomCredits = currentUser.kingdomCredits ?? user.kingdomCredits ?? 0;

  final agentContracts = AgentContractsData(
    unlockedCount: totalAgentUnlocked,
    completedCount: totalAgentCompleted,
    totalAgents: playableAgentIds.length,
    currentProgressXp: currentAgentProgressXp,
    totalNeededXp: currentAgentTotalXp,
    kingdomCreditsBalance: kingdomCredits,
  );

  final List<RecentMatchXp> recentXpHistory = [];
  final processedMatches =
      dynamicContractsData['ProcessedMatches'] as List? ?? [];

  for (var pm in processedMatches) {
    final String id = pm['ID'] ?? '';
    final int startTimeMs = pm['StartTime'] ?? 0;
    final DateTime matchTime = DateTime.fromMillisecondsSinceEpoch(startTimeMs);

    final xpGrants = pm['XPGrants'] ?? {};
    final int gamePlayed = xpGrants['GamePlayed'] ?? 0;
    final int gameWon = xpGrants['GameWon'] ?? 0;
    final int roundPlayed = xpGrants['RoundPlayed'] ?? 0;
    final int roundWon = xpGrants['RoundWon'] ?? 0;
    final int missionsXp = (xpGrants['Missions'] as Map? ?? {}).values.fold(
      0,
      (sum, val) => sum + ((val as num).toInt()),
    );
    final int modifier = xpGrants['Modifier']?['Value'] ?? 0;

    final int totalXp =
        gamePlayed + gameWon + roundPlayed + roundWon + missionsXp + modifier;
    final timePlayedXp = gamePlayed + roundPlayed + roundWon + modifier;

    final Map<String, int> breakdown = {'Time Played': timePlayedXp};
    if (gameWon > 0) {
      breakdown['Match Win'] = gameWon;
    }
    if (missionsXp > 0) {
      breakdown['Missions'] = missionsXp;
    }

    recentXpHistory.add(
      RecentMatchXp(
        matchId: id,
        matchTime: matchTime,
        totalXp: totalXp,
        xpBreakdown: breakdown,
      ),
    );
  }

  LoggerService.log(
    'Processed contracts data: dailies=$activeDailyCheckpoints, activeWeeklies=${activeWeekly.length}, futureWeeklies=${allFutureWeeklies.length}, battlePass=${battlePass?.displayName ?? "none"}, eventPass=${eventPass?.displayName ?? "none"}, agents=${agentContracts.unlockedCount}/${agentContracts.totalAgents}',
    tag: 'Contracts',
  );

  return ContractsData(
    activeDailyCheckpoints: activeDailyCheckpoints,
    dailyResetSeconds: dailyResetSeconds,
    weeklyResetSeconds: weeklyResetSeconds,
    activeWeeklyMissions: activeWeekly,
    futureWeeklyMissions: futureWeeklyMissions,
    battlePass: battlePass,
    eventPass: eventPass,
    agentContracts: agentContracts,
    recentXpHistory: recentXpHistory,
  );
});
