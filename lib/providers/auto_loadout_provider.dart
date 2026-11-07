import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_thunai/models/auto_loadout_rule.dart';
import 'package:valorant_thunai/models/loadout_preset.dart';
import 'package:valorant_thunai/providers/preset_provider.dart';
import 'package:valorant_thunai/services/logger_service.dart';

class AutoLoadoutState {
  final List<AutoLoadoutRule> rules;
  final bool autoEquipEnabled;
  final String? lastAppliedRuleSummary;
  final DateTime? lastAppliedTimestamp;
  final AutoLoadoutConflict? pendingConflict;
  final AutoLoadoutConflictPreference conflictPreference;

  const AutoLoadoutState({
    this.rules = const [],
    this.autoEquipEnabled = true,
    this.lastAppliedRuleSummary,
    this.lastAppliedTimestamp,
    this.pendingConflict,
    this.conflictPreference = AutoLoadoutConflictPreference.ask,
  });

  AutoLoadoutState copyWith({
    List<AutoLoadoutRule>? rules,
    bool? autoEquipEnabled,
    String? lastAppliedRuleSummary,
    DateTime? lastAppliedTimestamp,
    AutoLoadoutConflict? pendingConflict,
    bool clearPendingConflict = false,
    AutoLoadoutConflictPreference? conflictPreference,
  }) {
    return AutoLoadoutState(
      rules: rules ?? this.rules,
      autoEquipEnabled: autoEquipEnabled ?? this.autoEquipEnabled,
      lastAppliedRuleSummary:
          lastAppliedRuleSummary ?? this.lastAppliedRuleSummary,
      lastAppliedTimestamp: lastAppliedTimestamp ?? this.lastAppliedTimestamp,
      pendingConflict: clearPendingConflict
          ? null
          : (pendingConflict ?? this.pendingConflict),
      conflictPreference: conflictPreference ?? this.conflictPreference,
    );
  }
}

final autoLoadoutProvider =
    AsyncNotifierProvider<AutoLoadoutNotifier, AutoLoadoutState>(
      AutoLoadoutNotifier.new,
    );

class AutoLoadoutNotifier extends AsyncNotifier<AutoLoadoutState> {
  static const _rulesKey = 'val_shop_auto_loadout_rules_v1';
  static const _enabledKey = 'val_shop_auto_loadout_enabled_v1';
  static const _conflictPreferenceKey =
      'val_shop_auto_loadout_conflict_preference_v1';

  String? _lastTriggerKey;
  String? _lastAppliedMatchId;
  String? _lastAppliedPresetId;

  @override
  FutureOr<AutoLoadoutState> build() async {
    return _loadState();
  }

