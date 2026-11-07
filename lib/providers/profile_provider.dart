import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/services/valorant_api.dart';
import 'package:valorant_thunai/services/logger_service.dart';
import 'package:valorant_thunai/services/rank_history_service.dart';

final competitiveTiersProvider = FutureProvider<Map<int, dynamic>>((ref) async {
  final tiersData = await ValorantApi.getCompetitiveTiers();
  final episode5AndUp = tiersData.lastWhere(
    (tierSet) => tierSet['uuid'] == '564d8e28-c226-3180-6285-e19a31071cb2',
    orElse: () => tiersData.last,
  );

  final Map<int, dynamic> tierMap = {};
  for (var tier in episode5AndUp['tiers']) {
    tierMap[tier['tier']] = tier;
  }
  return tierMap;
});

final titlesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final titlesData = await ValorantApi.getTitles();
  final Map<String, dynamic> titleMap = {};
  for (var title in titlesData) {
    titleMap[title['uuid']] = title;
  }
  return titleMap;
});

final agentsMapProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final agentsData = await ValorantApi.getAgents();
  final Map<String, dynamic> agentMap = {};
  for (var agent in agentsData) {
    final uuid = agent['uuid']?.toString().toLowerCase();
    if (uuid != null) {
      agentMap[uuid] = agent;
    }
  }
  return agentMap;
});

final mapsMapProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final mapsData = await ValorantApi.getMaps();
  final Map<String, dynamic> mapDict = {};
  for (var map in mapsData) {
    final mapPath = map['mapUrl']?.toString().toLowerCase();
    if (mapPath != null) {
      mapDict[mapPath] = map;
    }
    final uuid = map['uuid']?.toString().toLowerCase();
    if (uuid != null) {
      mapDict[uuid] = map;
    }
  }
  return mapDict;
});

class ActiveActInfo {
  final String uuid;
  final String name;
  final DateTime? endTime;
  final List<String> henrikSeasonKeys;

  const ActiveActInfo({
    required this.uuid,
    required this.name,
    this.endTime,
    this.henrikSeasonKeys = const [],
  });
}

class CurrentCompetitiveRank {
  final bool isCurrentlyRanked;
  final int currentTier;
  final int currentRR;
  final int gamesNeededForRating;
  final int? previousActTier;
  final bool old;
  final String? currentActSeasonKey;
  final bool currentActSeasonFound;

  const CurrentCompetitiveRank({
    required this.isCurrentlyRanked,
    required this.currentTier,
    required this.currentRR,
    required this.gamesNeededForRating,
    this.previousActTier,
    this.old = false,
    this.currentActSeasonKey,
    this.currentActSeasonFound = false,
  });
}

class AccountXpGrant {
  final int amount;
  final String source;
  final DateTime? timestamp;

  const AccountXpGrant({
    required this.amount,
    required this.source,
    this.timestamp,
  });
}

class AccountXpSummary {
  static const int defaultXpPerLevel = 5000;

  final int level;
  final int xp;
  final int xpToNextLevel;
  final List<AccountXpGrant> recentGrants;

  const AccountXpSummary({
    required this.level,
    required this.xp,
    required this.xpToNextLevel,
    required this.recentGrants,
  });

  double get progress =>
      xpToNextLevel <= 0 ? 0 : (xp / xpToNextLevel).clamp(0, 1).toDouble();

  int get xpRemaining => (xpToNextLevel - xp).clamp(0, xpToNextLevel);

  factory AccountXpSummary.fromJson(Map<String, dynamic> raw) {
    final Map progress = (raw['Progress'] as Map?) ?? const {};
    final int level = (progress['Level'] as num?)?.toInt() ?? 0;
    final int xp = (progress['XP'] as num?)?.toInt() ?? 0;

    final List historyRaw = (raw['History'] as List?) ?? const [];
    final List<AccountXpGrant> grants = [];
    for (final entry in historyRaw) {
      if (entry is! Map) continue;

      final num amountRaw =
          (entry['XPGrantAmount'] ?? entry['Amount'] ?? entry['XP'] ?? 0)
              as num;

      final String source =
          (entry['XPSourceOverride'] ??
                  entry['Source'] ??
                  entry['XPSource'] ??
                  entry['Context'] ??
                  'match')
              .toString();

      DateTime? timestamp;
      final dynamic rawTime =
          entry['MatchStart'] ??
          entry['Timestamp'] ??
          entry['GameStart'] ??
          entry['TimeSinceGrant'];
      if (rawTime is String) {
        timestamp = DateTime.tryParse(rawTime);
      } else if (rawTime is num) {
        timestamp = rawTime > 1000000000000
            ? DateTime.fromMillisecondsSinceEpoch(rawTime.toInt())
            : DateTime.now().subtract(Duration(milliseconds: rawTime.toInt()));
      }

      if (amountRaw == 0 && source == 'match' && timestamp == null) {
        continue;
      }

      grants.add(
        AccountXpGrant(
          amount: amountRaw.toInt(),
          source: source,
          timestamp: timestamp,
        ),
      );
    }

    grants.sort((a, b) {
      if (a.timestamp == null && b.timestamp == null) return 0;
      if (a.timestamp == null) return 1;
      if (b.timestamp == null) return -1;
      return b.timestamp!.compareTo(a.timestamp!);
    });

    return AccountXpSummary(
      level: level,
      xp: xp,
      xpToNextLevel: AccountXpSummary.defaultXpPerLevel,
      recentGrants: grants,
    );
  }
}

