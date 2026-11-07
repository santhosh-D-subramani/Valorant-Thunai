import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/services/valorant_api.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/providers/profile_provider.dart';
import 'package:valorant_thunai/utils/match_stats_calculator.dart';
import 'package:valorant_thunai/utils/format_utils.dart';
import 'package:valorant_thunai/providers/display_settings_provider.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';
import 'package:valorant_thunai/screens/matches/match_detail_tabs.dart';
import 'package:valorant_thunai/screens/profile/player_search_screen.dart';

class MatchDetailPage extends ConsumerStatefulWidget {
  final String matchId;
  final String playerPuuid;

  const MatchDetailPage({
    super.key,
    required this.matchId,
    required this.playerPuuid,
  });

  @override
  ConsumerState<MatchDetailPage> createState() => _MatchDetailPageState();
}

class _MatchDetailPageState extends ConsumerState<MatchDetailPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _matchDetails;
  late TabController _tabController;

  final Map<String, Map<String, dynamic>> _agentsMap = {};
  final Map<String, Map<String, dynamic>> _mapsMap = {};
  final Map<String, String> _weaponNamesByUuid = {};
  final Map<String, String> _weaponIconsByUuid = {};

  Map<String, Map<String, String>> _resolvedNames = {};

  late String _focusedPuuid;
  ScoreboardSortMetric _sortMetric = ScoreboardSortMetric.acs;

  @override
  void initState() {
    super.initState();
    _focusedPuuid = widget.playerPuuid;
    _tabController = TabController(length: 6, vsync: this);
    _fetchDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authState = ref.read(authProvider);
      final user = authState.user;
      if (user == null) {
        throw Exception("Session expired or user not logged in");
      }

      final api = ref.read(valorantApiProvider);

      final results = await Future.wait([
        api.getMatchDetails(
          shard: user.shard,
          matchId: widget.matchId,
          accessToken: user.accessToken,
          entitlementsToken: user.entitlementsToken,
        ),
        http.get(
          Uri.parse(
            'https://valorant-api.com/v1/agents?isPlayableCharacter=true',
          ),
        ),
        http.get(Uri.parse('https://valorant-api.com/v1/maps')),
        http.get(Uri.parse('https://valorant-api.com/v1/weapons')),
      ]);

      final details = results[0] as Map<String, dynamic>?;
      final agentsRes = results[1] as http.Response;
      final mapsRes = results[2] as http.Response;
      final weaponsRes = results[3] as http.Response;

      if (details == null) {
        throw Exception("Failed to load match details from Riot server.");
      }

      if (agentsRes.statusCode == 200) {
        final agentsData = jsonDecode(agentsRes.body)['data'] as List;
        for (var agent in agentsData) {
          final uuid = agent['uuid']?.toString().toLowerCase();
          if (uuid != null) {
            _agentsMap[uuid] = agent;
          }
        }
      }

      if (mapsRes.statusCode == 200) {
        final mapsData = jsonDecode(mapsRes.body)['data'] as List;
        for (var valMap in mapsData) {
          final mapPath = valMap['mapUrl']?.toString().toLowerCase();
          if (mapPath != null) {
            _mapsMap[mapPath] = valMap;
          }
        }
      }

      if (weaponsRes.statusCode == 200) {
        final weaponsData = jsonDecode(weaponsRes.body)['data'] as List;
        for (var weapon in weaponsData) {
          final uuid = weapon['uuid']?.toString().toLowerCase();
          final name = weapon['displayName']?.toString();
          final icon = weapon['killStreamIcon']?.toString();
          if (uuid != null && name != null) {
            _weaponNamesByUuid[uuid] = name;
          }
          if (uuid != null && icon != null && icon.isNotEmpty) {
            _weaponIconsByUuid[uuid] = icon;
          }
        }
      }

      final playersList = (details['players'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final missingNamePuuids = <String>[
        for (final p in playersList)
          if ((p['gameName']?.toString() ?? '').isEmpty)
            if (p['subject']?.toString() != null) p['subject'].toString(),
      ];
      if (missingNamePuuids.isNotEmpty) {
        try {
          _resolvedNames = await api.fetchNamesByPuuids(
            missingNamePuuids,
            user.shard,
            user.accessToken,
            user.entitlementsToken,
          );
        } catch (_) {}
      }

      setState(() {
        _matchDetails = details;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst("Exception: ", "");
        _isLoading = false;
      });
    }
  }

  (String name, String tag) _resolvePlayerNameParts(
    Map<String, dynamic> player,
  ) {
    final name = player['gameName']?.toString() ?? '';
    final tag = player['tagLine']?.toString() ?? '';
    if (name.isNotEmpty) return (name, tag);

    final subject = player['subject']?.toString();
    final resolved = subject != null ? _resolvedNames[subject] : null;
    final resolvedName = resolved?['gameName'] ?? '';
    if (resolvedName.isNotEmpty) {
      return (resolvedName, resolved?['tagline'] ?? '');
    }
    return (AppLocalizations.of(context)!.hiddenPlayerName, '');
  }

  String _resolvePlayerName(
    Map<String, dynamic> player,
    AppLocalizations l10n,
  ) {
    final (name, tag) = _resolvePlayerNameParts(player);
    return tag.isNotEmpty ? '$name#$tag' : name;
  }

  String? _friendlyServerName(String? gamePodId) {
    if (gamePodId == null || gamePodId.isEmpty) return null;
    final parts = gamePodId.toLowerCase().split('-');
    final gpIndex = parts.indexOf('gp');
    List<String> cityParts;
    if (gpIndex != -1 && gpIndex + 1 < parts.length) {
      cityParts = parts
          .sublist(gpIndex + 1)
          .where((p) => int.tryParse(p) == null)
          .toList();
    } else {
      cityParts = parts.where((p) => int.tryParse(p) == null).toList();
    }
    if (cityParts.isEmpty) return null;
    return cityParts
        .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.matchDetailsTitle), centerTitle: true),
      body: SafeArea(child: _buildBody(theme, isDark)),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 60,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchDetails,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_matchDetails == null) {
      return Center(child: Text(l10n.noDetailsAvailable));
    }

    final matchInfo = _matchDetails!['matchInfo'] ?? {};
    final players = (_matchDetails!['players'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final teams = (_matchDetails!['teams'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    final mapPath = (matchInfo['mapId'] ?? '').toString().toLowerCase();
    final mapData = _mapsMap[mapPath];
    final mapName = mapData?['displayName'] ?? l10n.unknownMap;
    final mapSplash = mapData?['splash'];

    final gameMode =
        matchInfo['queueID']?.toString().toUpperCase() ?? 'UNRATED';
    final gameLength = matchInfo['gameLengthMillis'] as int?;
    final gameStart = matchInfo['gameStartMillis'] as int?;
    final matchDate = gameStart != null
        ? DateTime.fromMillisecondsSinceEpoch(gameStart)
        : DateTime.now();

    final serverName = _friendlyServerName(matchInfo['gamePodId']?.toString());
    final displaySettings = ref.watch(displaySettingsProvider);
    final dateLabel = FormatUtils.formatDateTime(matchDate, displaySettings);

    final currentPlayer = players.firstWhere(
      (p) => p['subject'] == widget.playerPuuid,
      orElse: () => <String, dynamic>{},
    );

    final currentTeamId = currentPlayer['teamId'] ?? '';
    final currentTeamData = teams.firstWhere(
      (t) => t['teamId'] == currentTeamId,
      orElse: () => <String, dynamic>{},
    );

    final bool hasWon = currentTeamData['won'] == true;
    final int teamRoundsWon = currentTeamData['roundsWon'] ?? 0;

    final opposingTeamData = teams.firstWhere(
      (t) => t['teamId'] != currentTeamId,
      orElse: () => <String, dynamic>{},
    );
    final int opponentRoundsWon = opposingTeamData['roundsWon'] ?? 0;
    final int totalRounds = teamRoundsWon + opponentRoundsWon;
    final bool isDraw = teamRoundsWon == opponentRoundsWon && totalRounds > 0;

    final outcomeColor = isDraw
        ? Colors.grey[700]
        : (hasWon ? Colors.green[700] : Colors.red[700]);
    final outcomeText = isDraw
        ? l10n.matchResultDraw
        : (hasWon ? l10n.matchResultVictory : l10n.matchResultDefeat);

    final analysis = MatchStatsCalculator.analyze(
      matchDetails: _matchDetails!,
      targetPuuid: _focusedPuuid,
    );
    final playerNames = <String, String>{};
    final agentIconByPuuid = <String, dynamic>{};
    final teamBySubject = <String, String>{};
    final characterUuidByPuuid = <String, String>{};
    for (final p in players) {
      final subject = p['subject']?.toString();
      if (subject == null) continue;
      playerNames[subject] = _resolvePlayerName(p, l10n);
      final characterUuid = (p['characterId'] ?? '').toString().toLowerCase();
      agentIconByPuuid[subject] = _agentsMap[characterUuid]?['displayIcon'];
      teamBySubject[subject] = (p['teamId'] ?? '').toString();
      characterUuidByPuuid[subject] = characterUuid;
    }
    final focusedTeam =
        teamBySubject[_focusedPuuid] ?? currentTeamId.toString();

    return Column(
      children: [
        _buildMatchInfoCard(
          theme,
          mapSplash,
          mapName,
          gameMode,
          gameLength,
          dateLabel,
          serverName,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              color: outcomeColor?.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: outcomeColor ?? Colors.grey,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  outcomeText,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.normal,
                    color: outcomeColor,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  '$teamRoundsWon - $opponentRoundsWon',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: [
            Tab(text: l10n.matchTabSummary),
            Tab(text: l10n.matchTabScoreboard),
            Tab(text: l10n.matchTabRounds),
            Tab(text: l10n.matchTabDuels),
            Tab(text: l10n.matchTabPerformance),
            Tab(text: l10n.matchTabEconomy),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              SummaryTab(
                analysis: analysis,
                playerNames: playerNames,
                focusedPuuid: _focusedPuuid,
              ),
              ScoreboardTab(
                players: players,
                analysis: analysis,
                playerNames: playerNames,
                agentIconByPuuid: agentIconByPuuid,
                competitiveTiers:
                    ref.watch(competitiveTiersProvider).value ?? {},
                viewerPuuid: widget.playerPuuid,
                viewerTeam: currentTeamId.toString(),
                focusedPuuid: _focusedPuuid,
                sortMetric: _sortMetric,
                onFocusPlayer: (puuid) => setState(() => _focusedPuuid = puuid),
                onOpenProfile: _openPlayerProfile,
              ),
              RoundsTab(
                analysis: analysis,
                playerNames: playerNames,
                weaponNames: _weaponNamesByUuid,
                weaponIcons: _weaponIconsByUuid,
                agentIconByPuuid: agentIconByPuuid,
                characterUuidByPuuid: characterUuidByPuuid,
                agentsByUuid: _agentsMap,
                mapData: mapData,
                focusedPuuid: _focusedPuuid,
                focusedTeam: focusedTeam,
                teamBySubject: teamBySubject,
              ),
              DuelsTab(
                analysis: analysis,
                playerNames: playerNames,
                agentIconByPuuid: agentIconByPuuid,
              ),
              PerformanceTab(
                analysis: analysis,
                displaySettings: displaySettings,
              ),
              EconomyTab(analysis: analysis, displaySettings: displaySettings),
            ],
          ),
        ),
        _buildBottomBar(
          theme,
          currentPlayer,
          analysis,
          displaySettings,
          players,
          playerNames,
        ),
      ],
    );
  }

  void _openPlayerProfile(String puuid) {
    final player = (_matchDetails!['players'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['subject'] == puuid, orElse: () => {});
    if (player.isEmpty) return;
    final (name, tag) = _resolvePlayerNameParts(player);
    if (name.isEmpty ||
        name == AppLocalizations.of(context)!.hiddenPlayerName) {
      return;
    }
    final query = tag.isNotEmpty ? '$name#$tag' : name;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerSearchPage(initialQuery: query),
      ),
    );
  }

  Widget _buildBottomBar(
    ThemeData theme,
    Map<String, dynamic> currentPlayer,
    MatchAnalysis analysis,
    DisplaySettings displaySettings,
    List<Map<String, dynamic>> players,
    Map<String, String> playerNames,
  ) {
    if (currentPlayer.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final me = analysis.playerStats[widget.playerPuuid];

    final characterUuid = (currentPlayer['characterId'] ?? '')
        .toString()
        .toLowerCase();
    final agentData = _agentsMap[characterUuid];
    final agentName = agentData?['displayName'] ?? l10n.unknownAgent;
    final agentIcon = agentData?['displayIcon'];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (agentIcon != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: agentIcon,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              )
            else
              const Icon(Icons.person, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    agentName,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (me != null)
                    Text(
                      '${l10n.kdaHeader} ${me.kills}/${me.deaths}/${me.assists}  •  '
                      '${l10n.acs} ${me.acs.round()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.sortByLabel,
              icon: const Icon(Icons.sort),
              onPressed: () => _showSortSheet(context),
            ),
            _buildFocusedPlayerMenu(players, playerNames),
          ],
        ),
      ),
    );
  }

  String _sortMetricLabel(AppLocalizations l10n, ScoreboardSortMetric metric) {
    switch (metric) {
      case ScoreboardSortMetric.acs:
        return l10n.acs;
      case ScoreboardSortMetric.adr:
        return l10n.adr;
      case ScoreboardSortMetric.kast:
        return l10n.kast;
      case ScoreboardSortMetric.kills:
        return l10n.kills;
      case ScoreboardSortMetric.deaths:
        return l10n.deathsStat;
    }
  }

  void _showSortSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.sortByLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    RadioGroup<ScoreboardSortMetric>(
                      groupValue: _sortMetric,
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {});
                        setState(() => _sortMetric = value);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: ScoreboardSortMetric.values.map(
                          (metric) => RadioListTile<ScoreboardSortMetric>(
                            dense: true,
                            title: Text(_sortMetricLabel(l10n, metric)),
                            value: metric,
                          ),
                        ).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFocusedPlayerMenu(
    List<Map<String, dynamic>> players,
    Map<String, String> playerNames,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      tooltip: l10n.focusedPlayerLabel,
      onSelected: (puuid) => setState(() => _focusedPuuid = puuid),
      itemBuilder: (context) => players.map((p) {
        final subject = p['subject']?.toString() ?? '';
        final characterUuid = (p['characterId'] ?? '').toString().toLowerCase();
        final icon = _agentsMap[characterUuid]?['displayIcon'];
        return PopupMenuItem<String>(
          value: subject,
          child: Row(
            children: [
              if (icon != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: icon,
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                  ),
                )
              else
                const Icon(Icons.person, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  playerNames[subject] ?? '???',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 1.4,
          ),
        ),
        child: const Icon(Icons.center_focus_strong, size: 20),
      ),
    );
  }

  Widget _buildMatchInfoCard(
    ThemeData theme,
    String? mapSplash,
    String mapName,
    String gameMode,
    int? gameLength,
    String dateLabel,
    String? serverName,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 96,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (mapSplash != null)
            CachedNetworkImage(imageUrl: mapSplash, fit: BoxFit.cover)
          else
            Container(color: Colors.grey[900]),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.black.withValues(alpha: 0.45),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        gameMode,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mapName,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  dateLabel,
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    FormatUtils.formatDurationMillis(gameLength),
                    if (serverName != null) '${l10n.serverLabel}: $serverName',
                  ].join(' • '),
                  style: GoogleFonts.inter(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
