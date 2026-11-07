import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/providers/navigation_provider.dart';
import 'package:valorant_thunai/models/match_models.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/services/valorant_api.dart';
import 'package:valorant_thunai/services/logger_service.dart';
import 'package:valorant_thunai/providers/player_match_stats_provider.dart';
import 'package:valorant_thunai/providers/auto_loadout_provider.dart';

export 'package:valorant_thunai/models/match_models.dart';
export 'package:valorant_thunai/providers/player_match_stats_provider.dart';

class PartyMember {
  final String puuid;
  final String gameName;
  final String tagLine;
  final String playerCardId;
  final int competitiveTier;
  final bool isReady;
  final bool isOwner;

  PartyMember({
    required this.puuid,
    required this.gameName,
    required this.tagLine,
    required this.playerCardId,
    required this.competitiveTier,
    required this.isReady,
    required this.isOwner,
  });
}

class PartyState {
  final PartyPhase phase;
  final String? partyId;
  final List<PartyMember> members;
  final String? queueId;
  final String? state;
  final String? queueEntryTime;
  final bool isLoading;
  final String? error;
  final String accessibility;
  final String? inviteCode;
  final List<String> preferredGamePods;
  final Map<String, String> availableGamePods;
  final Map<String, String> availableQueues;
  final PregameMatch? pregameMatch;
  final CurrentGameMatch? currentGameMatch;

  PartyState({
    this.phase = PartyPhase.idle,
    this.partyId,
    this.members = const [],
    this.queueId,
    this.state,
    this.queueEntryTime,
    this.isLoading = false,
    this.error,
    this.accessibility = 'CLOSED',
    this.inviteCode,
    this.preferredGamePods = const [],
    this.availableGamePods = const {},
    this.availableQueues = const {
      'unrated': 'Unrated',
      'competitive': 'Competitive',
      'swiftplay': 'Swiftplay',
      'spikerush': 'Spike Rush',
      'deathmatch': 'Deathmatch',
      'ggteam': 'Escalation',
      'hurm': 'Team Deathmatch',
      'fortcollins': 'Retake',
    },
    this.pregameMatch,
    this.currentGameMatch,
  });

  PartyState copyWith({
    PartyPhase? phase,
    String? partyId,
    List<PartyMember>? members,
    String? queueId,
    String? state,
    String? queueEntryTime,
    bool? isLoading,
    String? error,
    String? accessibility,
    String? inviteCode,
    bool clearInviteCode = false,
    List<String>? preferredGamePods,
    Map<String, String>? availableGamePods,
    Map<String, String>? availableQueues,
    PregameMatch? pregameMatch,
    bool clearPregameMatch = false,
    CurrentGameMatch? currentGameMatch,
    bool clearCurrentGameMatch = false,
    bool clearRawState = false,
  }) {
    return PartyState(
      phase: phase ?? this.phase,
      partyId: partyId ?? this.partyId,
      members: members ?? this.members,
      queueId: queueId ?? this.queueId,
      state: clearRawState ? null : (state ?? this.state),
      queueEntryTime: queueEntryTime ?? this.queueEntryTime,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      accessibility: accessibility ?? this.accessibility,
      inviteCode: clearInviteCode ? null : (inviteCode ?? this.inviteCode),
      preferredGamePods: preferredGamePods ?? this.preferredGamePods,
      availableGamePods: availableGamePods ?? this.availableGamePods,
      availableQueues: availableQueues ?? this.availableQueues,
      pregameMatch: clearPregameMatch
          ? null
          : (pregameMatch ?? this.pregameMatch),
      currentGameMatch: clearCurrentGameMatch
          ? null
          : (currentGameMatch ?? this.currentGameMatch),
    );
  }
}

class PartyNotifier extends Notifier<PartyState> {
  static const Duration _basePollInterval = Duration(seconds: 8);

  Timer? _pollTimer;
  int _consecutiveFailures = 0;
  Duration _currentInterval = _basePollInterval;
  bool _isFetching = false;
  bool _hasLoadedDynamicConfig = false;

  final Map<String, Map<String, String>> _nameCache = {};

  @override
  PartyState build() {
    ref.onDispose(() {
      _stopPolling();
    });

    final currentTab = ref.watch(currentTabProvider);
    ref.listen<int>(currentTabProvider, (previous, next) {
      if (next == AppTab.party.index) {
        _startPolling(immediate: true);
      } else {
        _stopPolling();
      }
    });

    if (currentTab == AppTab.party.index) {
      Future.microtask(() => _startPolling(immediate: true));
    }

    return PartyState();
  }