class ProfileData {
  final Map<String, dynamic> accountXp;
  final Map<String, dynamic>? henrikMmr;
  final Map<int, dynamic> competitiveTiers;
  final Map<String, dynamic> titles;
  final String? liveTitleId;
  final String activeSeasonName;
  final DateTime? activeActEndTime;
  final Map<String, dynamic>? penalties;
  final bool isCurrentlyRanked;
  final int currentTier;
  final int currentRR;
  final int gamesNeededForRating;
  final int? previousActTier;

  ProfileData({
    required this.accountXp,
    required this.henrikMmr,
    required this.competitiveTiers,
    required this.titles,
    this.liveTitleId,
    this.activeSeasonName = '',
    this.activeActEndTime,
    this.penalties,
    this.isCurrentlyRanked = false,
    this.currentTier = 0,
    this.currentRR = 0,
    this.gamesNeededForRating = 0,
    this.previousActTier,
  });

  AccountXpSummary get xpSummary => AccountXpSummary.fromJson(accountXp);
}

final activeActProvider = FutureProvider<ActiveActInfo?>((ref) async {
  try {
    final seasonsRes = await http.get(
      Uri.parse('https://valorant-api.com/v1/seasons'),
    );
    if (seasonsRes.statusCode != 200) return null;
    final json = jsonDecode(seasonsRes.body);
    final List seasons = json['data'] ?? [];
    return parseActiveActFromSeasons(seasons);
  } catch (_) {
    return null;
  }
});

int _asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? _parseActNumber(String displayName) {
  final upper = displayName.toUpperCase().trim();
  const romans = {
    'VIII': 8,
    'VII': 7,
    'III': 3,
    'II': 2,
    'IV': 4,
    'VI': 6,
    'IX': 9,
    'I': 1,
    'V': 5,
    'X': 10,
  };
  for (final entry in romans.entries) {
    if (RegExp('ACT\\s+${entry.key}\\b').hasMatch(upper) ||
        upper == 'ACT ${entry.key}' ||
        upper.endsWith(' ${entry.key}')) {
      return entry.value;
    }
  }
  final numeric = RegExp(r'ACT\s+(\d+)').firstMatch(upper);
  if (numeric != null) return int.tryParse(numeric.group(1)!);
  return null;
}

bool _isActSeason(dynamic season) {
  final type = season?['type']?.toString() ?? '';
  return type == 'EAresSeasonType::Act' || type == 'EA_Act';
}