  Future<AutoLoadoutState> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_rulesKey);
    final autoEnabled = prefs.getBool(_enabledKey) ?? true;
    final conflictPreference = _parseConflictPreference(
      prefs.getString(_conflictPreferenceKey),
    );

    List<AutoLoadoutRule> rules = [];
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List decoded = jsonDecode(jsonStr);
        rules = decoded
            .map(
              (item) =>
                  AutoLoadoutRule.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      } catch (e) {
        LoggerService.log(
          'Error parsing auto loadout rules: $e',
          tag: 'AutoLoadout',
        );
      }
    }

    return AutoLoadoutState(
      rules: rules,
      autoEquipEnabled: autoEnabled,
      conflictPreference: conflictPreference,
    );
  }

  static AutoLoadoutConflictPreference _parseConflictPreference(String? raw) {
    switch (raw) {
      case 'preferAgent':
        return AutoLoadoutConflictPreference.preferAgent;
      case 'preferMap':
        return AutoLoadoutConflictPreference.preferMap;
      default:
        return AutoLoadoutConflictPreference.ask;
    }
  }

  Future<void> _persistState(AutoLoadoutState s) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(s.rules.map((r) => r.toJson()).toList());
    await prefs.setString(_rulesKey, jsonStr);
    await prefs.setBool(_enabledKey, s.autoEquipEnabled);
    await prefs.setString(_conflictPreferenceKey, s.conflictPreference.name);
  }

  Future<void> toggleAutoEquip(bool enabled) async {
    final current = state.value ?? const AutoLoadoutState();
    final updated = current.copyWith(autoEquipEnabled: enabled);
    state = AsyncValue.data(updated);
    await _persistState(updated);
  }

  Future<void> setConflictPreference(AutoLoadoutConflictPreference pref) async {
    final current = state.value ?? const AutoLoadoutState();
    final updated = current.copyWith(conflictPreference: pref);
    state = AsyncValue.data(updated);
    await _persistState(updated);
  }

  Future<void> saveRule(AutoLoadoutRule rule) async {
    final current = state.value ?? const AutoLoadoutState();
    final existingIndex = current.rules.indexWhere((r) => r.id == rule.id);

    List<AutoLoadoutRule> updatedRules;
    if (existingIndex >= 0) {
      updatedRules = List.from(current.rules)..[existingIndex] = rule;
    } else {
      updatedRules = [...current.rules, rule];
    }

    final updated = current.copyWith(rules: updatedRules);
    state = AsyncValue.data(updated);
    await _persistState(updated);
  }

  Future<void> deleteRule(String ruleId) async {
    final current = state.value ?? const AutoLoadoutState();
    final updatedRules = current.rules.where((r) => r.id != ruleId).toList();
    final updated = current.copyWith(rules: updatedRules);
    state = AsyncValue.data(updated);
    await _persistState(updated);
  }

  Future<void> toggleRuleEnabled(String ruleId, bool enabled) async {
    final current = state.value ?? const AutoLoadoutState();
    final updatedRules = current.rules.map((r) {
      if (r.id == ruleId) {
        return r.copyWith(isEnabled: enabled);
      }
      return r;
    }).toList();
    final updated = current.copyWith(rules: updatedRules);
    state = AsyncValue.data(updated);
    await _persistState(updated);
  }

  AutoLoadoutRule? _findAgentRule(
    List<AutoLoadoutRule> rules,
    String normalizedChar,
  ) {
    if (normalizedChar.isEmpty) return null;
    try {
      return rules.firstWhere(
        (r) =>
            r.isEnabled &&
            r.triggerType == AutoLoadoutTriggerType.agent &&
            (r.targetId.toLowerCase().trim() == normalizedChar ||
                r.targetName.toLowerCase().trim() == normalizedChar),
      );
    } catch (_) {
      return null;
    }
  }

  AutoLoadoutRule? _findMapRule(
    List<AutoLoadoutRule> rules,
    String normalizedMap,
  ) {
    if (normalizedMap.isEmpty) return null;
    try {
      return rules.firstWhere(
        (r) =>
            r.isEnabled &&
            r.triggerType == AutoLoadoutTriggerType.map &&
            (r.targetId.toLowerCase().trim() == normalizedMap ||
                r.targetName.toLowerCase().trim() == normalizedMap ||
                normalizedMap.contains(r.targetName.toLowerCase().trim())),
      );
    } catch (_) {
      return null;
    }
  }

  Future<LoadoutPreset?> _resolvePreset(
    List<LoadoutPreset> presets,
    AutoLoadoutRule rule,
  ) async {
    try {
      return presets.firstWhere((p) => p.id == rule.presetId);
    } catch (_) {
      try {
        return presets.firstWhere(
          (p) => p.name.toLowerCase() == rule.presetName.toLowerCase(),
        );
      } catch (_) {
        return null;
      }
    }
  }

  Future<bool> _applyResolved(
    AutoLoadoutState currentState,
    AutoLoadoutRule matchedRule,
    LoadoutPreset targetPreset,
    String? matchId,
  ) async {
    final ruleTypeLabel =
        matchedRule.triggerType == AutoLoadoutTriggerType.agent
        ? 'Agent'
        : 'Map';

    if (matchId != null &&
        matchId == _lastAppliedMatchId &&
        targetPreset.id == _lastAppliedPresetId) {
      if (currentState.pendingConflict != null) {
        state = AsyncValue.data(
          currentState.copyWith(clearPendingConflict: true),
        );
      }
      return false;
    }

    try {
      LoggerService.log(
        'Auto-applying preset "${targetPreset.name}" for ${matchedRule.triggerType.name} "${matchedRule.targetName}"...',
        tag: 'AutoLoadout',
      );

      await ref.read(presetsProvider.notifier).applyPresetToGame(targetPreset);
      _lastAppliedMatchId = matchId;
      _lastAppliedPresetId = targetPreset.id;

      final summary =
          'Applied "${targetPreset.name}" — $ruleTypeLabel rule: ${matchedRule.targetName}';
      state = AsyncValue.data(
        currentState.copyWith(
          lastAppliedRuleSummary: summary,
          lastAppliedTimestamp: DateTime.now(),
          clearPendingConflict: true,
        ),
      );
      return true;
    } catch (e) {
      LoggerService.log('Error auto-applying preset: $e', tag: 'AutoLoadout');
      return false;
    }
  }

  Future<bool> checkAndApplyAutoLoadout({
    required String? mapId,
    required String? characterId,
    String? matchId,
  }) async {
    final currentState = state.value;
    if (currentState == null || !currentState.autoEquipEnabled) {
      return false;
    }

    if (currentState.rules.isEmpty) {
      return false;
    }

    final normalizedMap = (mapId ?? '').toLowerCase().trim();
    final normalizedChar = (characterId ?? '').toLowerCase().trim();

    if (normalizedMap.isEmpty && normalizedChar.isEmpty) {
      return false;
    }

    final triggerKey = '$matchId:$normalizedMap:$normalizedChar';
    if (_lastTriggerKey == triggerKey) {
      return false;
    }
    _lastTriggerKey = triggerKey;

    final agentRule = _findAgentRule(currentState.rules, normalizedChar);
    final mapRule = _findMapRule(currentState.rules, normalizedMap);

    if (agentRule == null && mapRule == null) {
      if (currentState.pendingConflict != null) {
        state = AsyncValue.data(
          currentState.copyWith(clearPendingConflict: true),
        );
      }
      return false;
    }

    final presets = await ref.read(presetsProvider.future);
    final agentPreset = agentRule != null
        ? await _resolvePreset(presets, agentRule)
        : null;
    final mapPreset = mapRule != null
        ? await _resolvePreset(presets, mapRule)
        : null;

    if (agentRule != null &&
        mapRule != null &&
        agentPreset != null &&
        mapPreset != null &&
        agentPreset.id != mapPreset.id) {
      switch (currentState.conflictPreference) {
        case AutoLoadoutConflictPreference.preferAgent:
          LoggerService.log(
            'AutoLoadout conflict: Agent "${agentRule.targetName}" -> "${agentPreset.name}" vs Map "${mapRule.targetName}" -> "${mapPreset.name}" — auto-resolved to Agent per saved preference',
            tag: 'AutoLoadout',
          );
          return _applyResolved(currentState, agentRule, agentPreset, matchId);
        case AutoLoadoutConflictPreference.preferMap:
          LoggerService.log(
            'AutoLoadout conflict: Agent "${agentRule.targetName}" -> "${agentPreset.name}" vs Map "${mapRule.targetName}" -> "${mapPreset.name}" — auto-resolved to Map per saved preference',
            tag: 'AutoLoadout',
          );
          return _applyResolved(currentState, mapRule, mapPreset, matchId);
        case AutoLoadoutConflictPreference.ask:
          final latest = state.value ?? currentState;
          state = AsyncValue.data(
            latest.copyWith(
              pendingConflict: AutoLoadoutConflict(
                matchId: matchId,
                agentRule: agentRule,
                agentPresetName: agentPreset.name,
                mapRule: mapRule,
                mapPresetName: mapPreset.name,
              ),
            ),
          );
          LoggerService.log(
            'AutoLoadout conflict: Agent "${agentRule.targetName}" -> "${agentPreset.name}" vs Map "${mapRule.targetName}" -> "${mapPreset.name}" — waiting for user choice',
            tag: 'AutoLoadout',
          );
          return false;
      }
    }

    final matchedRule = agentRule ?? mapRule!;
    final targetPreset = agentPreset ?? mapPreset;

    if (targetPreset == null) {
      LoggerService.log(
        'AutoLoadout matched rule "${matchedRule.targetName}" but preset "${matchedRule.presetName}" not found',
        tag: 'AutoLoadout',
      );
      return false;
    }

    return _applyResolved(currentState, matchedRule, targetPreset, matchId);
  }

  Future<void> resolveConflict(bool chooseAgentRule) async {
    final currentState = state.value;
    final conflict = currentState?.pendingConflict;
    if (currentState == null || conflict == null) return;

    final chosenRule = chooseAgentRule ? conflict.agentRule : conflict.mapRule;
    final presets = await ref.read(presetsProvider.future);
    final targetPreset = await _resolvePreset(presets, chosenRule);
    if (targetPreset == null) {
      state = AsyncValue.data(
        currentState.copyWith(clearPendingConflict: true),
      );
      return;
    }

    try {
      await ref.read(presetsProvider.notifier).applyPresetToGame(targetPreset);
      _lastAppliedMatchId = conflict.matchId;
      _lastAppliedPresetId = targetPreset.id;

      final ruleTypeLabel = chooseAgentRule ? 'Agent' : 'Map';
      state = AsyncValue.data(
        currentState.copyWith(
          lastAppliedRuleSummary:
              'Applied "${targetPreset.name}" — $ruleTypeLabel rule: ${chosenRule.targetName} (you chose)',
          lastAppliedTimestamp: DateTime.now(),
          clearPendingConflict: true,
        ),
      );
    } catch (e) {
      LoggerService.log(
        'Error applying chosen conflict preset: $e',
        tag: 'AutoLoadout',
      );
    }
  }

  void dismissConflict() {
    final currentState = state.value;
    if (currentState == null || currentState.pendingConflict == null) return;
    state = AsyncValue.data(currentState.copyWith(clearPendingConflict: true));
  }

  AutoLoadoutPreviewResult previewMatch({String? mapName, String? agentName}) {
    final currentState = state.value ?? const AutoLoadoutState();
    final normalizedMap = (mapName ?? '').toLowerCase().trim();
    final normalizedAgent = (agentName ?? '').toLowerCase().trim();

    final agentRule = _findAgentRule(currentState.rules, normalizedAgent);
    final mapRule = _findMapRule(currentState.rules, normalizedMap);

    if (agentRule != null &&
        mapRule != null &&
        agentRule.presetId != mapRule.presetId) {
      switch (currentState.conflictPreference) {
        case AutoLoadoutConflictPreference.preferAgent:
          return AutoLoadoutPreviewResult(rule: agentRule);
        case AutoLoadoutConflictPreference.preferMap:
          return AutoLoadoutPreviewResult(rule: mapRule);
        case AutoLoadoutConflictPreference.ask:
          return AutoLoadoutPreviewResult(
            conflictAgentRule: agentRule,
            conflictMapRule: mapRule,
          );
      }
    }

    return AutoLoadoutPreviewResult(rule: agentRule ?? mapRule);
  }

  Future<void> applyRulePreset(AutoLoadoutRule rule) async {
    final presets = await ref.read(presetsProvider.future);
    final targetPreset = presets.firstWhere(
      (p) => p.id == rule.presetId || p.name == rule.presetName,
      orElse: () => throw Exception(
        'Preset "${rule.presetName}" was deleted or not found.',
      ),
    );

    await ref.read(presetsProvider.notifier).applyPresetToGame(targetPreset);

    final current = state.value ?? const AutoLoadoutState();
    state = AsyncValue.data(
      current.copyWith(
        lastAppliedRuleSummary:
            'Manually applied "${targetPreset.name}" (${rule.targetName})',
        lastAppliedTimestamp: DateTime.now(),
      ),
    );
  }
}
