import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'auth_provider.dart';
import 'contracts_provider.dart';
import 'skin_provider.dart';

import 'package:valorant_thunai/services/valorant_api.dart';
import 'package:valorant_thunai/services/logger_service.dart';

class BattlepassReward {
  final String type;
  final String uuid;
  final int amount;
  final String name;
  final String icon;

  BattlepassReward({
    required this.type,
    required this.uuid,
    required this.amount,
    required this.name,
    required this.icon,
  });
}

class BattlepassTier {
  final int levelIndex;
  final int tierNumber;
  final String chapterName;
  final bool isEpilogue;
  final int xpRequired;
  final BattlepassReward? freeReward;
  final BattlepassReward? premiumReward;
  final bool isUnlocked;

  BattlepassTier({
    required this.levelIndex,
    required this.tierNumber,
    required this.chapterName,
    required this.isEpilogue,
    required this.xpRequired,
    required this.freeReward,
    required this.premiumReward,
    required this.isUnlocked,
  });
}

class BattlepassData {
  final String contractId;
  final String displayName;
  final List<BattlepassTier> tiers;
  final int currentLevel;
  final int currentLevelXp;
  final bool hasPremium;

  BattlepassData({
    required this.contractId,
    required this.displayName,
    required this.tiers,
    required this.currentLevel,
    required this.currentLevelXp,
    required this.hasPremium,
  });
}

const _agentContractRelation = 'Agent';

final battlepassProvider = FutureProvider<BattlepassData?>((ref) async {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null || authState.hasSessionExpired) {
    return null;
  }

  final api = ref.read(valorantApiProvider);

  final results = await Future.wait<dynamic>(<Future<dynamic>>[
    ref.watch(staticContractsProvider.future).catchError((e) {
      LoggerService.log(
        'battlepassProvider staticContracts error: $e',
        tag: 'Battlepass',
      );
      return <String, dynamic>{};
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
    http.get(Uri.parse('https://valorant-api.com/v1/seasons')).catchError((e) {
      LoggerService.log(
        'battlepassProvider seasons error: $e',
        tag: 'Battlepass',
      );
      return http.Response('{}', 400);
    }),
  ]);

  final staticContracts = results[0] as Map<String, dynamic>;
  final skins = results[1] as Map<String, SkinMetadata>;
  final cards = results[2] as Map<String, dynamic>;
  final buddies = results[3] as Map<String, dynamic>;
  final sprays = results[4] as Map<String, dynamic>;
  final titles = results[5] as Map<String, dynamic>;
  final seasonsRes = results[6] as http.Response;

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
      }
    } catch (_) {}
  }

  Map<String, dynamic> dynamicContractsData = {};
  try {
    await ref.read(authProvider.notifier).checkAndRefreshSession();
    final currentUser = ref.read(authProvider).user ?? user;
    dynamicContractsData = await api.getContracts(
      shard: currentUser.shard,
      puuid: currentUser.puuid,
      accessToken: currentUser.accessToken,
      entitlementsToken: currentUser.entitlementsToken,
    );
  } catch (e) {
    LoggerService.log(
      'battlepassProvider getContracts error: $e',
      tag: 'Battlepass',
    );
  }

  final playerContracts = dynamicContractsData['Contracts'] as List? ?? [];

  Map<String, dynamic>? activeContractRaw;
  Map<String, dynamic>? activeStaticDef;
  String activeDefId = '';

  for (final pc in playerContracts) {
    final defId = pc['ContractDefinitionID'] ?? '';
    final staticDef = staticContracts[defId];
    if (staticDef == null) continue;
    final content = staticDef['content'] ?? {};
    final relationType = content['relationType'] ?? '';
    if (relationType == _agentContractRelation) continue;
    if (relationType == 'Season') {
      if (activeActUuid.isNotEmpty &&
          content['relationUuid'] == activeActUuid) {
        activeContractRaw = pc;
        activeStaticDef = staticDef;
        activeDefId = defId;
        break;
      }
      activeContractRaw = pc;
      activeStaticDef = staticDef;
      activeDefId = defId;
    }
  }

  if (activeStaticDef == null) {
    for (final entry in staticContracts.entries) {
      final content = entry.value['content'] ?? {};
      if (content['relationType'] == 'Season') {
        activeStaticDef = entry.value;
        activeDefId = entry.key;
      }
    }
  }

  if (activeStaticDef == null) return null;

  final content = activeStaticDef['content'] ?? {};
  final List chapters = content['chapters'] as List? ?? [];
  final String displayName = activeStaticDef['displayName'] ?? 'Battlepass';

  final int reachedLevel = activeContractRaw?['ProgressionLevelReached'] ?? 0;
  final int towardsNext =
      activeContractRaw?['ProgressionTowardsNextLevel'] ?? 0;

  bool hasPremium = false;
  if (activeContractRaw != null) {
    for (final key in [
      'IsOwned',
      'Owned',
      'IsPremiumOwned',
      'HasPremiumRewardSchedule',
    ]) {
      final v = activeContractRaw[key];
      if (v == true) {
        hasPremium = true;
        break;
      }
    }
  }

  BattlepassReward? resolveReward(Map? reward) {
    if (reward == null) return null;
    final String type = reward['type'] ?? '';
    final String uuid = reward['uuid'] ?? '';
    final int amount = reward['amount'] is num
        ? (reward['amount'] as num).toInt()
        : 1;
    if (type.isEmpty || uuid.isEmpty) return null;

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
      } else {
        name = 'Credits';
      }
      icon = 'https://media.valorant-api.com/currencies/$uuid/displayicon.png';
    }

    return BattlepassReward(
      type: type,
      uuid: uuid,
      amount: amount,
      name: name,
      icon: icon,
    );
  }

  final List<BattlepassTier> tiers = [];
  int levelIndex = 0;
  for (final ch in chapters) {
    final String chapterName = (ch['isEpilogue'] == true)
        ? 'Epilogue'
        : 'Chapter';
    final bool isEpilogue = ch['isEpilogue'] == true;
    final List levels = ch['levels'] as List? ?? [];
    for (final lvl in levels) {
      final int xp =
          lvl['xp'] as int? ?? lvl['doughAmountRequired'] as int? ?? 0;
      final reward = lvl['reward'] as Map?;
      final rewards = lvl['rewards'] as List?;

      BattlepassReward? freeReward = resolveReward(reward);
      BattlepassReward? premiumReward;

      if (rewards != null && rewards.isNotEmpty) {
        freeReward ??= resolveReward(rewards.first as Map?);
        if (rewards.length > 1) {
          premiumReward = resolveReward(rewards[1] as Map?);
        }
      }

      tiers.add(
        BattlepassTier(
          levelIndex: levelIndex,
          tierNumber: levelIndex + 1,
          chapterName: chapterName,
          isEpilogue: isEpilogue,
          xpRequired: xp,
          freeReward: freeReward,
          premiumReward: premiumReward,
          isUnlocked: levelIndex < reachedLevel,
        ),
      );
      levelIndex++;
    }
  }

  return BattlepassData(
    contractId: activeDefId,
    displayName: displayName,
    tiers: tiers,
    currentLevel: reachedLevel,
    currentLevelXp: towardsNext,
    hasPremium: hasPremium,
  );
});