ActiveActInfo? parseActiveActFromSeasons(List seasons) {
  final now = DateTime.now();
  final activeAct = seasons.cast<dynamic>().firstWhere((s) {
    if (!_isActSeason(s)) return false;
    final start = DateTime.tryParse(s['startTime'] ?? '');
    final end = DateTime.tryParse(s['endTime'] ?? '');
    if (start != null && end != null) {
      return now.isAfter(start) && now.isBefore(end);
    }
    return false;
  }, orElse: () => null);

  if (activeAct == null) return null;

  final parentEp = seasons.cast<dynamic>().firstWhere(
    (s) => s['uuid'] == activeAct['parentUuid'],
    orElse: () => null,
  );

  String activeSeasonName = '';
  if (activeAct['title'] != null && activeAct['title'].toString().isNotEmpty) {
    activeSeasonName = activeAct['title'].toString().toUpperCase();
  } else if (parentEp != null) {
    final epName = parentEp['displayName'].toString().replaceAll(
      'EPISODE',
      'EP',
    );
    final actName = activeAct['displayName'].toString().replaceAll(
      'ACT',
      'ACT',
    );
    activeSeasonName = '$epName || $actName'.toUpperCase();
  } else {
    activeSeasonName = activeAct['displayName'].toString().toUpperCase();
  }

  final uuid = activeAct['uuid']?.toString() ?? '';
  final parentUuid = activeAct['parentUuid']?.toString() ?? '';
  final parentName = parentEp?['displayName']?.toString() ?? '';
  final title = activeAct['title']?.toString() ?? '';
  final displayName = activeAct['displayName']?.toString() ?? '';

  final siblingActs =
      seasons
          .where(
            (s) => _isActSeason(s) && s['parentUuid']?.toString() == parentUuid,
          )
          .toList()
        ..sort((a, b) {
          final aStart = DateTime.tryParse(a['startTime'] ?? '') ?? DateTime(0);
          final bStart = DateTime.tryParse(b['startTime'] ?? '') ?? DateTime(0);
          return aStart.compareTo(bStart);
        });
  final actIndexInParent = siblingActs.indexWhere(
    (s) => s['uuid']?.toString() == uuid,
  );

  final parents = seasons.where((s) => !_isActSeason(s)).toList()
    ..sort((a, b) {
      final aStart = DateTime.tryParse(a['startTime'] ?? '') ?? DateTime(0);
      final bStart = DateTime.tryParse(b['startTime'] ?? '') ?? DateTime(0);
      return aStart.compareTo(bStart);
    });

  int maxEpisode = 0;
  int syntheticEpisode = 0;
  for (final parent in parents) {
    final name = parent['displayName']?.toString().toUpperCase() ?? '';
    final epMatch = RegExp(r'EPISODE\s+(\d+)').firstMatch(name);
    if (epMatch != null) {
      syntheticEpisode = int.parse(epMatch.group(1)!);
      if (syntheticEpisode > maxEpisode) maxEpisode = syntheticEpisode;
    } else if (name.startsWith('V') || name.startsWith('SEASON')) {
      maxEpisode += 1;
      syntheticEpisode = maxEpisode;
    }
    if (parent['uuid']?.toString() == parentUuid) break;
  }

  final actNum =
      _parseActNumber(displayName) ??
      (actIndexInParent >= 0 ? actIndexInParent + 1 : 1);
  final keys = <String>{
    if (uuid.isNotEmpty) uuid,
    if (uuid.isNotEmpty) uuid.toLowerCase(),
    if (syntheticEpisode > 0) 'e${syntheticEpisode}a$actNum',
    if (syntheticEpisode > 0 && actIndexInParent >= 0)
      'e${syntheticEpisode}a${actIndexInParent + 1}',
  };

  final vMatch = RegExp(
    r'V(\d{2})',
    caseSensitive: false,
  ).firstMatch(title.isNotEmpty ? title : parentName);
  if (vMatch != null) {
    keys.add('v${vMatch.group(1)}a$actNum');
    keys.add('V${vMatch.group(1)}a$actNum');
  }

  return ActiveActInfo(
    uuid: uuid,
    name: activeSeasonName,
    endTime: DateTime.tryParse(activeAct['endTime'] ?? ''),
    henrikSeasonKeys: keys.toList(),
  );
}

bool _isValidCurrentActRankEntry(dynamic entry) {
  if (entry == null || entry is! Map) return false;
  final map = Map<String, dynamic>.from(entry);
  final error = map['error'];
  if (error is String && error.isNotEmpty) return false;
  if (error == true) return false;
  return _asInt(map['final_rank'] ?? map['rank']) > 0;
}

CurrentCompetitiveRank resolveCurrentCompetitiveRank(
  Map<String, dynamic>? henrikMmr,
  ActiveActInfo? activeAct,
) {
  if (henrikMmr == null) {
    return const CurrentCompetitiveRank(
      isCurrentlyRanked: false,
      currentTier: 0,
      currentRR: 0,
      gamesNeededForRating: 0,
    );
  }

  final currentData = henrikMmr['current_data'] as Map?;
  final rawTier = _asInt(currentData?['currenttier']);
  final rawRR = _asInt(currentData?['ranking_in_tier']);
  final gamesNeeded = _asInt(currentData?['games_needed_for_rating']);
  final old = currentData?['old'] == true;

  final bySeasonRaw = henrikMmr['by_season'] ?? currentData?['by_season'];
  Map<String, dynamic> bySeason = {};
  if (bySeasonRaw is Map) {
    bySeason = bySeasonRaw.map((key, value) => MapEntry(key.toString(), value));
  }

  String? foundKey;
  dynamic foundEntry;
  if (activeAct != null) {
    for (final key in activeAct.henrikSeasonKeys) {
      if (bySeason.containsKey(key)) {
        foundKey = key;
        foundEntry = bySeason[key];
        break;
      }
    }
  }
  final currentActSeasonFound = foundKey != null;
  final hasValidCurrentActRank = _isValidCurrentActRankEntry(foundEntry);

  final isCurrentlyRanked = rawTier > 0 && gamesNeeded <= 0;

  LoggerService.log(
    'activeAct uuid=${activeAct?.uuid} name=${activeAct?.name} '
    'keys=${activeAct?.henrikSeasonKeys} '
    'currenttier=$rawTier ranking_in_tier=$rawRR '
    'games_needed_for_rating=$gamesNeeded old=$old '
    'by_season_key=$foundKey found=$currentActSeasonFound '
    'by_season_keys=${bySeason.keys.toList()} '
    'validCurrentActRank=$hasValidCurrentActRank '
    'isCurrentlyRanked=$isCurrentlyRanked',
    tag: 'CurrentRank',
  );

  if (!isCurrentlyRanked) {
    return CurrentCompetitiveRank(
      isCurrentlyRanked: false,
      currentTier: 0,
      currentRR: 0,
      gamesNeededForRating: gamesNeeded,
      previousActTier: rawTier > 0 ? rawTier : null,
      old: old,
      currentActSeasonKey: foundKey,
      currentActSeasonFound: currentActSeasonFound,
    );
  }

  return CurrentCompetitiveRank(
    isCurrentlyRanked: true,
    currentTier: rawTier,
    currentRR: rawRR,
    gamesNeededForRating: gamesNeeded,
    previousActTier: rawTier,
    old: old,
    currentActSeasonKey: foundKey,
    currentActSeasonFound: currentActSeasonFound,
  );
}

