import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/providers/contracts_provider.dart';
import 'package:valorant_thunai/providers/skin_provider.dart';
import 'package:valorant_thunai/services/logger_service.dart';
import 'package:valorant_thunai/services/valorant_api.dart';

class AgentGearReward {
  final int tier;
  final String type;
  final String name;
  final String icon;
  final int kingdomCreditsCost;
  final bool isComplete;

  AgentGearReward({
    required this.tier,
    required this.type,
    required this.name,
    required this.icon,
    required this.kingdomCreditsCost,
    required this.isComplete,
  });
}

class AgentGearProgress {
  final String agentUuid;
  final String agentName;
  final String agentIcon;
  final String contractDisplayName;
  final int completedTiers;
  final int totalTiers;
  final int kingdomCreditsRemaining;
  final List<AgentGearReward> rewards;

  AgentGearProgress({
    required this.agentUuid,
    required this.agentName,
    required this.agentIcon,
    required this.contractDisplayName,
    required this.completedTiers,
    required this.totalTiers,
    required this.kingdomCreditsRemaining,
    required this.rewards,
  });

  bool get isMaxed => totalTiers > 0 && completedTiers >= totalTiers;
}

const _agentGearAgentItemTypeId = '01bb38e1-da47-4e6a-9b3d-945fe4655707';

final agentGearProvider = FutureProvider<List<AgentGearProgress>>((ref) async {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null || authState.hasSessionExpired) {
    return [];
  }

  final api = ref.read(valorantApiProvider);

  try {
    await ref.read(authProvider.notifier).checkAndRefreshSession();
  } catch (e) {
    LoggerService.log('checkAndRefreshSession notice: $e', tag: 'AgentGear');
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
    LoggerService.log('getContracts failed: $e', tag: 'AgentGear');
    try {
      await ref.read(authProvider.notifier).checkAndRefreshSession(force: true);
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
        tag: 'AgentGear',
      );
    }
  }

  if (dynamicContractsData.isEmpty) return [];

  final results = await Future.wait<dynamic>(<Future<dynamic>>[
    ref.watch(staticContractsProvider.future).catchError((e) {
      return <String, dynamic>{};
    }),
    ref.watch(playableAgentsProvider.future).catchError((e) {
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
    api
        .getEntitlements(
          currentUser.puuid,
          currentUser.shard,
          currentUser.accessToken,
          currentUser.entitlementsToken,
          _agentGearAgentItemTypeId,
        )
        .catchError((e) {
          return <dynamic>[];
        }),
  ]);

  final staticContracts = results[0] as Map<String, dynamic>;
  final playableAgents = results[1] as Map<String, dynamic>;
  final skins = results[2] as Map<String, SkinMetadata>;
  final cards = results[3] as Map<String, dynamic>;
  final buddies = results[4] as Map<String, dynamic>;
  final sprays = results[5] as Map<String, dynamic>;
  final titles = results[6] as Map<String, dynamic>;

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

  final Map<String, Map<String, dynamic>> agentContractDefs = {};
  staticContracts.forEach((defId, def) {
    final content = def['content'] ?? {};
    if (content['relationType'] == 'Agent') {
      final relationUuid = content['relationUuid']?.toString();
      if (relationUuid != null) {
        agentContractDefs[relationUuid.toLowerCase()] = {...def, 'uuid': defId};
      }
    }
  });

  final playerContracts = dynamicContractsData['Contracts'] as List? ?? [];
  final Map<String, Map<String, dynamic>> progressByDefId = {
    for (final pc in playerContracts)
      if (pc is Map && pc['ContractDefinitionID'] != null)
        pc['ContractDefinitionID'].toString(): Map<String, dynamic>.from(pc),
  };

  final List<AgentGearProgress> result = [];

  for (final entry in playableAgents.entries) {
    final agentUuid = entry.key.toString();
    final agentData = entry.value as Map? ?? {};
    final agentName = agentData['displayName']?.toString() ?? 'Agent';
    final agentIcon =
        agentData['displayIconSmall']?.toString() ??
        agentData['displayIcon']?.toString() ??
        '';

    final def = agentContractDefs[agentUuid.toLowerCase()];
    if (def == null) continue;

    final content = def['content'] ?? {};
    final chapters = content['chapters'] as List? ?? [];
    final List<Map<String, dynamic>> allLevels = [];
    for (final ch in chapters) {
      final lvls = ch['levels'] as List? ?? [];
      for (final l in lvls) {
        if (l is Map) allLevels.add(Map<String, dynamic>.from(l));
      }
    }
    if (allLevels.isEmpty) continue;

    final defId = def['uuid'].toString();
    final playerProgress = progressByDefId[defId];
    final int reachedLevel = playerProgress != null
        ? (playerProgress['ProgressionLevelReached'] as int? ?? 0)
        : 0;

    int kcRemaining = 0;
    final List<AgentGearReward> rewards = [];
    for (int i = 0; i < allLevels.length; i++) {
      final lvl = allLevels[i];
      final bool isComplete = i < reachedLevel;
      final int doughCost = lvl['doughCost'] as int? ?? 0;
      if (!isComplete) {
        kcRemaining += doughCost;
      }
      final reward = lvl['reward'] ?? {};
      final String rewType = reward['type']?.toString() ?? '';
      final String rewUuid = reward['uuid']?.toString() ?? '';
      final resolved = resolveReward(rewType, rewUuid);

      rewards.add(
        AgentGearReward(
          tier: i + 1,
          type: rewType,
          name: resolved['name'] ?? 'Reward',
          icon: resolved['icon'] ?? '',
          kingdomCreditsCost: doughCost,
          isComplete: isComplete,
        ),
      );
    }

    result.add(
      AgentGearProgress(
        agentUuid: agentUuid,
        agentName: agentName,
        agentIcon: agentIcon,
        contractDisplayName:
            def['displayName']?.toString() ?? '$agentName Gear',
        completedTiers: reachedLevel.clamp(0, allLevels.length),
        totalTiers: allLevels.length,
        kingdomCreditsRemaining: kcRemaining,
        rewards: rewards,
      ),
    );
  }

  result.sort((a, b) => a.agentName.compareTo(b.agentName));

  return result;
});
