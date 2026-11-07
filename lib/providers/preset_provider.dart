import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_thunai/models/loadout_preset.dart';
import 'package:valorant_thunai/providers/loadout_provider.dart';
import 'package:valorant_thunai/providers/weapons_provider.dart';
import 'package:valorant_thunai/services/logger_service.dart';

final presetsProvider =
    AsyncNotifierProvider<LoadoutPresetsNotifier, List<LoadoutPreset>>(
      LoadoutPresetsNotifier.new,
    );

class LoadoutPresetsNotifier extends AsyncNotifier<List<LoadoutPreset>> {
  static const _prefsKey = 'val_shop_loadout_presets_v1';

  @override
  FutureOr<List<LoadoutPreset>> build() async {
    return _loadPresets();
  }

  Future<List<LoadoutPreset>> _loadPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefsKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }

    try {
      final List decoded = jsonDecode(jsonStr);
      return decoded
          .map(
            (item) => LoadoutPreset.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (e) {
      LoggerService.log('Error parsing presets: $e', tag: 'PresetProvider');
      return [];
    }
  }

  Future<void> _persistPresets(List<LoadoutPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(presets.map((p) => p.toJson()).toList());
    await prefs.setString(_prefsKey, jsonStr);
  }

  Future<void> savePreset(LoadoutPreset preset) async {
    final current = state.value ?? [];
    final trimmedName = preset.name.trim();

    final duplicateIndex = current.indexWhere(
      (p) =>
          p.id != preset.id &&
          p.name.trim().toLowerCase() == trimmedName.toLowerCase(),
    );

    if (duplicateIndex >= 0) {
      throw Exception(
        'A preset with the name "$trimmedName" already exists. Please choose a unique name.',
      );
    }

    final existingIndex = current.indexWhere((p) => p.id == preset.id);

    List<LoadoutPreset> updated;
    if (existingIndex >= 0) {
      updated = List.from(current)..[existingIndex] = preset;
    } else {
      updated = [preset, ...current];
    }

    state = AsyncValue.data(updated);
    await _persistPresets(updated);
  }

  Future<void> deletePreset(String id) async {
    final current = state.value ?? [];
    final updated = current.where((p) => p.id != id).toList();
    state = AsyncValue.data(updated);
    await _persistPresets(updated);
  }

  Future<LoadoutPreset?> saveCurrentAsPreset(String name) async {
    final currentLoadout = ref.read(loadoutProvider).value;
    if (currentLoadout == null) return null;

    final preset = LoadoutPreset.fromPlayerLoadout(
      name: name.trim().isEmpty ? 'My Loadout' : name.trim(),
      loadout: currentLoadout,
    );

    await savePreset(preset);
    return preset;
  }

  static const _titleEntitlementTypeId = 'de7caa6b-adf7-4588-bbd1-143831e786c6';
  static const _cardEntitlementTypeId = '3f296c07-64c3-494c-923b-fe692a4fa1bd';
  static const _sprayEntitlementTypeId = 'd5f120f8-ff8c-4aac-92ea-f2b5acbe9475';

  static const _sprayEquipSlotIds = [
    '0814b2fe-4512-60a4-5288-1fbdcec6ca48',
    '04af080a-4071-487b-61c0-5b9c0cfaac74',
    '5863985e-43ac-b05d-cb2d-139e72970014',
    'ec989a55-442a-5a9e-c852-510067ffbb3b',
  ];

  static const _defaultFlexIds = {
    '90f0a554-41b3-355b-6846-74a27aa3f7b9',
    'af52b5a0-4a4c-03b2-c9d7-8187a08a2675',
  };

  static const _noneFlexId = '90f0a554-41b3-355b-6846-74a27aa3f7b9';

  static const double _topSlotFlexChance = 0.70;
  static const double _otherSlotFlexChance = 0.10;

  Future<LoadoutPreset> generateRandomizedPreset({
    String name = 'Randomized Loadout',
    bool randomizeGuns = true,
    bool randomizeCard = false,
    bool randomizeSprays = false,
    bool randomizeTitle = false,
  }) async {
    final random = math.Random();
    final List<GunPresetItem> generatedGuns = [];

    if (randomizeGuns) {
      final weapons = await ref.read(weaponsProvider.future);

      final skinEntitlements = await ref.read(
        entitlementsProvider(
          'e7c63390-eda7-46e0-bb7a-a6abdacd2433,3ad1b2b2-acdb-4524-852f-954a76ddae0a',
        ).future,
      );
      final buddyEntitlements = await ref.read(
        entitlementsProvider('dd3bf334-87f3-40bd-b043-682a57a8dc3a').future,
      );
      final allBuddies = await ref.read(allBuddiesProvider.future);

      final Set<String> ownedSkinUuids = skinEntitlements
          .map(
            (e) => (e['ItemID'] ?? e['itemId'] ?? '').toString().toLowerCase(),
          )
          .toSet();

      final List<Map<String, dynamic>> availableBuddies = [];
      for (var b in allBuddies) {
        if (b is! Map<String, dynamic> && b is! Map) continue;
        final buddyUuid = (b['uuid'] ?? '').toString();
        final levels = b['levels'] as List? ?? [];
        for (var lvl in levels) {
          if (lvl is! Map) continue;
          final lvlUuid = (lvl['uuid'] ?? '').toString().toLowerCase();
          for (var ent in buddyEntitlements) {
            if (ent is! Map) continue;
            final itemId = (ent['ItemID'] ?? ent['itemId'] ?? '')
                .toString()
                .toLowerCase();
            if (itemId == lvlUuid) {
              availableBuddies.add({
                'charmId': buddyUuid,
                'charmLevelId': lvl['uuid'],
                'charmInstanceId':
                    ent['InstanceID'] ?? ent['instanceID'] ?? ent['instanceId'],
              });
            }
          }
        }
      }
      availableBuddies.shuffle(random);

      for (var weapon in weapons) {
        final weaponId = (weapon['uuid'] as String).toLowerCase();
        final defaultSkinUuid = (weapon['defaultSkinUuid'] ?? '')
            .toString()
            .toLowerCase();
        final weaponSkins = (weapon['skins'] as List? ?? []);
        final bool isMelee =
            (weapon['displayName'] ?? '').toString().toLowerCase() == 'melee' ||
            weaponId == '2f59173c-4bed-b6c3-2191-dea9b58be9c7';

        final List<Map<String, dynamic>> customOwnedSkins = [];

        for (var skin in weaponSkins) {
          final skinUuid = (skin['uuid'] ?? '').toString().toLowerCase();
          final displayName = (skin['displayName'] ?? '')
              .toString()
              .toLowerCase();

          final bool isDefaultSkin =
              displayName.startsWith('standard') ||
              displayName == 'melee' ||
              displayName == 'standard melee' ||
              displayName == 'none' ||
              (defaultSkinUuid.isNotEmpty && skinUuid == defaultSkinUuid);

          if (isDefaultSkin) continue;

          final levels = skin['levels'] as List? ?? [];
          final chromas = skin['chromas'] as List? ?? [];

          final eligibleLevels = levels
              .where(
                (l) =>
                    ownedSkinUuids.contains(
                      (l['uuid'] ?? '').toString().toLowerCase(),
                    ) ||
                    ownedSkinUuids.contains(skinUuid),
              )
              .toList();

          final eligibleChromas = chromas
              .where(
                (c) =>
                    ownedSkinUuids.contains(
                      (c['uuid'] ?? '').toString().toLowerCase(),
                    ) ||
                    ownedSkinUuids.contains(skinUuid),
              )
              .toList();

          final isOwned =
              ownedSkinUuids.contains(skinUuid) ||
              eligibleLevels.isNotEmpty ||
              eligibleChromas.isNotEmpty;

          if (isOwned) {
            customOwnedSkins.add({
              'skin': skin,
              'levels': eligibleLevels.isNotEmpty ? eligibleLevels : levels,
              'chromas': eligibleChromas.isNotEmpty ? eligibleChromas : chromas,
            });
          }
        }

        String chosenSkinId;
        String chosenLevelId;
        String chosenChromaId;

        if (customOwnedSkins.isNotEmpty) {
          final chosen =
              customOwnedSkins[random.nextInt(customOwnedSkins.length)];
          final skinData = chosen['skin'];
          final levelsList = chosen['levels'] as List;
          final chromasList = chosen['chromas'] as List;

          chosenSkinId = skinData['uuid'];
          chosenLevelId = levelsList.isNotEmpty
              ? levelsList.last['uuid']
              : chosenSkinId;
          chosenChromaId = chromasList.isNotEmpty
              ? chromasList[random.nextInt(chromasList.length)]['uuid']
              : chosenSkinId;
        } else {
          dynamic defaultSkin;
          if (defaultSkinUuid.isNotEmpty) {
            try {
              defaultSkin = weaponSkins.firstWhere(
                (s) =>
                    (s['uuid'] ?? '').toString().toLowerCase() ==
                    defaultSkinUuid,
              );
            } catch (_) {}
          }
          defaultSkin ??= weaponSkins.firstWhere((s) {
            final name = (s['displayName'] ?? '').toString().toLowerCase();
            return name.startsWith('standard') ||
                name == 'melee' ||
                name == 'none';
          }, orElse: () => weaponSkins.isNotEmpty ? weaponSkins.first : null);

          chosenSkinId = defaultSkin?['uuid'] ?? defaultSkinUuid;
          final defLevels = defaultSkin?['levels'] as List? ?? [];
          final defChromas = defaultSkin?['chromas'] as List? ?? [];
          chosenLevelId = defLevels.isNotEmpty
              ? defLevels[0]['uuid']
              : chosenSkinId;
          chosenChromaId = defChromas.isNotEmpty
              ? defChromas[0]['uuid']
              : chosenSkinId;
        }

        String? chosenCharmId;
        String? chosenCharmLevelId;
        String? chosenCharmInstanceId;

        if (!isMelee && availableBuddies.isNotEmpty) {
          final chosenBuddy = availableBuddies.removeAt(0);
          chosenCharmId = chosenBuddy['charmId'];
          chosenCharmLevelId = chosenBuddy['charmLevelId'];
          chosenCharmInstanceId = chosenBuddy['charmInstanceId'];
        }

        generatedGuns.add(
          GunPresetItem(
            id: weapon['uuid'],
            skinId: chosenSkinId,
            skinLevelId: chosenLevelId,
            chromaId: chosenChromaId,
            charmId: chosenCharmId,
            charmLevelId: chosenCharmLevelId,
            charmInstanceId: chosenCharmInstanceId,
          ),
        );
      }
    }

    Map<String, dynamic>? generatedIdentity;
    List<dynamic>? generatedSprays;

    if (randomizeCard) {
      final cardId = await _pickRandomOwnedItem(_cardEntitlementTypeId, random);
      if (cardId != null) {
        generatedIdentity = {...?generatedIdentity, 'PlayerCardID': cardId};
      }
    }

    if (randomizeTitle) {
      final titleId = await _pickRandomOwnedItem(
        _titleEntitlementTypeId,
        random,
      );
      if (titleId != null) {
        generatedIdentity = {...?generatedIdentity, 'PlayerTitleID': titleId};
      }
    }

    if (randomizeSprays) {
      final sprayEntitlements = await ref.read(
        entitlementsProvider(_sprayEntitlementTypeId).future,
      );
      final ownedIds = sprayEntitlements
          .map(
            (e) => (e['ItemID'] ?? e['itemId'] ?? '').toString().toLowerCase(),
          )
          .where((id) => id.isNotEmpty)
          .toSet();

      final allSprays = await ref.read(allSpraysProvider.future);
      final ownedSprayIds = <String>[];
      for (final spray in allSprays) {
        if (spray is! Map) continue;
        if (spray['category'] == 'EAresSprayCategory::Contextual') continue;
        final uuid = (spray['uuid'] ?? '').toString();
        if (uuid.isEmpty) continue;
        final displayName = (spray['displayName'] ?? '')
            .toString()
            .toLowerCase();
        if (displayName == 'none' || displayName == 'standard') continue;
        final levels = spray['levels'] as List? ?? [];
        final ownsLevel = levels.any(
          (l) =>
              l is Map &&
              ownedIds.contains((l['uuid'] ?? '').toString().toLowerCase()),
        );
        if (ownedIds.contains(uuid.toLowerCase()) || ownsLevel) {
          ownedSprayIds.add(uuid);
        }
      }

      final allFlexes = await ref.read(allFlexesProvider.future);
      final ownedFlexIds = <String>[];
      for (final flex in allFlexes) {
        if (flex is! Map) continue;
        final uuid = (flex['uuid'] ?? '').toString();
        if (uuid.isEmpty) continue;
        if (uuid.toLowerCase() == _noneFlexId) continue;
        if (_defaultFlexIds.contains(uuid.toLowerCase()) ||
            ownedIds.contains(uuid.toLowerCase())) {
          ownedFlexIds.add(uuid);
        }
      }

      if (ownedSprayIds.isNotEmpty || ownedFlexIds.isNotEmpty) {
        final remainingSprays = List<String>.from(ownedSprayIds);
        final remainingFlexes = List<String>.from(ownedFlexIds);

        String pickForSlot(double flexChance) {
          final useFlex =
              remainingFlexes.isNotEmpty &&
              (remainingSprays.isEmpty || random.nextDouble() < flexChance);
          final pool = useFlex ? remainingFlexes : remainingSprays;
          if (pool.isNotEmpty) {
            final index = random.nextInt(pool.length);
            return pool.removeAt(index);
          }
          final fallbackPool = useFlex ? remainingSprays : remainingFlexes;
          if (fallbackPool.isNotEmpty) {
            final index = random.nextInt(fallbackPool.length);
            return fallbackPool.removeAt(index);
          }
          final source = ownedSprayIds.isNotEmpty
              ? ownedSprayIds
              : ownedFlexIds;
          return source[random.nextInt(source.length)];
        }

        generatedSprays = [
          for (var i = 0; i < _sprayEquipSlotIds.length; i++)
            {
              'EquipSlotID': _sprayEquipSlotIds[i],
              'SprayID': pickForSlot(
                i == 0 ? _topSlotFlexChance : _otherSlotFlexChance,
              ),
              'SprayLevelID': null,
            },
        ];
      }
    }

    final preset = LoadoutPreset(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      createdAt: DateTime.now(),
      guns: generatedGuns,
      identity: generatedIdentity,
      sprays: generatedSprays,
    );

    return preset;
  }

  Future<String?> _pickRandomOwnedItem(
    String entitlementTypeId,
    math.Random random,
  ) async {
    final entitlements = await ref.read(
      entitlementsProvider(entitlementTypeId).future,
    );
    final ownedIds = entitlements
        .map((e) => (e['ItemID'] ?? e['itemId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();
    if (ownedIds.isEmpty) return null;
    return ownedIds[random.nextInt(ownedIds.length)];
  }

  Future<void> applyPresetToGame(LoadoutPreset preset) async {
    final currentLoadout = ref.read(loadoutProvider).value;
    if (currentLoadout == null) {
      throw Exception('Failed to get active in-game loadout');
    }

    final newLoadout = preset.toRiotLoadout(currentLoadout);
    await ref.read(loadoutProvider.notifier).updateLoadout(newLoadout);
  }
}