final profileProvider = FutureProvider<ProfileData?>((ref) async {
  final authState = ref.watch(authProvider);
  final user = authState.user;

  if (user == null || authState.hasSessionExpired) {
    return null;
  }

  final api = ref.read(valorantApiProvider);

  final results = await Future.wait([
    api
        .getAccountXp(
          shard: user.shard,
          puuid: user.puuid,
          accessToken: user.accessToken,
          entitlementsToken: user.entitlementsToken,
        )
        .catchError((_) => <String, dynamic>{}),
    ValorantApi.getHenrikMMR(user.region, user.puuid),
    ref.watch(competitiveTiersProvider.future),
    ref.watch(titlesProvider.future),

    http
        .get(
          Uri.parse(
            'https://pd.${user.shard}.a.pvp.net/personalization/v2/players/${user.puuid}/playerloadout',
          ),
          headers: {
            'X-Riot-Entitlements-JWT': user.entitlementsToken,
            'Authorization': 'Bearer ${user.accessToken}',
            'X-Riot-ClientPlatform': 'ew0KCSJwbGF0Zm9ybVR5cGUiOiAiUEMiLA0KCSJwbGF0Zm9ybU9TIjogIldpbmRvd3MiLA0KCSJwbGF0Zm9ybU9TVmVyc2lvbiI6ICIxMC4wLjE5MDQyLjEuMjU2LjY0Yml0IiwNCgkicGxhdGZvcm1DaGlwc2V0IjogIkludGVsIg0KfQ==',
            'X-Riot-ClientVersion': 'release-13.00-shipping-28-4928912',
          },
        )
        .catchError((_) => http.Response('{}', 400)),

    ref.watch(activeActProvider.future),

    api
        .getPenalties(
          shard: user.shard,
          puuid: user.puuid,
          accessToken: user.accessToken,
          entitlementsToken: user.entitlementsToken,
        )
        .catchError((error) {
          LoggerService.log('getPenalties failed: $error', tag: 'Profile');
          return <String, dynamic>{};
        }),
  ]);

  String? liveTitleId = user.titleId;
  final loadoutRes = results[4] as http.Response;
  if (loadoutRes.statusCode == 200) {
    try {
      final json = jsonDecode(loadoutRes.body);
      if (json['Identity'] != null) {
        liveTitleId = json['Identity']['PlayerTitleID'];
      }
    } catch (_) {}
  }

  final activeAct = results[5] as ActiveActInfo?;
  final henrikMmr = results[1] as Map<String, dynamic>?;
  final currentRank = resolveCurrentCompetitiveRank(henrikMmr, activeAct);

  if (currentRank.isCurrentlyRanked) {
    unawaited(
      RankHistoryService.recordRank(
        puuid: user.puuid,
        tier: currentRank.currentTier,
        rr: currentRank.currentRR,
      ),
    );
  }

  return ProfileData(
    accountXp: results[0] as Map<String, dynamic>,
    henrikMmr: henrikMmr,
    competitiveTiers: results[2] as Map<int, dynamic>,
    titles: results[3] as Map<String, dynamic>,
    liveTitleId: liveTitleId,
    activeSeasonName: activeAct?.name ?? '',
    activeActEndTime: activeAct?.endTime,
    penalties: results[6] as Map<String, dynamic>?,
    isCurrentlyRanked: currentRank.isCurrentlyRanked,
    currentTier: currentRank.currentTier,
    currentRR: currentRank.currentRR,
    gamesNeededForRating: currentRank.gamesNeededForRating,
    previousActTier: currentRank.previousActTier,
  );
});