  void _startPolling({bool immediate = false}) {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (state.phase == PartyPhase.inMatch ||
        state.phase == PartyPhase.agentSelect) {
      LoggerService.log('Game polling started', tag: 'PartyProvider');
    } else {
      LoggerService.log('Party polling started', tag: 'PartyProvider');
    }

    if (immediate) {
      _pollTick();
    }

    _pollTimer = Timer.periodic(_currentInterval, (timer) {
      if (ref.read(currentTabProvider) == AppTab.party.index) {
        _pollTick();
      } else {
        _stopPolling();
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (state.phase == PartyPhase.inMatch ||
        state.phase == PartyPhase.agentSelect) {
      LoggerService.log('Game polling stopped', tag: 'PartyProvider');
    } else {
      LoggerService.log('Party polling stopped', tag: 'PartyProvider');
    }
  }

  void _transitionPhase(PartyPhase newPhase) {
    if (state.phase != newPhase) {
      LoggerService.log(
        'Party phase: ${state.phase.name} -> ${newPhase.name}',
        tag: 'PartyProvider',
      );
      state = state.copyWith(phase: newPhase);

      const targetInterval = _basePollInterval;

      if (_currentInterval != targetInterval) {
        _currentInterval = targetInterval;
        if (ref.read(currentTabProvider) == AppTab.party.index) {
          _startPolling();
        }
      }
    }
  }

  void _handleSuccess() {
    if (_consecutiveFailures > 0) {
      _consecutiveFailures = 0;
      _updateInterval(_basePollInterval);
    }
  }

  void _handleFailure() {
    _consecutiveFailures++;
    Duration newInterval;
    if (_consecutiveFailures <= 2) {
      newInterval = _basePollInterval;
    } else if (_consecutiveFailures <= 5) {
      newInterval = const Duration(seconds: 15);
    } else if (_consecutiveFailures <= 10) {
      newInterval = const Duration(seconds: 30);
    } else {
      newInterval = const Duration(seconds: 60);
    }

    if (newInterval != _currentInterval) {
      _updateInterval(newInterval);
    }
  }

  void _updateInterval(Duration duration) {
    _currentInterval = duration;
    LoggerService.log(
      'Updating party poll interval to ${_currentInterval.inSeconds}s (failures: $_consecutiveFailures)',
      tag: 'PartyProvider',
    );
    if (ref.read(currentTabProvider) == AppTab.party.index) {
      _startPolling();
    }
  }

  Future<void> _pollTick() async {
    if (_isFetching) return;
    if (ref.read(currentTabProvider) != AppTab.party.index) return;

    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null || authState.hasSessionExpired) {
      state = PartyState();
      return;
    }

    switch (state.phase) {
      case PartyPhase.idle:
        await _pollIdleState(user);
        break;
      case PartyPhase.matchmaking:
        await _pollMatchmakingState(user);
        break;
      case PartyPhase.agentSelect:
        await _pollAgentSelectState(user);
        break;
      case PartyPhase.inMatch:
        await _pollInMatchState(user);
        break;
    }
  }

  Future<void> _ensurePlayerNames(
    List<String> puuids,
    dynamic user,
    ValorantApi api,
  ) async {
    final missingPuuids = puuids
        .where((p) => p.isNotEmpty && !_nameCache.containsKey(p))
        .toList();
    if (missingPuuids.isNotEmpty) {
      try {
        final names = await api.fetchNamesByPuuids(
          missingPuuids,
          user.shard,
          user.accessToken,
          user.entitlementsToken,
        );
        _nameCache.addAll(names);
      } catch (e) {
        LoggerService.log(
          'Failed to fetch names for PUUIDs: $e',
          tag: 'PartyProvider',
        );
      }
    }
  }

  Future<void> _pollIdleState(dynamic user) async {
    _isFetching = true;
    final api = ref.read(valorantApiProvider);

    try {
      final pregamePlayer = await api.getPregamePlayer(
        user.puuid,
        user.accessToken,
        user.entitlementsToken,
        user.region,
        user.shard,
      );

      if (pregamePlayer != null && pregamePlayer['MatchID'] != null) {
        _transitionPhase(PartyPhase.agentSelect);
        await _fetchAndSetPregameMatch(pregamePlayer['MatchID'], user, api);
        _handleSuccess();
        return;
      }

      final coregamePlayer = await api.getCurrentGamePlayer(
        user.puuid,
        user.accessToken,
        user.entitlementsToken,
        user.region,
        user.shard,
      );

      if (coregamePlayer != null && coregamePlayer['MatchID'] != null) {
        _transitionPhase(PartyPhase.inMatch);
        await _fetchAndSetCurrentGameMatch(
          coregamePlayer['MatchID'],
          user,
          api,
        );
        _handleSuccess();
        return;
      }

      await _fetchPartyLobbyDetails(user, api);
      _handleSuccess();
    } catch (e) {
      LoggerService.log('Failed to poll idle party: $e', tag: 'PartyProvider');
      _handleFailure();
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _pollMatchmakingState(dynamic user) async {
    _isFetching = true;
    final api = ref.read(valorantApiProvider);

    try {
      final pregamePlayer = await api.getPregamePlayer(
        user.puuid,
        user.accessToken,
        user.entitlementsToken,
        user.region,
        user.shard,
      );

      if (pregamePlayer != null && pregamePlayer['MatchID'] != null) {
        final String matchId = pregamePlayer['MatchID'];
        _transitionPhase(PartyPhase.agentSelect);
        await _fetchAndSetPregameMatch(matchId, user, api);
        _handleSuccess();
        return;
      }

      final coregamePlayer = await api.getCurrentGamePlayer(
        user.puuid,
        user.accessToken,
        user.entitlementsToken,
        user.region,
        user.shard,
      );

      if (coregamePlayer != null && coregamePlayer['MatchID'] != null) {
        final String matchId = coregamePlayer['MatchID'];
        _transitionPhase(PartyPhase.inMatch);
        await _fetchAndSetCurrentGameMatch(matchId, user, api);
        _handleSuccess();
        return;
      }

      await _fetchPartyLobbyDetails(user, api);
      _handleSuccess();
    } catch (e) {
      LoggerService.log(
        'Failed to poll matchmaking state: $e',
        tag: 'PartyProvider',
      );
      _handleFailure();
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _pollAgentSelectState(dynamic user) async {
    _isFetching = true;
    final api = ref.read(valorantApiProvider);

    try {
      final pregamePlayer = await api.getPregamePlayer(
        user.puuid,
        user.accessToken,
        user.entitlementsToken,
        user.region,
        user.shard,
      );

      if (pregamePlayer != null && pregamePlayer['MatchID'] != null) {
        await _fetchAndSetPregameMatch(pregamePlayer['MatchID'], user, api);
      } else {
        final coregamePlayer = await api.getCurrentGamePlayer(
          user.puuid,
          user.accessToken,
          user.entitlementsToken,
          user.region,
          user.shard,
        );
        if (coregamePlayer != null && coregamePlayer['MatchID'] != null) {
          _transitionPhase(PartyPhase.inMatch);
          await _fetchAndSetCurrentGameMatch(
            coregamePlayer['MatchID'],
            user,
            api,
          );
        } else {
          _transitionPhase(PartyPhase.idle);
          await _fetchPartyLobbyDetails(user, api);
        }
      }
      _handleSuccess();
    } catch (e) {
      LoggerService.log('Error polling agent select: $e', tag: 'PartyProvider');
      _handleFailure();
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _pollInMatchState(dynamic user) async {
    _isFetching = true;
    final api = ref.read(valorantApiProvider);

    try {
      final coregamePlayer = await api.getCurrentGamePlayer(
        user.puuid,
        user.accessToken,
        user.entitlementsToken,
        user.region,
        user.shard,
      );

      if (coregamePlayer == null || coregamePlayer['MatchID'] == null) {
        LoggerService.log(
          'Core-game match completed. Transitioning back to lobby.',
          tag: 'PartyProvider',
        );
        _transitionPhase(PartyPhase.idle);
        await _fetchPartyLobbyDetails(user, api);
      } else {
        await _fetchAndSetCurrentGameMatch(
          coregamePlayer['MatchID'],
          user,
          api,
        );
      }
      _handleSuccess();
    } catch (e) {
      LoggerService.log(
        'Error polling current match: $e',
        tag: 'PartyProvider',
      );
      _handleFailure();
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _fetchPartyLobbyDetails(dynamic user, ValorantApi api) async {
    final partyId = await api.getCurrentPartyId(
      user.puuid,
      user.accessToken,
      user.entitlementsToken,
      user.region,
      user.shard,
    );

    if (partyId == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    final partyDetails = await api.getPartyDetails(
      partyId,
      user.accessToken,
      user.entitlementsToken,
      user.region,
      user.shard,
    );

    final List<dynamic> membersList = partyDetails['Members'] ?? [];
    if (membersList.isEmpty) {
      state = state.copyWith(partyId: partyId, isLoading: false, members: []);
      return;
    }

    final matchmakingData = partyDetails['MatchmakingData'] ?? {};
    final String? queueId = matchmakingData['QueueID'];
    final String? partyStateStr = partyDetails['State'];
    final String? queueEntryTime = partyDetails['QueueEntryTime'];

    if (partyStateStr == 'MATCHMAKING') {
      _transitionPhase(PartyPhase.matchmaking);
    } else if (state.phase == PartyPhase.matchmaking) {
      _transitionPhase(PartyPhase.idle);
    }

    final List<String> puuids = membersList
        .map((m) => m['Subject'] as String)
        .toList();
    await _ensurePlayerNames(puuids, user, api);

    List<PartyMember> partyMembers = [];
    for (var member in membersList) {
      final String puuid = member['Subject'];
      final bool isReady = member['IsReady'] ?? false;
      final bool isOwner = member['IsOwner'] ?? false;
      final int compTier = member['CompetitiveTier'] ?? 0;

      final playerIdentity =
          member['PlayerIdentity'] as Map<String, dynamic>? ?? {};
      final String playerCardId =
          playerIdentity['PlayerCardID'] as String? ?? '';

      final nameData = _nameCache[puuid];
      final String gameName = nameData?['gameName'] ?? 'Unknown';
      final String tagLine = nameData?['tagline'] ?? '';

      partyMembers.add(
        PartyMember(
          puuid: puuid,
          gameName: gameName,
          tagLine: tagLine,
          playerCardId: playerCardId,
          competitiveTier: compTier,
          isReady: isReady,
          isOwner: isOwner,
        ),
      );
    }

    final String accessibility = partyDetails['Accessibility'] ?? 'CLOSED';
    final String? inviteCode =
        partyDetails['InviteCode'] == "" || partyDetails['InviteCode'] == null
        ? null
        : partyDetails['InviteCode'];
    final List<dynamic> rawPreferredPods =
        matchmakingData['PreferredGamePods'] ?? [];
    final List<String> preferredPods = rawPreferredPods
        .map((e) => e.toString())
        .toList();

    Map<String, String> availablePods = state.availableGamePods;
    Map<String, String> availableQueues = state.availableQueues;

    if (!_hasLoadedDynamicConfig) {
      await _loadDynamicConfigs(user, api);
      availablePods = state.availableGamePods;
      availableQueues = state.availableQueues;
    }

    LoggerService.log(
      'Parsed party: partyId=$partyId accessibility=$accessibility '
      'inviteCode=$inviteCode queueId=$queueId partyState=$partyStateStr '
      'preferredPods=$preferredPods availablePodsKeys=${availablePods.keys.toList()}',
      tag: 'PartyProvider',
    );

    state = state.copyWith(
      partyId: partyId,
      members: partyMembers,
      queueId: queueId,
      state: partyStateStr,
      queueEntryTime: queueEntryTime,
      isLoading: false,
      accessibility: accessibility,
      inviteCode: inviteCode,
      clearInviteCode: inviteCode == null,
      preferredGamePods: preferredPods,
      availableGamePods: availablePods,
      availableQueues: availableQueues,
      clearPregameMatch: true,
      clearCurrentGameMatch: true,
    );
  }

  void _prefetchPlayerStatsStaggered(List<String> puuids, dynamic user) {
    var delayMs = 0;
    for (final p in puuids) {
      if (p.isEmpty) continue;
      final puuid = p;
      final currentDelay = delayMs;
      Future.delayed(Duration(milliseconds: currentDelay), () {
        ref
            .read(playerMatchStatsProvider.notifier)
            .fetchPlayerStats(
              puuid,
              region: user.region,
              shard: user.shard,
              accessToken: user.accessToken,
              entitlementsToken: user.entitlementsToken,
            );
      });
      delayMs += 600;
    }
  }

  Future<void> _fetchAndSetPregameMatch(
    String matchId,
    dynamic user,
    ValorantApi api,
  ) async {
    final matchData = await api.getPregameMatch(
      matchId,
      user.accessToken,
      user.entitlementsToken,
      user.region,
      user.shard,
    );

    if (matchData == null) {
      final coregamePlayer = await api.getCurrentGamePlayer(
        user.puuid,
        user.accessToken,
        user.entitlementsToken,
        user.region,
        user.shard,
      );
      if (coregamePlayer != null && coregamePlayer['MatchID'] != null) {
        _transitionPhase(PartyPhase.inMatch);
        await _fetchAndSetCurrentGameMatch(
          coregamePlayer['MatchID'],
          user,
          api,
        );
      } else {
        _transitionPhase(PartyPhase.idle);
        await _fetchPartyLobbyDetails(user, api);
      }
      return;
    }

    final mapId = matchData['MapID'] ?? '';
    final matchmakingData = matchData['MatchmakingData'] ?? {};
    final queueId = matchmakingData['QueueID'] ?? matchData['QueueID'] ?? '';
    final phase = matchData['PregameState'] ?? 'character_select_active';

    final allyTeamData = matchData['AllyTeam'] as Map<String, dynamic>?;
    final enemyTeamData = matchData['EnemyTeam'] as Map<String, dynamic>?;

    final List<dynamic> allyPlayersRaw = allyTeamData?['Players'] ?? [];
    final List<dynamic> enemyPlayersRaw = enemyTeamData?['Players'] ?? [];

    final allPuuids = <String>[];
    for (var p in allyPlayersRaw) {
      if (p['Subject'] != null) allPuuids.add(p['Subject']);
    }
    for (var p in enemyPlayersRaw) {
      if (p['Subject'] != null) allPuuids.add(p['Subject']);
    }

    await _ensurePlayerNames(allPuuids, user, api);
    _prefetchPlayerStatsStaggered(allPuuids, user);

    List<PregamePlayer> parsePregamePlayers(
      List<dynamic> list,
      bool isAlly,
      String teamId,
    ) {
      return list.map((p) {
        final puuid = p['Subject'] ?? '';
        final charId = p['CharacterID'] ?? '';
        final selState = p['CharacterSelectionState'] ?? '';
        final compTier = p['CompetitiveTier'] ?? 0;
        final identity = p['PlayerIdentity'] as Map<String, dynamic>? ?? {};
        final cardId = identity['PlayerCardID'] as String? ?? '';
        final accountLevel = identity['AccountLevel'] as int? ?? 0;

        final nameData = _nameCache[puuid];
        final gameName = nameData?['gameName'] ?? 'Player';
        final tagLine = nameData?['tagline'] ?? '';

        return PregamePlayer(
          puuid: puuid,
          gameName: gameName,
          tagLine: tagLine,
          characterId: charId,
          characterSelectionState: selState,
          competitiveTier: compTier,
          playerCardId: cardId,
          accountLevel: accountLevel,
          teamId: teamId,
          isAlly: isAlly,
        );
      }).toList();
    }

    final allyTeam = parsePregamePlayers(
      allyPlayersRaw,
      true,
      allyTeamData?['TeamID'] ?? 'Blue',
    );
    final enemyTeam = parsePregamePlayers(
      enemyPlayersRaw,
      false,
      enemyTeamData?['TeamID'] ?? 'Red',
    );

    final pregameMatch = PregameMatch(
      matchId: matchId,
      mapId: mapId,
      queueId: queueId,
      phase: phase,
      allyTeam: allyTeam,
      enemyTeam: enemyTeam,
    );

    final myPlayer = allyTeam.firstWhere(
      (p) => p.puuid == user.puuid,
      orElse: () => PregamePlayer(
        puuid: '',
        gameName: '',
        tagLine: '',
        characterId: '',
        characterSelectionState: '',
        competitiveTier: 0,
        playerCardId: '',
        accountLevel: 0,
        teamId: '',
        isAlly: true,
      ),
    );

    ref
        .read(autoLoadoutProvider.notifier)
        .checkAndApplyAutoLoadout(
          mapId: mapId,
          characterId: myPlayer.characterId.isNotEmpty
              ? myPlayer.characterId
              : null,
          matchId: matchId,
        );

    state = state.copyWith(
      phase: PartyPhase.agentSelect,
      pregameMatch: pregameMatch,
      isLoading: false,
      clearCurrentGameMatch: true,
      clearRawState: true,
    );
  }

  Future<void> _fetchAndSetCurrentGameMatch(
    String matchId,
    dynamic user,
    ValorantApi api,
  ) async {
    final matchData = await api.getCurrentGameMatch(
      matchId,
      user.accessToken,
      user.entitlementsToken,
      user.region,
      user.shard,
    );

    if (matchData == null) {
      _transitionPhase(PartyPhase.idle);
      await _fetchPartyLobbyDetails(user, api);
      return;
    }

    final mapId = matchData['MapID'] ?? '';
    final modeId = matchData['ModeID'] ?? '';
    final matchmakingData = matchData['MatchmakingData'] ?? {};
    final queueId = matchmakingData['QueueID'] ?? '';
    final gamePodId = matchData['GamePodID'];
    final provisioningFlow = matchData['ProvisioningFlow'];

    final List<dynamic> playersRaw = matchData['Players'] ?? [];

    if (playersRaw.isEmpty) {
      LoggerService.log(
        'Core-game match has no players left — treating as completed.',
        tag: 'PartyProvider',
      );
      _transitionPhase(PartyPhase.idle);
      await _fetchPartyLobbyDetails(user, api);
      return;
    }

    final allPuuids = <String>[];
    for (var p in playersRaw) {
      if (p['Subject'] != null) allPuuids.add(p['Subject']);
    }

    await _ensurePlayerNames(allPuuids, user, api);
    _prefetchPlayerStatsStaggered(allPuuids, user);

    String userTeam = 'Blue';
    for (var p in playersRaw) {
      if (p['Subject'] == user.puuid) {
        userTeam = p['TeamID'] ?? 'Blue';
        break;
      }
    }

    final List<CurrentGamePlayer> allyTeam = [];
    final List<CurrentGamePlayer> enemyTeam = [];

    for (var p in playersRaw) {
      final puuid = p['Subject'] ?? '';
      final teamId = p['TeamID'] ?? '';
      final charId = p['CharacterID'] ?? '';
      final compTier =
          p['SeasonalBadgeInfo']?['Rank'] ?? p['CompetitiveTier'] ?? 0;
      final identity = p['PlayerIdentity'] as Map<String, dynamic>? ?? {};
      final cardId = identity['PlayerCardID'] as String? ?? '';
      final accountLevel = identity['AccountLevel'] as int? ?? 0;
      final isCoach = p['IsCoach'] ?? false;
      final isAlly = teamId == userTeam;

      final nameData = _nameCache[puuid];
      final gameName = nameData?['gameName'] ?? 'Player';
      final tagLine = nameData?['tagline'] ?? '';

      final playerObj = CurrentGamePlayer(
        puuid: puuid,
        gameName: gameName,
        tagLine: tagLine,
        teamId: teamId,
        characterId: charId,
        competitiveTier: compTier,
        playerCardId: cardId,
        accountLevel: accountLevel,
        isCoach: isCoach,
        isAlly: isAlly,
      );

      if (isAlly) {
        allyTeam.add(playerObj);
      } else {
        enemyTeam.add(playerObj);
      }
    }

    final currentGameMatch = CurrentGameMatch(
      matchId: matchId,
      mapId: mapId,
      modeId: modeId,
      queueId: queueId,
      gamePodId: gamePodId,
      provisioningFlow: provisioningFlow,
      allyTeam: allyTeam,
      enemyTeam: enemyTeam,
    );

    final myPlayer = allyTeam.firstWhere(
      (p) => p.puuid == user.puuid,
      orElse: () => CurrentGamePlayer(
        puuid: '',
        gameName: '',
        tagLine: '',
        teamId: '',
        characterId: '',
        competitiveTier: 0,
        playerCardId: '',
        accountLevel: 0,
        isAlly: true,
      ),
    );

    ref
        .read(autoLoadoutProvider.notifier)
        .checkAndApplyAutoLoadout(
          mapId: mapId,
          characterId: myPlayer.characterId.isNotEmpty
              ? myPlayer.characterId
              : null,
          matchId: matchId,
        );

    state = state.copyWith(
      phase: PartyPhase.inMatch,
      currentGameMatch: currentGameMatch,
      isLoading: false,
      clearPregameMatch: true,
      clearRawState: true,
    );
  }

  Future<void> _loadDynamicConfigs(dynamic user, ValorantApi api) async {
    try {
      final configs = await api.getCustomGameConfigs(
        user.accessToken,
        user.entitlementsToken,
        user.region,
        user.shard,
      );
      final pingServiceInfo =
          configs['GamePodPingServiceInfo'] as Map<String, dynamic>? ?? {};
      final Map<String, String> podsMap = {};

      final Map<String, String> gamePodNames = {
        'ares-gamepod-prod-bom1-1': 'Mumbai',
        'ares-gamepod-prod-sin1-1': 'Singapore',
        'ares-gamepod-prod-hkg1-1': 'Hong Kong',
        'ares-gamepod-prod-nrt1-1': 'Tokyo',
        'ares-gamepod-prod-icn1-1': 'Seoul',
        'ares-gamepod-prod-ece1-1': 'Sydney',
        'ares-gamepod-prod-fra1-1': 'Frankfurt',
        'ares-gamepod-prod-par1-1': 'Paris',
        'ares-gamepod-prod-lon1-1': 'London',
        'ares-gamepod-prod-mad1-1': 'Madrid',
        'ares-gamepod-prod-sto1-1': 'Stockholm',
        'ares-gamepod-prod-waw1-1': 'Warsaw',
        'ares-gamepod-prod-ist1-1': 'Istanbul',
        'ares-gamepod-prod-bah1-1': 'Bahrain',
        'ares-gamepod-prod-pdx1-1': 'Oregon',
        'ares-gamepod-prod-sjc1-1': 'Northern California',
        'ares-gamepod-prod-ash1-1': 'Northern Virginia',
        'ares-gamepod-prod-dfw1-1': 'Texas',
        'ares-gamepod-prod-ord1-1': 'Chicago',
        'ares-gamepod-prod-atl1-1': 'Atlanta',
        'ares-gamepod-prod-mia1-1': 'Miami',
        'ares-gamepod-prod-gru1-1': 'Sao Paulo',
        'ares-gamepod-prod-scl1-1': 'Santiago',
        'ares-gamepod-prod-bog1-1': 'Bogota',
        'ares-gamepod-prod-mex1-1': 'Mexico City',
      };

      pingServiceInfo.forEach((key, value) {
        final name = gamePodNames[key];
        if (name != null) {
          podsMap[key] = name;
        } else {
          final gpIndex = key.indexOf('-gp-');
          if (gpIndex != -1) {
            final afterGp = key.substring(gpIndex + 4);
            final parts = afterGp.split('-');
            if (parts.isNotEmpty) {
              final city = parts[0];
              podsMap[key] = city[0].toUpperCase() + city.substring(1);
              return;
            }
          }

          final Map<String, String> cityShortCodes = {
            'bom': 'Mumbai',
            'sin': 'Singapore',
            'hkg': 'Hong Kong',
            'nrt': 'Tokyo',
            'icn': 'Seoul',
            'ece': 'Sydney',
            'fra': 'Frankfurt',
            'par': 'Paris',
            'lon': 'London',
            'mad': 'Madrid',
            'sto': 'Stockholm',
            'waw': 'Warsaw',
            'ist': 'Istanbul',
            'bah': 'Bahrain',
            'pdx': 'Oregon',
            'sjc': 'Northern California',
            'ash': 'Northern Virginia',
            'dfw': 'Texas',
            'ord': 'Chicago',
            'atl': 'Atlanta',
            'mia': 'Miami',
            'gru': 'Sao Paulo',
            'scl': 'Santiago',
            'bog': 'Bogota',
            'mex': 'Mexico City',
          };

          bool foundShortcode = false;
          for (final entry in cityShortCodes.entries) {
            if (key.contains(entry.key)) {
              podsMap[key] = entry.value;
              foundShortcode = true;
              break;
            }
          }

          if (!foundShortcode) {
            final parts = key.split('-');
            if (parts.length >= 4) {
              final gpPos = parts.indexOf('gp');
              if (gpPos != -1 && gpPos + 1 < parts.length) {
                final city = parts[gpPos + 1];
                podsMap[key] = city[0].toUpperCase() + city.substring(1);
              } else {
                podsMap[key] = parts[parts.length - 2].toUpperCase();
              }
            } else {
              podsMap[key] = key;
            }
          }
        }
      });

      final rawQueues = configs['Queues'] as List<dynamic>? ?? [];
      List<dynamic> apiModes = [];
      try {
        apiModes = await ValorantApi.getGameModes();
      } catch (modeError) {
        LoggerService.log(
          'Failed to fetch game modes from valorant-api: $modeError',
          tag: 'PartyProvider',
        );
      }

      final Map<String, String> queuesMap = {};
      final Map<String, String> queueOverrides = {
        'unrated': 'Unrated',
        'competitive': 'Competitive',
        'swiftplay': 'Swiftplay',
        'spikerush': 'Spike Rush',
        'deathmatch': 'Deathmatch',
        'ggteam': 'Escalation',
        'hurm': 'Team Deathmatch',
        'onefa': 'Replication',
        'snowballfight': 'Snowball Fight',
        'fortcollins': 'Retake',
      };

      for (final q in rawQueues) {
        final String? queueId = q['QueueID'];
        final bool isEnabled = q['Enabled'] ?? false;
        if (queueId == null || queueId.isEmpty) continue;
        if (!isEnabled) continue;

        if (queueOverrides.containsKey(queueId)) {
          queuesMap[queueId] = queueOverrides[queueId]!;
          continue;
        }

        if (queueId.toLowerCase().startsWith('premier')) {
          final String suffix = queueId
              .substring('premier'.length)
              .replaceAll(RegExp(r'^[_\-]+'), '');
          queuesMap[queueId] = suffix.isEmpty
              ? 'Premier'
              : 'Premier: ${suffix[0].toUpperCase()}${suffix.substring(1)}';
          continue;
        }

        final String? modeAssetPath = q['Mode'];
        if (modeAssetPath != null && apiModes.isNotEmpty) {
          final String normalizedAsset = modeAssetPath
              .split('/')
              .last
              .replaceAll('_PrimaryAsset', '')
              .replaceAll('GameMode', '')
              .toLowerCase();
          String? matchedName;
          for (final mode in apiModes) {
            final String? apiAssetPath = mode['assetPath'];
            if (apiAssetPath != null) {
              final String apiNormalized = apiAssetPath
                  .split('/')
                  .last
                  .replaceAll('_PrimaryAsset', '')
                  .replaceAll('GameMode', '')
                  .toLowerCase();
              if (normalizedAsset == apiNormalized) {
                matchedName = mode['displayName'];
                break;
              }
            }
          }
          if (matchedName != null) {
            queuesMap[queueId] = matchedName;
          } else {
            queuesMap[queueId] =
                queueId[0].toUpperCase() + queueId.substring(1);
          }
        } else {
          queuesMap[queueId] = queueId[0].toUpperCase() + queueId.substring(1);
        }
      }

      LoggerService.log(
        'Resolved queues: $queuesMap (raw QueueIDs: '
        '${rawQueues.map((q) => q['QueueID']).toList()})',
        tag: 'PartyProvider',
      );
      LoggerService.log('Resolved game pods: $podsMap', tag: 'PartyProvider');

      state = state.copyWith(
        availableGamePods: podsMap,
        availableQueues: queuesMap.isNotEmpty
            ? queuesMap
            : state.availableQueues,
      );

      _hasLoadedDynamicConfig = true;
    } catch (configError) {
      LoggerService.log(
        'Failed to fetch custom game configs: $configError',
        tag: 'PartyProvider',
      );
    }
  }

  Future<void> refreshParty({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, error: null);
      _consecutiveFailures = 0;
      if (_currentInterval != _basePollInterval) {
        _currentInterval = _basePollInterval;
      }
    }
    await _pollTick();
  }

  Future<void> toggleReady() async {
    if (_isFetching || state.isLoading) return;
    final user = ref.read(authProvider).user;
    final partyId = state.partyId;
    if (user == null || partyId == null) return;

    final myMember = state.members.firstWhere(
      (m) => m.puuid == user.puuid,
      orElse: () => PartyMember(
        puuid: user.puuid,
        gameName: '',
        tagLine: '',
        playerCardId: '',
        competitiveTier: 0,
        isReady: false,
        isOwner: false,
      ),
    );

    state = state.copyWith(isLoading: true);
    final api = ref.read(valorantApiProvider);

    try {
      await api.setReady(
        partyId,
        user.puuid,
        !myMember.isReady,
        user.accessToken,
        user.entitlementsToken,
        user.region,
        user.shard,
      );
      await refreshParty();
    } catch (e) {
      LoggerService.log('Failed to toggle ready: $e', tag: 'PartyProvider');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> changeQueue(String queueId) async {
    if (_isFetching || state.isLoading) return;
    final user = ref.read(authProvider).user;
    final partyId = state.partyId;
    if (user == null || partyId == null) return;

    state = state.copyWith(isLoading: true);
    final api = ref.read(valorantApiProvider);

    try {
      await api.changeQueue(
        partyId,
        queueId,
        user.accessToken,
        user.entitlementsToken,
        user.region,
        user.shard,
      );
      await refreshParty();
    } catch (e) {
      LoggerService.log('Failed to change queue: $e', tag: 'PartyProvider');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> startMatchmaking() async {
    if (_isFetching || state.isLoading) return;
    final user = ref.read(authProvider).user;
    final partyId = state.partyId;
    if (user == null || partyId == null) return;

    state = state.copyWith(isLoading: true);
    final api = ref.read(valorantApiProvider);

    try {
      await api.enterMatchmaking(
        partyId,
        user.accessToken,
        user.entitlementsToken,
        user.region,
        user.shard,
      );
      await refreshParty();
    } catch (e) {
      LoggerService.log(
        'Failed to start matchmaking: $e',
        tag: 'PartyProvider',
      );
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> stopMatchmaking() async {
    if (_isFetching || state.isLoading) return;
    final user = ref.read(authProvider).user;
    final partyId = state.partyId;
    if (user == null || partyId == null) return;

    state = state.copyWith(isLoading: true);
    final api = ref.read(valorantApiProvider);

    try {
      await api.leaveMatchmaking(
        partyId,
        user.accessToken,
        user.entitlementsToken,
        user.region,
        user.shard,
      );
      await refreshParty();
    } catch (e) {
      LoggerService.log('Failed to stop matchmaking: $e', tag: 'PartyProvider');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> toggleAccessibility() async {
    if (_isFetching || state.isLoading) return;
    final user = ref.read(authProvider).user;
    final partyId = state.partyId;
    if (user == null || partyId == null) return;

    final nextAccessibility = state.accessibility == 'OPEN' ? 'CLOSED' : 'OPEN';
    state = state.copyWith(isLoading: true);
    final api = ref.read(valorantApiProvider);

    try {
      await api.setAccessibility(
        partyId,
        nextAccessibility,
        user.accessToken,
        user.entitlementsToken,
        user.region,
        user.shard,
      );
      await refreshParty();
    } catch (e) {
      LoggerService.log(
        'Failed to toggle accessibility: $e',
        tag: 'PartyProvider',
      );
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> generatePartyCode() async {
    if (_isFetching || state.isLoading) return;
    final user = ref.read(authProvider).user;
    final partyId = state.partyId;
    if (user == null || partyId == null) return;

    state = state.copyWith(isLoading: true);
    final api = ref.read(valorantApiProvider);

    try {
      await api.makeCode(
        partyId,
        user.accessToken,
        user.entitlementsToken,
        user.region,
        user.shard,
      );
      await refreshParty();
    } catch (e) {
      LoggerService.log('Failed to make code: $e', tag: 'PartyProvider');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> disablePartyCode() async {
    if (_isFetching || state.isLoading) return;
    final user = ref.read(authProvider).user;
    final partyId = state.partyId;
    if (user == null || partyId == null) return;

    state = state.copyWith(isLoading: true);
    final api = ref.read(valorantApiProvider);

    try {
      await api.revokeCode(
        partyId,
        user.accessToken,
        user.entitlementsToken,
        user.region,
        user.shard,
      );
      await refreshParty();
    } catch (e) {
      LoggerService.log('Failed to revoke code: $e', tag: 'PartyProvider');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updatePreferredGamePods(List<String> gamePods) async {
    if (_isFetching || state.isLoading) return;
    final user = ref.read(authProvider).user;
    final partyId = state.partyId;
    if (user == null || partyId == null) return;

    state = state.copyWith(isLoading: true);
    final api = ref.read(valorantApiProvider);

    LoggerService.log(
      'updatePreferredGamePods requested: $gamePods (partyId=$partyId, '
      'region=${user.region}, shard=${user.shard}, previouslySelected=${state.preferredGamePods})',
      tag: 'PartyProvider',
    );

    try {
      await api.setPreferredGamePods(
        partyId,
        gamePods,
        user.accessToken,
        user.entitlementsToken,
        user.region,
        user.shard,
      );
      await refreshParty();
      LoggerService.log(
        'updatePreferredGamePods result after refresh: ${state.preferredGamePods}',
        tag: 'PartyProvider',
      );
    } catch (e) {
      LoggerService.log(
        'Failed to set preferred game pods: $e',
        tag: 'PartyProvider',
      );
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> invitePlayer(String name, String tag) async {
    final user = ref.read(authProvider).user;
    final partyId = state.partyId;
    if (user == null || partyId == null) return false;

    final api = ref.read(valorantApiProvider);
    try {
      await api.inviteToPartyByName(
        partyId,
        name,
        tag,
        user.accessToken,
        user.entitlementsToken,
        user.region,
        user.shard,
      );
      return true;
    } catch (e) {
      LoggerService.log(
        'Failed to invite player $name#$tag: $e',
        tag: 'PartyProvider',
      );
      return false;
    }
  }
}

final partyProvider = NotifierProvider<PartyNotifier, PartyState>(() {
  return PartyNotifier();
});
