import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/services/valorant_api.dart';
import 'package:valorant_thunai/services/logger_service.dart';

const List<String> leaderboardShards = ['na', 'eu', 'ap', 'kr', 'pbe'];

class LeaderboardEntry {
  final String puuid;
  final int rank;
  final String gameName;
  final String tagLine;
  final bool isAnonymized;
  final int rankedRating;
  final int numberOfWins;
  final int competitiveTier;
  final String playerCardId;

  const LeaderboardEntry({
    required this.puuid,
    required this.rank,
    required this.gameName,
    required this.tagLine,
    required this.isAnonymized,
    required this.rankedRating,
    required this.numberOfWins,
    required this.competitiveTier,
    required this.playerCardId,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final anonymized = json['IsAnonymized'] == true;
    return LeaderboardEntry(
      puuid: json['puuid'] ?? '',
      rank: json['leaderboardRank'] ?? 0,
      gameName: anonymized ? '' : (json['gameName'] ?? ''),
      tagLine: anonymized ? '' : (json['tagLine'] ?? ''),
      isAnonymized: anonymized,
      rankedRating: json['rankedRating'] ?? 0,
      numberOfWins: json['numberOfWins'] ?? 0,
      competitiveTier: json['competitiveTier'] ?? 0,
      playerCardId: anonymized ? '' : (json['PlayerCardID'] ?? ''),
    );
  }

  String get displayName {
    if (isAnonymized || gameName.isEmpty) return 'Anonymous';
    return tagLine.isEmpty ? gameName : '$gameName #$tagLine';
  }
}

class ActInfo {
  final String uuid;
  final String name;
  final DateTime? startTime;

  const ActInfo({required this.uuid, required this.name, this.startTime});
}

final allActsProvider = FutureProvider<List<ActInfo>>((ref) async {
  final response = await http.get(
    Uri.parse('https://valorant-api.com/v1/seasons'),
  );
  if (response.statusCode != 200) return [];
  final List seasons = jsonDecode(response.body)['data'] ?? [];

  final acts = <ActInfo>[];
  for (final season in seasons) {
    if (season['type'] != 'EAresSeasonType::Act') continue;
    final start = DateTime.tryParse(season['startTime'] ?? '');
    acts.add(
      ActInfo(
        uuid: season['uuid'] as String? ?? '',
        name: '',
        startTime: start,
      ),
    );
  }
  acts.sort((a, b) {
    if (a.startTime == null || b.startTime == null) return 0;
    return b.startTime!.compareTo(a.startTime!);
  });

  final numbered = <ActInfo>[];
  for (var i = 0; i < acts.length; i++) {
    numbered.add(
      ActInfo(
        uuid: acts[i].uuid,
        name: 'Act ${acts.length - i}',
        startTime: acts[i].startTime,
      ),
    );
  }
  return numbered;
});

final currentActIdProvider = FutureProvider<String?>((ref) async {
  final acts = await ref.watch(allActsProvider.future);
  final now = DateTime.now();
  for (final act in acts) {
    if (act.startTime != null && act.startTime!.isBefore(now)) {
      return act.uuid;
    }
  }
  return acts.isNotEmpty ? acts.first.uuid : null;
});

class LeaderboardFilters {
  final String shard;
  final String? seasonId;
  final String query;

  const LeaderboardFilters({
    required this.shard,
    required this.seasonId,
    this.query = '',
  });

  LeaderboardFilters copyWith({
    String? shard,
    String? seasonId,
    String? query,
  }) {
    return LeaderboardFilters(
      shard: shard ?? this.shard,
      seasonId: seasonId ?? this.seasonId,
      query: query ?? this.query,
    );
  }
}

class LeaderboardFiltersNotifier extends Notifier<LeaderboardFilters> {
  @override
  LeaderboardFilters build() {
    final user = ref.read(authProvider).user;
    return LeaderboardFilters(shard: user?.shard ?? 'na', seasonId: null);
  }

  void setShard(String shard) => state = state.copyWith(shard: shard);
  void setSeason(String seasonId) => state = state.copyWith(seasonId: seasonId);
  void setQuery(String query) => state = state.copyWith(query: query);

  void reset() {
    final user = ref.read(authProvider).user;
    state = LeaderboardFilters(
      shard: user?.shard ?? 'na',
      seasonId: null,
      query: '',
    );
  }
}

final leaderboardFiltersProvider =
    NotifierProvider<LeaderboardFiltersNotifier, LeaderboardFilters>(
      LeaderboardFiltersNotifier.new,
    );

class LeaderboardState {
  final List<LeaderboardEntry> entries;
  final bool isLoading;
  final bool hasMore;
  final int totalPlayers;
  final String? error;

  const LeaderboardState({
    this.entries = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.totalPlayers = 0,
    this.error,
  });

  LeaderboardState copyWith({
    List<LeaderboardEntry>? entries,
    bool? isLoading,
    bool? hasMore,
    int? totalPlayers,
    String? error,
  }) {
    return LeaderboardState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      totalPlayers: totalPlayers ?? this.totalPlayers,
      error: error,
    );
  }
}

class LeaderboardNotifier extends Notifier<LeaderboardState> {
  static const _pageSize = 100;

  @override
  LeaderboardState build() {
    ref.listen(leaderboardFiltersProvider, (previous, next) {
      if (previous?.shard != next.shard ||
          previous?.seasonId != next.seasonId ||
          previous?.query != next.query) {
        state = const LeaderboardState();
        loadNextPage();
      }
    });
    return const LeaderboardState();
  }

  Future<void> loadNextPage() async {
    if (state.isLoading || !state.hasMore) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    final filters = ref.read(leaderboardFiltersProvider);
    var seasonId = filters.seasonId;
    seasonId ??= await ref.read(currentActIdProvider.future);
    if (seasonId == null) {
      state = state.copyWith(
        isLoading: false,
        hasMore: false,
        error: 'noActiveAct',
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ref.read(valorantApiProvider);
      final data = await api.getLeaderboard(
        shard: filters.shard,
        accessToken: user.accessToken,
        entitlementsToken: user.entitlementsToken,
        seasonId: seasonId,
        size: _pageSize,
        startIndex: state.entries.length,
        query: filters.query,
      );

      final List playersJson = data['Players'] ?? data['players'] ?? [];
      final newEntries = playersJson
          .map((p) => LeaderboardEntry.fromJson(Map<String, dynamic>.from(p)))
          .toList();
      final total = data['totalPlayers'] ?? state.totalPlayers;

      state = state.copyWith(
        entries: [...state.entries, ...newEntries],
        isLoading: false,
        hasMore: newEntries.length >= _pageSize,
        totalPlayers: total,
      );
    } catch (e) {
      LoggerService.log(
        'Failed to load leaderboard page: $e',
        tag: 'Leaderboard',
      );
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() {
    state = const LeaderboardState();
  }
}

final leaderboardProvider =
    NotifierProvider<LeaderboardNotifier, LeaderboardState>(
      LeaderboardNotifier.new,
    );
