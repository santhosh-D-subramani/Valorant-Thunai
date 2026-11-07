import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/services/valorant_api.dart';
import 'package:valorant_thunai/services/logger_service.dart';

final loadoutProvider =
    AsyncNotifierProvider<LoadoutNotifier, Map<String, dynamic>>(
      LoadoutNotifier.new,
    );

final entitlementsProvider = FutureProvider.family<List<dynamic>, String>((
  ref,
  itemTypeIds,
) async {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null || user.puuid.isEmpty || authState.hasSessionExpired) {
    return [];
  }

  final ids = itemTypeIds.split(',');
  final api = ValorantApi(ref);

  List<dynamic> allEntitlements = [];
  for (String id in ids) {
    if (id.trim().isEmpty) continue;
    try {
      final res = await api.getEntitlements(
        user.puuid,
        user.shard,
        user.accessToken,
        user.entitlementsToken,
        id.trim(),
      );
      allEntitlements.addAll(res);
    } catch (e) {
      LoggerService.log(
        'Failed to fetch entitlement for $id: $e',
        tag: 'LoadoutProvider',
      );
    }
  }

  return allEntitlements;
});

class LoadoutNotifier extends AsyncNotifier<Map<String, dynamic>> {
  @override
  FutureOr<Map<String, dynamic>> build() async {
    return _fetchLoadout();
  }

  Future<Map<String, dynamic>> _fetchLoadout() async {
    try {
      await ref.read(authProvider.notifier).checkAndRefreshSession();
    } catch (e) {
      LoggerService.log(
        'checkAndRefreshSession notice: $e',
        tag: 'LoadoutProvider',
      );
    }

    final authState = ref.read(authProvider);
    final user = authState.user;

    if (user == null || user.puuid.isEmpty || authState.hasSessionExpired) {
      LoggerService.log(
        'Auth check failed: user=${user?.gameName}, puuid=${user?.puuid}, expired=${authState.hasSessionExpired}',
        tag: 'LoadoutProvider',
      );
      throw Exception('User not authenticated or session expired');
    }

    LoggerService.log(
      'Fetching loadout for ${user.gameName}#${user.tagline} (PUUID: ${user.puuid}, Shard: ${user.shard}, Region: ${user.region})',
      tag: 'LoadoutProvider',
    );

    try {
      final loadout = await ValorantApi(ref).getPlayerLoadout(
        user.puuid,
        user.shard,
        user.accessToken,
        user.entitlementsToken,
      );
      final guns = (loadout['Guns'] as List?)?.length ?? 0;
      final sprays = (loadout['Sprays'] as List?)?.length ?? 0;
      final title = loadout['Identity']?['PlayerTitleID'];
      final card = loadout['Identity']?['PlayerCardID'];
      LoggerService.log(
        'Loadout retrieved successfully: Guns=$guns, Sprays=$sprays, Card=$card, Title=$title',
        tag: 'LoadoutProvider',
      );
      return loadout;
    } catch (e, st) {
      LoggerService.log(
        'Failed to fetch loadout: $e\nStack: $st',
        tag: 'LoadoutProvider',
      );
      rethrow;
    }
  }

