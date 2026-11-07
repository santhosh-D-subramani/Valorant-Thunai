import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';
import 'package:valorant_thunai/utils/match_stats_calculator.dart';
import 'package:valorant_thunai/utils/format_utils.dart';
import 'package:valorant_thunai/providers/display_settings_provider.dart';
import 'package:valorant_thunai/screens/matches/match_round_detail_screen.dart';

enum ScoreboardSortMetric { acs, adr, kast, kills, deaths }

class _StatAccordion extends StatelessWidget {
  final String title;
  final String myValue;
  final String lobbyAvgLabel;
  final int percentile;
  final List<_RankedPlayer> ranked;
  final String focusedPuuid;

  const _StatAccordion({
    required this.title,
    required this.myValue,
    required this.lobbyAvgLabel,
    required this.percentile,
    required this.ranked,
    required this.focusedPuuid,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              Text(
                myValue,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          subtitle: Text(
            l10n.betterThanPercentFormat(percentile),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            ...ranked.map((r) {
              final isMe = r.puuid == focusedPuuid;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '#${r.rank}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        r.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isMe
                              ? FontWeight.w800
                              : FontWeight.normal,
                          color: isMe
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      r.value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isMe
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 20),
            Text(
              l10n.lobbyAvgFormat(lobbyAvgLabel),
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankedPlayer {
  final int rank;
  final String puuid;
  final String name;
  final String value;
  _RankedPlayer(this.rank, this.puuid, this.name, this.value);
}

List<_RankedPlayer> _rankPlayers(
  Map<String, dynamic> playerNames,
  Map<String, PlayerAggStats> stats,
  double Function(PlayerAggStats) metric,
) {
  final entries = stats.values.where((s) => s.roundsPlayed > 0).toList()
    ..sort((a, b) => metric(b).compareTo(metric(a)));
  return [
    for (var i = 0; i < entries.length; i++)
      _RankedPlayer(
        i + 1,
        entries[i].subject,
        playerNames[entries[i].subject]?.toString() ?? '???',
        metric(entries[i]).toStringAsFixed(1),
      ),
  ];
}

int _percentileOf(List<_RankedPlayer> ranked, String puuid) {
  if (ranked.isEmpty) return 0;
  final idx = ranked.indexWhere((r) => r.puuid == puuid);
  if (idx == -1) return 0;
  return (((ranked.length - 1 - idx) /
              (ranked.length - 1 == 0 ? 1 : ranked.length - 1)) *
          100)
      .round();
}

class SummaryTab extends StatelessWidget {
  final MatchAnalysis analysis;
  final Map<String, String> playerNames;
  final String focusedPuuid;

  const SummaryTab({
    super.key,
    required this.analysis,
    required this.playerNames,
    required this.focusedPuuid,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final me = analysis.playerStats[focusedPuuid];
    if (me == null || me.roundsPlayed == 0) {
      return Center(child: Text(l10n.noDetailsAvailable));
    }

    final allStats = analysis.playerStats;

    Widget accordionFor(
      String title,
      double Function(PlayerAggStats) metric,
      String Function(double) formatter,
    ) {
      final ranked = _rankPlayers(playerNames, allStats, metric);
      final avg = MatchAnalysis.lobbyAverage(allStats.values, metric);
      return _StatAccordion(
        title: title,
        myValue: formatter(metric(me)),
        lobbyAvgLabel: formatter(avg),
        percentile: _percentileOf(ranked, focusedPuuid),
        ranked: ranked,
        focusedPuuid: focusedPuuid,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          l10n.lobbyAverageHeader,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        accordionFor(l10n.acs, (p) => p.acs, (v) => v.round().toString()),
        accordionFor(l10n.adr, (p) => p.adr, (v) => v.round().toString()),
        accordionFor(
          l10n.hsPercent,
          (p) => p.hsPercent,
          (v) => '${v.round()}%',
        ),
        accordionFor(l10n.kast, (p) => p.kast, (v) => '${v.round()}%'),
        accordionFor(l10n.kdHeader, (p) => p.kd, (v) => v.toStringAsFixed(2)),
        accordionFor(
          l10n.fkPerRoundHeader,
          (p) => p.fkPerRound,
          (v) => v.toStringAsFixed(2),
        ),

        const SizedBox(height: 24),
        Text(
          l10n.halvesHeader,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _HalfCard(
                title: l10n.attackHalf,
                stats: analysis.attack,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HalfCard(
                title: l10n.defenseHalf,
                stats: analysis.defense,
                color: Colors.greenAccent,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        Text(
          l10n.matchHighlightsHeader,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _HighlightsList(analysis: analysis),

        const SizedBox(height: 24),
        const StatAbbreviationLegend(),
      ],
    );
  }
}

class _HalfCard extends StatelessWidget {
  final String title;
  final HalfStats stats;
  final Color color;

  const _HalfCard({
    required this.title,
    required this.stats,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    Widget row(String label, int value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text('$value', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        ],
      ),
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: color,
              ),
            ),
            const Divider(height: 14),
            row(l10n.kills, stats.kills),
            row(l10n.deathsStat, stats.deaths),
            row(l10n.assists, stats.assists),
            row(l10n.plantsStat, stats.plants),
            row(l10n.defusesStat, stats.defuses),
            row(l10n.firstBloodsStat, stats.firstBloods),
            row(l10n.firstDeathsStat, stats.firstDeaths),
          ],
        ),
      ),
    );
  }
}

class _HighlightsList extends StatelessWidget {
  final MatchAnalysis analysis;
  const _HighlightsList({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final items = <Widget>[];
    final sortedMultiKills = [...analysis.multiKills]
      ..sort((a, b) => a.roundNum.compareTo(b.roundNum));
    for (final mk in sortedMultiKills) {
      items.add(
        _HighlightTile(
          icon: Icons.bolt,
          color: Colors.amber,
          text: l10n.multiKillFormat(mk.kills, mk.roundNum + 1),
        ),
      );
    }
    final sortedClutches = [...analysis.clutches]
      ..sort((a, b) => a.roundNum.compareTo(b.roundNum));
    for (final c in sortedClutches) {
      items.add(
        _HighlightTile(
          icon: c.won ? Icons.emoji_events : Icons.close,
          color: c.won ? Colors.green : Colors.redAccent,
          text: c.won
              ? l10n.clutchWonFormat(c.enemiesFaced, c.roundNum + 1)
              : l10n.clutchLostFormat(c.enemiesFaced, c.roundNum + 1),
        ),
      );
    }

    if (items.isEmpty) {
      return Text(
        l10n.noHighlightsAvailable,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return Column(children: items);
  }
}

class _HighlightTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _HighlightTile({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatAbbreviationLegend extends StatelessWidget {
  const StatAbbreviationLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final entries = <(String, String)>[
      (l10n.acs, l10n.abbrAcsFull),
      (l10n.adr, l10n.abbrAdrFull),
      (l10n.hsPercent, l10n.abbrHsFull),
      (l10n.kast, l10n.abbrKastFull),
      (l10n.kdHeader, l10n.abbrKdFull),
      (l10n.fkPerRoundHeader, l10n.abbrFkFull),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.statAbbreviationsHeader,
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 10),
          ...entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      e.$1,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.$2,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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
}

class ScoreboardTab extends StatelessWidget {
  final List<Map<String, dynamic>> players;
  final MatchAnalysis analysis;
  final Map<String, String> playerNames;
  final Map<String, dynamic> agentIconByPuuid;
  final Map<int, dynamic> competitiveTiers;
  final String viewerPuuid;
  final String viewerTeam;
  final String focusedPuuid;
  final ScoreboardSortMetric sortMetric;
  final ValueChanged<String> onFocusPlayer;
  final ValueChanged<String> onOpenProfile;

  const ScoreboardTab({
    super.key,
    required this.players,
    required this.analysis,
    required this.playerNames,
    required this.agentIconByPuuid,
    required this.competitiveTiers,
    required this.viewerPuuid,
    required this.viewerTeam,
    required this.focusedPuuid,
    required this.sortMetric,
    required this.onFocusPlayer,
    required this.onOpenProfile,
  });

  double _metricValue(PlayerAggStats? p) {
    if (p == null) return 0;
    switch (sortMetric) {
      case ScoreboardSortMetric.acs:
        return p.acs;
      case ScoreboardSortMetric.adr:
        return p.adr;
      case ScoreboardSortMetric.kast:
        return p.kast;
      case ScoreboardSortMetric.kills:
        return p.kills.toDouble();
      case ScoreboardSortMetric.deaths:
        return p.deaths.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final myTeamPlayers = players
        .where((p) => p['teamId'] == viewerTeam)
        .toList();
    final enemyTeamPlayers = players
        .where((p) => p['teamId'] != viewerTeam)
        .toList();
    for (final list in [myTeamPlayers, enemyTeamPlayers]) {
      list.sort(
        (a, b) =>
            _metricValue(analysis.playerStats[b['subject']])
                .compareTo(_metricValue(analysis.playerStats[a['subject']])),
      );
    }

    Widget teamSection(
      String label,
      Color color,
      List<Map<String, dynamic>> teamPlayers,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...teamPlayers.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final player = entry.value;
            final subject = player['subject']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ScoreboardPlayerAccordion(
                rank: rank,
                player: player,
                stats: analysis.playerStats[subject],
                name: playerNames[subject] ?? l10n.unknownAgent,
                agentIcon: agentIconByPuuid[subject],
                tierData: competitiveTiers[player['competitiveTier'] ?? 0],
                teamColor: color,
                isViewer: subject == viewerPuuid,
                isFocused: subject == focusedPuuid,
                onFocus: () => onFocusPlayer(subject),
                onOpenProfile: () => onOpenProfile(subject),
              ),
            );
          }),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        teamSection(
          l10n.myTeamLabel,
          Colors.greenAccent.shade400,
          myTeamPlayers,
        ),
        const SizedBox(height: 20),
        teamSection(l10n.enemyTeamLabel, Colors.redAccent, enemyTeamPlayers),
      ],
    );
  }
}

class _ScoreboardPlayerAccordion extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> player;
  final PlayerAggStats? stats;
  final String name;
  final dynamic agentIcon;
  final dynamic tierData;
  final Color teamColor;
  final bool isViewer;
  final bool isFocused;
  final VoidCallback onFocus;
  final VoidCallback onOpenProfile;

  const _ScoreboardPlayerAccordion({
    required this.rank,
    required this.player,
    required this.stats,
    required this.name,
    required this.agentIcon,
    required this.tierData,
    required this.teamColor,
    required this.isViewer,
    required this.isFocused,
    required this.onFocus,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final s = stats;
    final tierIcon = tierData?['smallIcon'];
    final tierName = tierData?['tierName']?.toString() ?? l10n.unrated;

    final chips = <Widget>[];
    for (final mk in s?.multiKills ?? const []) {
      chips.add(_chip(l10n.multiKillChipFormat(mk.kills), Colors.amber));
    }
    for (final c in s?.clutches ?? const []) {
      chips.add(
        _chip(
          c.won
              ? l10n.clutchChipWonFormat(c.enemiesFaced)
              : l10n.clutchChipLostFormat(c.enemiesFaced),
          c.won ? Colors.green : Colors.redAccent,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: teamColor.withValues(alpha: isFocused ? 0.16 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isViewer
              ? Colors.amber
              : (isFocused ? teamColor : theme.colorScheme.outlineVariant),
          width: isViewer || isFocused ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (_) => onFocus(),
          leading: SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          title: Row(
            children: [
              if (agentIcon != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: agentIcon,
                    width: 34,
                    height: 34,
                    fit: BoxFit.cover,
                  ),
                )
              else
                const Icon(Icons.person),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isViewer
                            ? FontWeight.w900
                            : FontWeight.w700,
                        fontSize: 13.5,
                        color: isViewer
                            ? Colors.amber.shade800
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    Row(
                      children: [
                        if (tierIcon != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: CachedNetworkImage(
                              imageUrl: tierIcon,
                              width: 14,
                              height: 14,
                            ),
                          ),
                        Flexible(
                          child: Text(
                            tierName,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${s?.kills ?? 0}/${s?.deaths ?? 0}/${s?.assists ?? 0}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    '${l10n.acs} ${s?.acs.round() ?? 0}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onOpenProfile,
                icon: const Icon(Icons.person_search, size: 16),
                label: Text(l10n.openProfileAction),
              ),
            ),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _statTile(l10n.adr, s?.adr.round().toString() ?? '0'),
                _statTile(l10n.hsPercent, '${s?.hsPercent.round() ?? 0}%'),
                _statTile(l10n.kast, '${s?.kast.round() ?? 0}%'),
                _statTile(l10n.firstBloodsStat, '${s?.firstKills ?? 0}'),
                _statTile(l10n.firstDeathsStat, '${s?.firstDeaths ?? 0}'),
                _statTile(l10n.plantsStat, '${s?.plants ?? 0}'),
              ],
            ),
            const SizedBox(height: 10),
            if (chips.isEmpty)
              Text(
                l10n.noChipsAvailable,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Wrap(spacing: 6, runSpacing: 6, children: chips),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class RoundsTab extends StatelessWidget {
  final MatchAnalysis analysis;
  final Map<String, String> playerNames;
  final Map<String, String> weaponNames;
  final Map<String, String> weaponIcons;
  final Map<String, dynamic> agentIconByPuuid;
  final Map<String, String> characterUuidByPuuid;
  final Map<String, Map<String, dynamic>> agentsByUuid;
  final Map<String, dynamic>? mapData;
  final String focusedPuuid;
  final String focusedTeam;
  final Map<String, String> teamBySubject;

  const RoundsTab({
    super.key,
    required this.analysis,
    required this.playerNames,
    required this.weaponNames,
    required this.weaponIcons,
    required this.agentIconByPuuid,
    required this.characterUuidByPuuid,
    required this.agentsByUuid,
    required this.mapData,
    required this.focusedPuuid,
    required this.focusedTeam,
    required this.teamBySubject,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final rounds = analysis.rounds;

    if (rounds.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            l10n.noRoundDataAvailable,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    void openRound(int index) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MatchRoundDetailScreen(
            rounds: rounds,
            initialIndex: index,
            playerNames: playerNames,
            weaponNames: weaponNames,
            weaponIcons: weaponIcons,
            agentIconByPuuid: agentIconByPuuid,
            characterUuidByPuuid: characterUuidByPuuid,
            agentsByUuid: agentsByUuid,
            mapData: mapData,
            focusedPuuid: focusedPuuid,
            teamBySubject: teamBySubject,
            economy: analysis.economy,
          ),
        ),
      );
    }

    final maxKills = rounds
        .map((r) => r.blueKills > r.redKills ? r.blueKills : r.redKills)
        .fold<int>(1, (a, b) => a > b ? a : b);
    final myColor = Colors.greenAccent.shade400;
    final enemyColor = Colors.redAccent;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          l10n.roundsOverviewHeader,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${l10n.myTeamLabel} ▲  •  ▼ ${l10n.enemyTeamLabel}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: rounds.asMap().entries.map((entry) {
              final r = entry.value;
              final myKills = focusedTeam == 'Blue' ? r.blueKills : r.redKills;
              final enemyKills = focusedTeam == 'Blue'
                  ? r.redKills
                  : r.blueKills;
              final wonByMe = r.winningTeam == focusedTeam;
              return Expanded(
                child: GestureDetector(
                  onTap: () => openRound(entry.key),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: (myKills / maxKills).clamp(
                                0.04,
                                1.0,
                              ),
                              child: Container(
                                color: myColor.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          height: 2,
                          color: wonByMe
                              ? myColor
                              : (r.winningTeam.isEmpty
                                    ? theme.colorScheme.outlineVariant
                                    : enemyColor),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: FractionallySizedBox(
                              heightFactor: (enemyKills / maxKills).clamp(
                                0.04,
                                1.0,
                              ),
                              child: Container(
                                color: enemyColor.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        ...rounds.asMap().entries.map((entry) {
          final index = entry.key;
          final r = entry.value;
          final wonByMe = r.winningTeam == focusedTeam;
          final planter = r.bombPlanter != null
              ? playerNames[r.bombPlanter]
              : null;
          final defuser = r.bombDefuser != null
              ? playerNames[r.bombDefuser]
              : null;
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: ListTile(
              onTap: () => openRound(index),
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: (wonByMe ? myColor : enemyColor).withValues(
                  alpha: 0.2,
                ),
                child: Icon(
                  wonByMe ? Icons.check : Icons.close,
                  size: 16,
                  color: wonByMe ? myColor : enemyColor,
                ),
              ),
              title: Text(
                l10n.roundNumberFormat(r.roundNum + 1),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                [
                  if (planter != null) l10n.plantedByFormat(planter),
                  if (defuser != null) l10n.defusedByFormat(defuser),
                  if (planter == null && defuser == null)
                    '${r.kills.length} kills',
                ].join(' • '),
                style: theme.textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          );
        }),
      ],
    );
  }
}

class DuelsTab extends StatelessWidget {
  final MatchAnalysis analysis;
  final Map<String, String> playerNames;
  final Map<String, dynamic> agentIconByPuuid;

  const DuelsTab({
    super.key,
    required this.analysis,
    required this.playerNames,
    required this.agentIconByPuuid,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (analysis.duels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            l10n.noDuelsAvailable,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final sorted = analysis.duels.values.toList()
      ..sort((a, b) => b.totalEngagements.compareTo(a.totalEngagements));

    final allPairs = analysis.allDuels.where((p) => p.total > 0).toList();
    final topRivalry = allPairs.isEmpty
        ? null
        : (allPairs.toList()..sort((a, b) => b.total.compareTo(a.total))).first;
    final biggestMismatch = allPairs.isEmpty
        ? null
        : (allPairs.toList()
                ..sort((a, b) => b.imbalance.compareTo(a.imbalance)))
              .first;

    final maxCount = sorted.fold<int>(
      1,
      (max, d) => [
        max,
        d.killsOnOpponent,
        d.deathsToOpponent,
      ].reduce((a, b) => a > b ? a : b),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            if (topRivalry != null)
              Expanded(
                child: _PairHighlightCard(
                  title: l10n.topRivalryHeader,
                  icon: Icons.sports_kabaddi,
                  color: Colors.deepPurpleAccent,
                  pair: topRivalry,
                  playerNames: playerNames,
                  agentIconByPuuid: agentIconByPuuid,
                ),
              ),
            if (topRivalry != null && biggestMismatch != null)
              const SizedBox(width: 12),
            if (biggestMismatch != null)
              Expanded(
                child: _PairHighlightCard(
                  title: l10n.biggestMismatchHeader,
                  icon: Icons.trending_down,
                  color: Colors.orangeAccent,
                  pair: biggestMismatch,
                  playerNames: playerNames,
                  agentIconByPuuid: agentIconByPuuid,
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          l10n.allDuelsHeader,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          l10n.duelsSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...sorted.map((d) {
          final name = playerNames[d.opponentPuuid] ?? '???';
          final icon = agentIconByPuuid[d.opponentPuuid];
          final netColor = d.net > 0
              ? Colors.green
              : d.net < 0
              ? Colors.redAccent
              : theme.colorScheme.onSurfaceVariant;
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (icon != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: icon,
                            width: 28,
                            height: 28,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        const Icon(Icons.person, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        l10n.netFormat(d.net > 0 ? '+${d.net}' : '${d.net}'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: netColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${d.deathsToOpponent}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: FractionallySizedBox(
                                alignment: Alignment.centerRight,
                                widthFactor: (d.deathsToOpponent / maxCount)
                                    .clamp(0.02, 1.0),
                                child: Container(
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.horizontal(
                                      left: Radius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: (d.killsOnOpponent / maxCount)
                                    .clamp(0.02, 1.0),
                                child: Container(
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Colors.greenAccent,
                                    borderRadius: BorderRadius.horizontal(
                                      right: Radius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${d.killsOnOpponent}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _PairHighlightCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final PairDuel pair;
  final Map<String, String> playerNames;
  final Map<String, dynamic> agentIconByPuuid;

  const _PairHighlightCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.pair,
    required this.playerNames,
    required this.agentIconByPuuid,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nameA = playerNames[pair.puuidA] ?? '???';
    final nameB = playerNames[pair.puuidB] ?? '???';
    final iconA = agentIconByPuuid[pair.puuidA];
    final iconB = agentIconByPuuid[pair.puuidB];

    Widget avatar(dynamic url) => url != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CachedNetworkImage(
              imageUrl: url,
              width: 26,
              height: 26,
              fit: BoxFit.cover,
            ),
          )
        : const Icon(Icons.person, size: 26);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              avatar(iconA),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  nameA,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${pair.aKills} - ${pair.bKills}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          Row(
            children: [
              avatar(iconB),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  nameB,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PerformanceTab extends StatelessWidget {
  final MatchAnalysis analysis;
  final DisplaySettings displaySettings;

  const PerformanceTab({
    super.key,
    required this.analysis,
    required this.displaySettings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final rounds = analysis.performance;

    if (rounds.isEmpty) {
      return Center(
        child: Text(
          l10n.noRoundDataAvailable,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final maxScore = rounds
        .map((r) => r.score)
        .fold<int>(1, (a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          l10n.performanceHeader,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: rounds.map((r) {
              final heightFactor = maxScore > 0 ? r.score / maxScore : 0.0;
              final barColor = r.won ? Colors.green : Colors.redAccent;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Tooltip(
                    message:
                        '${l10n.roundNumberFormat(r.roundNum + 1)}: ${FormatUtils.formatNumber(r.score, displaySettings)}',
                    child: FractionallySizedBox(
                      heightFactor: heightFactor.clamp(0.03, 1.0),
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        decoration: BoxDecoration(
                          color: barColor.withValues(alpha: 0.75),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        ...rounds.map(
          (r) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (r.won ? Colors.green : Colors.redAccent).withValues(
                alpha: 0.08,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    l10n.roundNumberFormat(r.roundNum + 1),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Icon(
                  r.isAttack ? Icons.arrow_upward : Icons.shield,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${r.kills}/${r.deaths}/${r.assists}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Text(
                  '${FormatUtils.formatNumber(r.damage, displaySettings)} dmg',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 40,
                  child: Text(
                    FormatUtils.formatNumber(r.score, displaySettings),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class EconomyTab extends StatelessWidget {
  final MatchAnalysis analysis;
  final DisplaySettings displaySettings;

  const EconomyTab({
    super.key,
    required this.analysis,
    required this.displaySettings,
  });

  Color _buyColor(String type) {
    switch (type) {
      case 'ECO':
        return Colors.grey;
      case 'SEMI':
        return Colors.orangeAccent;
      case 'BONUS':
        return Colors.blueAccent;
      default:
        return Colors.green;
    }
  }

  String _buyLabel(AppLocalizations l10n, String type) {
    switch (type) {
      case 'ECO':
        return l10n.buyTypeEco;
      case 'SEMI':
        return l10n.buyTypeSemi;
      case 'BONUS':
        return l10n.buyTypeBonus;
      default:
        return l10n.buyTypeFull;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final rounds = analysis.economy;

    if (rounds.isEmpty) {
      return Center(
        child: Text(
          l10n.noRoundDataAvailable,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          l10n.economyHeader,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        ...rounds.map((r) {
          final color = _buyColor(r.buyType);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: (r.won ? Colors.green : Colors.redAccent).withValues(
                alpha: 0.06,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    l10n.roundNumberFormat(r.roundNum + 1),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (r.isPistolRound)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        l10n.pistolRoundLabel,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.purpleAccent,
                        ),
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _buyLabel(l10n, r.buyType),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${l10n.loadoutValueLabel}: ${FormatUtils.formatNumber(r.loadoutValue, displaySettings)}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 8),
                Icon(
                  r.won ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: r.won ? Colors.green : Colors.redAccent,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
