import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:valorant_thunai/services/valorant_api.dart';
import 'package:valorant_thunai/services/session_stats_service.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:valorant_thunai/l10n/app_localizations.dart';

class _MatchClutches {
  final int attempts;
  final int wins;
  const _MatchClutches({this.attempts = 0, this.wins = 0});
}

class ProfileStatsTab extends StatefulWidget {
  final String region;
  final String puuid;
  final bool isDark;

  const ProfileStatsTab({
    super.key,
    required this.region,
    required this.puuid,
    required this.isDark,
  });

  @override
  State<ProfileStatsTab> createState() => _ProfileStatsTabState();
}

class _ProfileStatsTabState extends State<ProfileStatsTab> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _matches = [];
  List<dynamic> _rrHistory = [];

  final Map<String, String> _agentNameIconMap = {};
  final Map<String, String> _mapNameSplashMap = {};

  int totalMatches = 0;
  int totalWins = 0;
  int totalLosses = 0;
  int totalDraws = 0;
  int totalKills = 0;
  int totalDeaths = 0;
  int totalAssists = 0;
  int totalScore = 0;
  int totalRoundsPlayed = 0;
  int totalPlaytimeMillis = 0;
  int totalClutchAttempts = 0;
  int totalClutchWins = 0;

  Map<String, Map<String, dynamic>> agentStats = {};
  Map<String, Map<String, dynamic>> mapStats = {};

  int sessionMatches = 0;
  int sessionWins = 0;
  int sessionLosses = 0;
  int sessionDraws = 0;
  int sessionKills = 0;
  int sessionDeaths = 0;
  int sessionAssists = 0;
  int sessionScore = 0;
  int sessionRoundsPlayed = 0;

  bool _showSessionStats = false;

  String _selectedMode = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final matchesFuture = ValorantApi.fetchHenrikMatches(
        widget.region,
        widget.puuid,
        size: 50,
      );
      final rrHistoryFuture = ValorantApi.getHenrikMMRHistory(
        widget.region,
        widget.puuid,
      );
      final agentsFuture = http.get(
        Uri.parse(
          'https://valorant-api.com/v1/agents?isPlayableCharacter=true',
        ),
      );
      final mapsFuture = http.get(
        Uri.parse('https://valorant-api.com/v1/maps'),
      );

      final results = await Future.wait([
        matchesFuture,
        rrHistoryFuture,
        agentsFuture,
        mapsFuture,
      ]);

      final matchesData = results[0] as List<dynamic>?;
      final rrHistoryData = results[1] as List<dynamic>?;
      final agentsRes = results[2] as http.Response;
      final mapsRes = results[3] as http.Response;

      _rrHistory = rrHistoryData ?? [];

      if (agentsRes.statusCode == 200) {
        final agentsData = jsonDecode(agentsRes.body)['data'] as List;
        for (var agent in agentsData) {
          final name = agent['displayName']?.toString().toLowerCase();
          final icon = agent['displayIcon']?.toString();
          if (name != null && icon != null) {
            _agentNameIconMap[name] = icon;
          }
        }
      }

      if (mapsRes.statusCode == 200) {
        final mapsData = jsonDecode(mapsRes.body)['data'] as List;
        for (var map in mapsData) {
          final name = map['displayName']?.toString().toLowerCase();
          final splash = map['splash']?.toString();
          if (name != null && splash != null) {
            _mapNameSplashMap[name] = splash;
          }
        }
      }

      if (matchesData != null) {
        _matches = matchesData;
        _calculateStats();
      } else {
        _error = "Failed to load matches.";
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _calculateStats() {
    totalMatches = 0;
    totalWins = 0;
    totalLosses = 0;
    totalDraws = 0;
    totalKills = 0;
    totalDeaths = 0;
    totalAssists = 0;
    totalScore = 0;
    totalRoundsPlayed = 0;
    totalPlaytimeMillis = 0;
    totalClutchAttempts = 0;
    totalClutchWins = 0;
    agentStats.clear();
    mapStats.clear();

    sessionMatches = 0;
    sessionWins = 0;
    sessionLosses = 0;
    sessionDraws = 0;
    sessionKills = 0;
    sessionDeaths = 0;
    sessionAssists = 0;
    sessionScore = 0;
    sessionRoundsPlayed = 0;

    for (var match in _matches) {
      final metadata = match['metadata'] ?? {};
      final mode = metadata['mode']?.toString() ?? 'Unrated';

      if (_selectedMode != 'All' &&
          mode.toLowerCase() != _selectedMode.toLowerCase()) {
        continue;
      }

      totalMatches++;
      final mapName = metadata['map']?.toString() ?? 'Unknown';
      final gameStart = (metadata['game_start'] as num?)?.toInt() ?? 0;
      final isThisSession = SessionStatsService.isDuringSession(gameStart);
      final int roundsPlayed = (metadata['rounds_played'] as num? ?? 0).toInt();
      final int playtime =
          ((metadata['playtime_millis'] ?? metadata['game_length'] ?? 0) as num)
              .toInt();

      totalRoundsPlayed += roundsPlayed;
      totalPlaytimeMillis += playtime;

      final players = match['players']?['all_players'] as List? ?? [];
      final playerInfo = players.firstWhere(
        (p) => p['puuid'] == widget.puuid,
        orElse: () => null,
      );

      if (playerInfo == null) continue;

      final characterName = playerInfo['character']?.toString() ?? 'Unknown';
      final team = playerInfo['team']?.toString().toLowerCase() ?? 'blue';
      final stats = playerInfo['stats'] ?? {};

      final kills = (stats['kills'] ?? 0) as int;
      final deaths = (stats['deaths'] ?? 0) as int;
      final assists = (stats['assists'] ?? 0) as int;
      final score = (stats['score'] ?? 0) as int;

      totalKills += kills;
      totalDeaths += deaths;
      totalAssists += assists;
      totalScore += score;

      final clutches = _computeClutches(match, widget.puuid);
      totalClutchAttempts += clutches.attempts;
      totalClutchWins += clutches.wins;

      final teams = match['teams'] ?? {};
      final teamInfo = teams[team] ?? {};
      final bool hasWon = teamInfo['has_won'] ?? false;
      final int roundsWon = teamInfo['rounds_won'] ?? 0;
      final int roundsLost = (roundsPlayed > 0) ? roundsPlayed - roundsWon : 0;
      final isDraw = (roundsWon == roundsLost) && roundsPlayed > 0;

      if (hasWon) {
        totalWins++;
      } else if (isDraw) {
        totalDraws++;
      } else {
        totalLosses++;
      }

      if (isThisSession) {
        sessionMatches++;
        sessionKills += kills;
        sessionDeaths += deaths;
        sessionAssists += assists;
        sessionScore += score;
        sessionRoundsPlayed += roundsPlayed;
        if (hasWon) {
          sessionWins++;
        } else if (isDraw) {
          sessionDraws++;
        } else {
          sessionLosses++;
        }
      }

      if (!agentStats.containsKey(characterName)) {
        agentStats[characterName] = {
          'matches': 0,
          'wins': 0,
          'kills': 0,
          'deaths': 0,
        };
      }
      agentStats[characterName]!['matches'] =
          agentStats[characterName]!['matches'] + 1;
      agentStats[characterName]!['wins'] =
          agentStats[characterName]!['wins'] + (hasWon ? 1 : 0);
      agentStats[characterName]!['kills'] =
          agentStats[characterName]!['kills'] + kills;
      agentStats[characterName]!['deaths'] =
          agentStats[characterName]!['deaths'] + deaths;

      if (!mapStats.containsKey(mapName)) {
        mapStats[mapName] = {'matches': 0, 'wins': 0};
      }
      mapStats[mapName]!['matches'] = mapStats[mapName]!['matches'] + 1;
      mapStats[mapName]!['wins'] =
          mapStats[mapName]!['wins'] + (hasWon ? 1 : 0);
    }
  }

  static _MatchClutches _computeClutches(dynamic match, String puuid) {
    try {
      final allPlayers = (match['players']?['all_players'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      if (allPlayers.isEmpty) return const _MatchClutches();

      final teamBySubject = <String, String>{
        for (final p in allPlayers)
          (p['puuid']?.toString() ?? ''):
              (p['team']?.toString().toLowerCase() ?? ''),
      };
      final myTeam = teamBySubject[puuid];
      if (myTeam == null || myTeam.isEmpty) return const _MatchClutches();

      final rosterSize = <String, int>{};
      for (final t in teamBySubject.values) {
        if (t.isEmpty) continue;
        rosterSize[t] = (rosterSize[t] ?? 0) + 1;
      }
      final otherTeam = rosterSize.keys.firstWhere(
        (t) => t != myTeam,
        orElse: () => '',
      );
      if (otherTeam.isEmpty) return const _MatchClutches();

      final rounds = (match['rounds'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      if (rounds.isEmpty) return const _MatchClutches();

      var attempts = 0;
      var wins = 0;

      for (final round in rounds) {
        final winningTeam =
            round['winning_team']?.toString().toLowerCase() ?? '';
        final playerStats = (round['player_stats'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        if (!playerStats.any((ps) => ps['player_puuid']?.toString() == puuid)) {
          continue;
        }

        final roundKills = <Map<String, dynamic>>[];
        for (final ps in playerStats) {
          roundKills.addAll(
            (ps['kill_events'] as List? ?? []).cast<Map<String, dynamic>>(),
          );
        }
        if (roundKills.isEmpty) continue;
        roundKills.sort(
          (a, b) => ((a['kill_time_in_round'] as num?) ?? 0).compareTo(
            (b['kill_time_in_round'] as num?) ?? 0,
          ),
        );

        var myAlive = rosterSize[myTeam] ?? 0;
        var enemyAlive = rosterSize[otherTeam] ?? 0;
        var inClutch = false;
        var died = false;
        var enemiesFaced = 0;

        for (final k in roundKills) {
          final victim = k['victim_puuid']?.toString();
          final victimTeam = teamBySubject[victim];
          if (victimTeam == myTeam) {
            myAlive -= 1;
          } else if (victimTeam == otherTeam) {
            enemyAlive -= 1;
          }
          if (victim == puuid) died = true;

          if (!inClutch && !died && myAlive == 1 && enemyAlive >= 1) {
            inClutch = true;
            enemiesFaced = enemyAlive;
          }
        }

        if (inClutch && enemiesFaced > 0) {
          attempts += 1;
          if (winningTeam == myTeam && !died) wins += 1;
        }
      }

      return _MatchClutches(attempts: attempts, wins: wins);
    } catch (_) {
      return const _MatchClutches();
    }
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E1E21) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  Widget _buildRRTrendChart(Color textColor) {
    if (_rrHistory.isEmpty) return const SizedBox.shrink();

    final chronological = _rrHistory.reversed.toList();
    final spots = <FlSpot>[];
    final changes = <int>[];
    double cumulative = 0;

    for (int i = 0; i < chronological.length; i++) {
      final entry = chronological[i];
      if (entry is! Map) continue;
      final change = (entry['mmr_change_to_last_game'] as num?)?.toInt() ?? 0;
      final elo = (entry['elo'] as num?)?.toDouble();
      changes.add(change);
      double y;
      if (elo != null) {
        y = elo;
      } else {
        cumulative += change;
        y = cumulative;
      }
      spots.add(FlSpot(i.toDouble(), y));
    }

    if (spots.length < 2) return const SizedBox.shrink();

    final yValues = spots.map((s) => s.y);
    final minY = yValues.reduce((a, b) => a < b ? a : b);
    final maxY = yValues.reduce((a, b) => a > b ? a : b);
    final span = (maxY - minY).abs();
    final padding = span > 0 ? span * 0.15 : 10.0;

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RR Trend',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last ${spots.length} ranked matches',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: minY - padding,
                maxY: maxY + padding,
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                      final idx = s.x.toInt();
                      final change = (idx >= 0 && idx < changes.length)
                          ? changes[idx]
                          : 0;
                      return LineTooltipItem(
                        '${change >= 0 ? '+' : ''}$change RR',
                        TextStyle(
                          color: change >= 0
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.blueAccent,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        final change = (index >= 0 && index < changes.length)
                            ? changes[index]
                            : 0;
                        return FlDotCirclePainter(
                          radius: 3,
                          color: change >= 0
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          strokeWidth: 0,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blueAccent.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 22,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(
          l10n.genericError(_error!),
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (totalMatches == 0) {
      return Center(
        child: Text(
          l10n.noMatchesFoundForMode,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    final kd = totalDeaths > 0
        ? (totalKills / totalDeaths).toStringAsFixed(2)
        : totalKills.toString();
    final winrate = totalMatches > 0
        ? ((totalWins / totalMatches) * 100).toStringAsFixed(1)
        : '0';
    final acs = totalRoundsPlayed > 0
        ? (totalScore / totalRoundsPlayed).round().toString()
        : '0';
    final hoursPlayed = (totalPlaytimeMillis / (1000 * 60 * 60))
        .toStringAsFixed(1);
    final clutchRate = totalClutchAttempts > 0
        ? ((totalClutchWins / totalClutchAttempts) * 100).toStringAsFixed(1)
        : '0';

    final sessionKd = sessionDeaths > 0
        ? (sessionKills / sessionDeaths).toStringAsFixed(2)
        : sessionKills.toString();
    final sessionWinrate = sessionMatches > 0
        ? ((sessionWins / sessionMatches) * 100).toStringAsFixed(1)
        : '0';
    final sessionAcs = sessionRoundsPlayed > 0
        ? (sessionScore / sessionRoundsPlayed).round().toString()
        : '0';

    final textColor = widget.isDark ? Colors.white : Colors.black;

    final sortedAgents = agentStats.entries.toList()
      ..sort((a, b) => b.value['matches'].compareTo(a.value['matches']));

    final List<PieChartSectionData> pieSections = [];
    int colorIndex = 0;
    final List<Color> colors = [
      Colors.redAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.tealAccent,
    ];

    for (var agent in sortedAgents.take(5)) {
      pieSections.add(
        PieChartSectionData(
          value: agent.value['matches'].toDouble(),
          title: '${agent.key}\n${agent.value['matches']}',
          color: colors[colorIndex % colors.length],
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      colorIndex++;
    }

    final sortedMaps = mapStats.entries.toList()
      ..sort((a, b) => b.value['matches'].compareTo(a.value['matches']));

    final List<BarChartGroupData> barGroups = [];
    int mapIndex = 0;
    for (var map in sortedMaps.take(5)) {
      final winRate = map.value['matches'] > 0
          ? (map.value['wins'] / map.value['matches']) * 100
          : 0.0;
      barGroups.add(
        BarChartGroupData(
          x: mapIndex,
          barRods: [
            BarChartRodData(
              toY: winRate,
              color: Colors.blueAccent,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
      mapIndex++;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.performanceLastMatches(totalMatches),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              DropdownButton<String>(
                value: _selectedMode,
                dropdownColor: widget.isDark ? Colors.grey[900] : Colors.white,
                style: GoogleFonts.inter(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
                underline: const SizedBox(),
                items:
                    ['All', 'Competitive', 'Unrated', 'Deathmatch', 'Swiftplay']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedMode = val;
                      _calculateStats();
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildSectionCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildStatItem(
                    l10n.statKd,
                    kd,
                    double.parse(kd) >= 1.0 ? Colors.green : Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    l10n.statWinrate,
                    '$winrate%',
                    double.parse(winrate) >= 50.0 ? Colors.green : Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(l10n.statAcs, acs, Colors.blueAccent),
                ),
                Expanded(
                  child: _buildStatItem(
                    l10n.statHours,
                    '${hoursPlayed}h',
                    Colors.orangeAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildRRTrendChart(textColor),
          if (_rrHistory.isNotEmpty) const SizedBox(height: 16),

          _buildSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.thisSession,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Switch(
                      value: _showSessionStats,
                      onChanged: (val) =>
                          setState(() => _showSessionStats = val),
                    ),
                  ],
                ),
                if (_showSessionStats) ...[
                  const SizedBox(height: 12),
                  if (sessionMatches == 0)
                    Text(
                      l10n.noMatchesThisSessionYet,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${l10n.sessionMatchesPlayed}: $sessionMatches  '
                          '(${l10n.sessionRecordWinLoss(sessionWins, sessionLosses)})',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _buildStatItem(
                                l10n.statKd,
                                sessionKd,
                                double.parse(sessionKd) >= 1.0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                l10n.statWinrate,
                                '$sessionWinrate%',
                                double.parse(sessionWinrate) >= 50.0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                l10n.statAcs,
                                sessionAcs,
                                Colors.blueAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (totalClutchAttempts > 0)
            _buildSectionCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Colors.amber,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.clutchDetectorTitle,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.clutchDetectorSubtitle(
                            totalClutchWins,
                            totalClutchAttempts,
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatItem(
                    l10n.statClutchRate,
                    '$clutchRate%',
                    double.parse(clutchRate) >= 50.0
                        ? Colors.green
                        : Colors.amber,
                  ),
                ],
              ),
            ),
          if (totalClutchAttempts > 0) const SizedBox(height: 16),

          _buildSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.mostPlayedAgents,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
                  child: pieSections.isEmpty
                      ? const SizedBox.shrink()
                      : PieChart(
                          PieChartData(
                            sections: pieSections,
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.mapWinratePercent,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
                  child: barGroups.isEmpty
                      ? const SizedBox.shrink()
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: 100,
                            barTouchData: BarTouchData(enabled: false),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget:
                                      (double value, TitleMeta meta) {
                                        if (value.toInt() >=
                                            sortedMaps.length) {
                                          return const SizedBox.shrink();
                                        }
                                        final name =
                                            sortedMaps[value.toInt()].key;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8.0,
                                          ),
                                          child: Text(
                                            name.substring(0, 3).toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        );
                                      },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      '${value.toInt()}%',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: 20,
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: barGroups,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