  Future<void> fetchLoadout() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchLoadout());
  }

  Future<void> updateLoadout(Map<String, dynamic> newLoadout) async {
    final authState = ref.read(authProvider);
    final user = authState.user;

    if (user == null || user.puuid.isEmpty || authState.hasSessionExpired) {
      return;
    }

    final previousState = state;
    state = AsyncValue.data(newLoadout);

    try {
      await ValorantApi(ref).updatePlayerLoadout(
        user.puuid,
        user.shard,
        user.accessToken,
        user.entitlementsToken,
        newLoadout,
      );
      LoggerService.log('Loadout updated successfully', tag: 'LoadoutProvider');
    } catch (e) {
      LoggerService.log('Failed to update loadout: $e', tag: 'LoadoutProvider');
      state = previousState;
      rethrow;
    }
  }

  Future<void> equipSkin(
    String weaponId,
    String skinId,
    String skinLevelId,
    String chromaId,
  ) async {
    final currentLoadout = state.value;
    if (currentLoadout == null) return;

    final updatedLoadout = Map<String, dynamic>.from(currentLoadout);
    final List<dynamic> guns = List<dynamic>.from(updatedLoadout['Guns'] ?? []);

    for (int i = 0; i < guns.length; i++) {
      if ((guns[i]['ID'] as String).toLowerCase() == weaponId.toLowerCase()) {
        final gun = Map<String, dynamic>.from(guns[i]);
        gun['SkinID'] = skinId;
        gun['SkinLevelID'] = skinLevelId;
        gun['ChromaID'] = chromaId;
        guns[i] = gun;
        break;
      }
    }

    updatedLoadout['Guns'] = guns;
    await updateLoadout(updatedLoadout);
  }

  Future<void> equipBuddy(
    String weaponId,
    String charmId,
    String charmLevelId,
    String charmInstanceId,
  ) async {
    final currentLoadout = state.value;
    if (currentLoadout == null) return;

    final updatedLoadout = Map<String, dynamic>.from(currentLoadout);
    final List<dynamic> guns = List<dynamic>.from(updatedLoadout['Guns'] ?? []);

    for (int i = 0; i < guns.length; i++) {
      if ((guns[i]['ID'] as String).toLowerCase() == weaponId.toLowerCase()) {
        final gun = Map<String, dynamic>.from(guns[i]);
        gun['CharmID'] = charmId;
        gun['CharmLevelID'] = charmLevelId;
        gun['CharmInstanceID'] = charmInstanceId;
        guns[i] = gun;
        break;
      }
    }

    updatedLoadout['Guns'] = guns;
    await updateLoadout(updatedLoadout);
  }

  Future<void> equipTitle(String titleId) async {
    final currentLoadout = state.value;
    if (currentLoadout == null) return;

    final updatedLoadout = Map<String, dynamic>.from(currentLoadout);
    final identity = Map<String, dynamic>.from(
      updatedLoadout['Identity'] ?? {},
    );
    identity['PlayerTitleID'] = titleId;
    updatedLoadout['Identity'] = identity;

    await updateLoadout(updatedLoadout);
  }

  Future<void> equipCard(String cardId) async {
    final currentLoadout = state.value;
    if (currentLoadout == null) return;

    final updatedLoadout = Map<String, dynamic>.from(currentLoadout);
    final identity = Map<String, dynamic>.from(
      updatedLoadout['Identity'] ?? {},
    );
    identity['PlayerCardID'] = cardId;
    updatedLoadout['Identity'] = identity;

    await updateLoadout(updatedLoadout);
  }

  Future<void> equipSpray(String equipSlotId, String sprayId) async {
    final currentLoadout = state.value;
    if (currentLoadout == null) return;

    final updatedLoadout = Map<String, dynamic>.from(currentLoadout);

    final List<dynamic> sprays = List<dynamic>.from(
      updatedLoadout['Sprays'] ?? [],
    );
    bool foundSpray = false;
    for (int i = 0; i < sprays.length; i++) {
      if (sprays[i]['EquipSlotID'] == equipSlotId) {
        final spray = Map<String, dynamic>.from(sprays[i]);
        spray['SprayID'] = sprayId;
        sprays[i] = spray;
        foundSpray = true;
        break;
      }
    }
    if (!foundSpray) {
      sprays.add({
        'EquipSlotID': equipSlotId,
        'SprayID': sprayId,
        'SprayLevelID': null,
      });
    }
    updatedLoadout['Sprays'] = sprays;

    final List<dynamic> activeExpressions = List<dynamic>.from(
      updatedLoadout['ActiveExpressions'] ?? [],
    );
    int targetIdx = -1;
    if (equipSlotId == '0814b2fe-4512-60a4-5288-1fbdcec6ca48') {
      targetIdx = 0;
    } else if (equipSlotId == '04af080a-4071-487b-61c0-5b9c0cfaac74') {
      targetIdx = 1;
    } else if (equipSlotId == '5863985e-43ac-b05d-cb2d-139e72970014') {
      targetIdx = 2;
    } else if (equipSlotId == 'ec989a55-442a-5a9e-c852-510067ffbb3b') {
      targetIdx = 3;
    }

    if (targetIdx >= 0) {
      while (activeExpressions.length <= targetIdx) {
        activeExpressions.add({
          'TypeID': 'd5f120f8-ff8c-4aac-92ea-f2b5acbe9475',
          'AssetID': '00000000-0000-0000-0000-000000000000',
        });
      }
      activeExpressions[targetIdx] = {
        'TypeID': 'd5f120f8-ff8c-4aac-92ea-f2b5acbe9475',
        'AssetID': sprayId,
      };
      updatedLoadout['ActiveExpressions'] = activeExpressions;
    }

    await updateLoadout(updatedLoadout);
  }
}
