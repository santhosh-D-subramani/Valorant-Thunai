import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';
import 'package:valorant_thunai/utils/match_stats_calculator.dart';
import 'package:valorant_thunai/utils/format_utils.dart';

const _spikeIconUrl =
    'https://media.valorant-api.com/gamemodes/96bd3920-4f36-d026-2b28-c683eb0bcac5/displayicon.png';

class _SpikeIcon extends StatelessWidget {
  final Color color;
  final double size;
  const _SpikeIcon({required this.color, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: _spikeIconUrl,
      width: size,
      height: size,
      color: color,
      errorWidget: (context, url, error) =>
          Icon(Icons.dangerous, size: size, color: color),
    );
  }
}

enum _RoundEventType { kill, plant, defuse, explosion }

class _RoundEvent {
  final _RoundEventType type;
  final int timeMillis;
  final Map<String, dynamic>? kill;
  final String? actorPuuid;
  final String? site;

  _RoundEvent.kill(this.kill)
    : type = _RoundEventType.kill,
      timeMillis = (kill!['roundTime'] as int?) ?? 0,
      actorPuuid = kill['killer']?.toString(),
      site = null;

  _RoundEvent.plant({
    required this.timeMillis,
    required this.actorPuuid,
    this.site,
  }) : type = _RoundEventType.plant,
       kill = null;

  _RoundEvent.defuse({required this.timeMillis, required this.actorPuuid})
    : type = _RoundEventType.defuse,
      kill = null,
      site = null;

  _RoundEvent.explosion({required this.timeMillis, this.site})
    : type = _RoundEventType.explosion,
      kill = null,
      actorPuuid = null;
}

class MatchRoundDetailScreen extends StatefulWidget {
  final List<RoundSummary> rounds;
  final int initialIndex;
  final Map<String, String> playerNames;
  final Map<String, String> weaponNames;
  final Map<String, String> weaponIcons;
  final Map<String, dynamic> agentIconByPuuid;
  final Map<String, String> characterUuidByPuuid;
  final Map<String, Map<String, dynamic>> agentsByUuid;
  final Map<String, dynamic>? mapData;
  final String focusedPuuid;
  final Map<String, String> teamBySubject;
  final List<RoundEconomyEntry> economy;

  const MatchRoundDetailScreen({
    super.key,
    required this.rounds,
    required this.initialIndex,
    required this.playerNames,
    required this.weaponNames,
    required this.weaponIcons,
    required this.agentIconByPuuid,
    required this.characterUuidByPuuid,
    required this.agentsByUuid,
    required this.mapData,
    required this.focusedPuuid,
    required this.teamBySubject,
    this.economy = const [],
  });

  @override
  State<MatchRoundDetailScreen> createState() => _MatchRoundDetailScreenState();
}

class _MatchRoundDetailScreenState extends State<MatchRoundDetailScreen> {
  late int _index;
  int? _selectedEventIndex;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  void _changeRound(int newIndex) {
    setState(() {
      _index = newIndex;
      _selectedEventIndex = null;
    });
  }

  String _resolveName(String? puuid) {
    if (puuid == null || puuid.isEmpty) return '';
    final l10n = AppLocalizations.of(context)!;
    return widget.playerNames[puuid] ?? l10n.unknownAgent;
  }

  String? _reasonLabel(AppLocalizations l10n, String? resultCode) {
    switch ((resultCode ?? '').toLowerCase()) {
      case 'elimination':
        return l10n.roundReasonElimination;
      case 'detonate':
      case 'bombdetonated':
        return l10n.roundReasonDetonate;
      case 'defuse':
        return l10n.roundReasonDefuse;
      case 'time':
      case 'roundtimeexpired':
        return l10n.roundReasonTime;
      case 'surrendered':
        return l10n.roundReasonSurrendered;
      default:
        return null;
    }
  }

  List<_RoundEvent> _buildEvents(RoundSummary round) {
    final events = <_RoundEvent>[
      for (final k in round.kills) _RoundEvent.kill(k),
    ];
    final wasPlanted =
        round.bombPlanter != null && round.bombPlanter!.isNotEmpty;
    final wasDefused =
        round.bombDefuser != null && round.bombDefuser!.isNotEmpty;

    if (wasPlanted && round.plantRoundTime != null) {
      events.add(
        _RoundEvent.plant(
          timeMillis: round.plantRoundTime!,
          actorPuuid: round.bombPlanter,
          site: round.plantSite,
        ),
      );
    }
    if (wasDefused && round.defuseRoundTime != null) {
      events.add(
        _RoundEvent.defuse(
          timeMillis: round.defuseRoundTime!,
          actorPuuid: round.bombDefuser,
        ),
      );
    } else if (wasPlanted &&
        round.plantRoundTime != null &&
        (round.resultCode ?? '').toLowerCase().contains('deton')) {
      events.add(
        _RoundEvent.explosion(
          timeMillis: round.plantRoundTime! + 45000,
          site: round.plantSite,
        ),
      );
    }
    events.sort((a, b) => a.timeMillis.compareTo(b.timeMillis));
    return events;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final round = widget.rounds[_index];
    final total = widget.rounds.length;
    final events = _buildEvents(round);
    final selected =
        _selectedEventIndex != null && _selectedEventIndex! < events.length
        ? events[_selectedEventIndex!]
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.roundDetailsTitle), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _index > 0
                        ? () => _changeRound(_index - 1)
                        : null,
                  ),
                  Text(
                    l10n.roundOfTotalFormat(round.roundNum + 1, total),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _index < total - 1
                        ? () => _changeRound(_index + 1)
                        : null,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.economy.isNotEmpty) ...[
                    _RoundEconomyChart(
                      economy: widget.economy,
                      currentRoundNum: round.roundNum,
                      onSelectRound: (roundNum) {
                        final idx = widget.rounds.indexWhere(
                          (r) => r.roundNum == roundNum,
                        );
                        if (idx != -1) _changeRound(idx);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_reasonLabel(l10n, round.resultCode)
                      case final reason?) ...[
                    Text(
                      reason,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _RoundMinimap(
                    round: round,
                    mapData: widget.mapData,
                    teamBySubject: widget.teamBySubject,
                    agentIconByPuuid: widget.agentIconByPuuid,
                    selected: selected,
                  ),
                  const SizedBox(height: 16),
                  _EventTimeline(
                    events: events,
                    teamBySubject: widget.teamBySubject,
                    selectedIndex: _selectedEventIndex,
                    onSelect: (i) => setState(() => _selectedEventIndex = i),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      selected != null
                          ? FormatUtils.formatRoundClock(selected.timeMillis)
                          : l10n.roundEventCountFormat(events.length),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (events.isEmpty)
                    Text(
                      l10n.noKillsThisRound,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    ...events.asMap().entries.map(
                      (entry) => _EventRow(
                        event: entry.value,
                        isSelected: entry.key == _selectedEventIndex,
                        playerNames: widget.playerNames,
                        weaponNames: widget.weaponNames,
                        weaponIcons: widget.weaponIcons,
                        agentIconByPuuid: widget.agentIconByPuuid,
                        characterUuidByPuuid: widget.characterUuidByPuuid,
                        agentsByUuid: widget.agentsByUuid,
                        teamBySubject: widget.teamBySubject,
                        focusedPuuid: widget.focusedPuuid,
                        resolveName: _resolveName,
                        onTap: () =>
                            setState(() => _selectedEventIndex = entry.key),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundEconomyChart extends StatelessWidget {
  final List<RoundEconomyEntry> economy;
  final int currentRoundNum;
  final ValueChanged<int> onSelectRound;

  const _RoundEconomyChart({
    required this.economy,
    required this.currentRoundNum,
    required this.onSelectRound,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final maxLoadout = economy
        .map((e) => e.loadoutValue)
        .fold<int>(1, (a, b) => a > b ? a : b);
    const barAreaHeight = 64.0;
    const minBarHeight = 6.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.economyOverviewLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: barAreaHeight + 22,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final entry in economy)
                    GestureDetector(
                      onTap: () => onSelectRound(entry.roundNum),
                      child: Container(
                        width: 26,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        clipBehavior: Clip.hardEdge,
                        decoration: const BoxDecoration(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: barAreaHeight,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  width: 14,
                                  height:
                                      (barAreaHeight *
                                              entry.loadoutValue /
                                              maxLoadout)
                                          .clamp(minBarHeight, barAreaHeight),
                                  decoration: BoxDecoration(
                                    color: _buyColor(entry.buyType),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(3),
                                    ),
                                    border: entry.roundNum == currentRoundNum
                                        ? Border.all(
                                            color: theme.colorScheme.onSurface,
                                            width: 1.6,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Icon(
                              entry.won
                                  ? Icons.arrow_drop_up
                                  : Icons.arrow_drop_down,
                              size: 16,
                              color: entry.won
                                  ? Colors.green
                                  : Colors.redAccent,
                            ),
                            Text(
                              '${entry.roundNum + 1}',
                              textScaler: TextScaler.noScaling,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: entry.roundNum == currentRoundNum
                                    ? FontWeight.w900
                                    : FontWeight.w500,
                                color: entry.roundNum == currentRoundNum
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _legendDot(Colors.grey, l10n.buyTypeEco),
              _legendDot(Colors.orangeAccent, l10n.buyTypeSemi),
              _legendDot(Colors.blueAccent, l10n.buyTypeBonus),
              _legendDot(Colors.green, l10n.buyTypeFull),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _EventTimeline extends StatelessWidget {
  final List<_RoundEvent> events;
  final Map<String, String> teamBySubject;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  const _EventTimeline({
    required this.events,
    required this.teamBySubject,
    required this.selectedIndex,
    required this.onSelect,
  });

  Widget _markerIcon(_RoundEventType type) {
    switch (type) {
      case _RoundEventType.plant:
        return const _SpikeIcon(color: Colors.white, size: 12);
      case _RoundEventType.defuse:
        return const _SpikeIcon(color: Colors.white, size: 12);
      case _RoundEventType.explosion:
        return const _SpikeIcon(color: Colors.white, size: 12);
      case _RoundEventType.kill:
        return const Icon(Icons.close, size: 12, color: Colors.white);
    }
  }

  Color _colorFor(BuildContext context, _RoundEvent event) {
    switch (event.type) {
      case _RoundEventType.plant:
        return Colors.orangeAccent;
      case _RoundEventType.explosion:
        return Colors.deepOrange;
      case _RoundEventType.defuse:
        return Colors.blueAccent;
      case _RoundEventType.kill:
        final team = teamBySubject[event.actorPuuid];
        return team == 'Blue' ? Colors.blueAccent : Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (events.isEmpty) return const SizedBox.shrink();
    final maxTime = events
        .map((e) => e.timeMillis)
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 44,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth - 24;
          return Stack(
            children: [
              Positioned(
                left: 12,
                right: 12,
                top: 21,
                child: Container(
                  height: 2,
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              for (var i = 0; i < events.length; i++)
                Positioned(
                  left:
                      12 +
                      (maxTime > 0 ? events[i].timeMillis / maxTime : 0) *
                          width -
                      11,
                  top: 0,
                  child: GestureDetector(
                    onTap: () => onSelect(i),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _colorFor(context, events[i]),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: i == selectedIndex
                              ? theme.colorScheme.onSurface
                              : Colors.white,
                          width: i == selectedIndex ? 2.5 : 1.2,
                        ),
                      ),
                      child: Center(child: _markerIcon(events[i].type)),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final _RoundEvent event;
  final bool isSelected;
  final Map<String, String> playerNames;
  final Map<String, String> weaponNames;
  final Map<String, String> weaponIcons;
  final Map<String, dynamic> agentIconByPuuid;
  final Map<String, String> characterUuidByPuuid;
  final Map<String, Map<String, dynamic>> agentsByUuid;
  final Map<String, String> teamBySubject;
  final String focusedPuuid;
  final String Function(String?) resolveName;
  final VoidCallback onTap;

  const _EventRow({
    required this.event,
    required this.isSelected,
    required this.playerNames,
    required this.weaponNames,
    required this.weaponIcons,
    required this.agentIconByPuuid,
    required this.characterUuidByPuuid,
    required this.agentsByUuid,
    required this.teamBySubject,
    required this.focusedPuuid,
    required this.resolveName,
    required this.onTap,
  });

  Widget _avatar(String? puuid) {
    final icon = puuid != null ? agentIconByPuuid[puuid] : null;
    if (icon == null) {
      return const CircleAvatar(
        radius: 14,
        child: Icon(Icons.person, size: 16),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CachedNetworkImage(
        imageUrl: icon,
        width: 28,
        height: 28,
        fit: BoxFit.cover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final timeLabel = FormatUtils.formatRoundClock(event.timeMillis);

    Widget content;
    Color rowColor;
    bool involvesFocused = false;

    switch (event.type) {
      case _RoundEventType.kill:
        final killerId = event.kill!['killer']?.toString();
        final victimId = event.kill!['victim']?.toString();
        final killerTeam = teamBySubject[killerId];
        rowColor = killerTeam == 'Blue' ? Colors.blueAccent : Colors.redAccent;
        involvesFocused = killerId == focusedPuuid || victimId == focusedPuuid;
        final killerCharacterUuid = characterUuidByPuuid[killerId];
        final killerAgentData = killerCharacterUuid != null
            ? agentsByUuid[killerCharacterUuid]
            : null;
        final weaponInfo = FormatUtils.resolveKillWeapon(
          finishingDamage:
              event.kill!['finishingDamage'] as Map<String, dynamic>?,
          weaponNamesByUuid: weaponNames,
          weaponIconsByUuid: weaponIcons,
          killerAgentData: killerAgentData,
        );
        content = Row(
          children: [
            _avatar(killerId),
            const SizedBox(width: 8),
            Expanded(
              child: weaponInfo.iconUrl != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Transform.flip(
                        flipX: weaponInfo.isWeaponIcon,
                        child: CachedNetworkImage(
                          imageUrl: weaponInfo.iconUrl!,
                          height: 22,
                          fit: BoxFit.contain,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    )
                  : Text(
                      weaponInfo.label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            _avatar(victimId),
          ],
        );
        break;
      case _RoundEventType.plant:
        rowColor = Colors.orangeAccent;
        content = Row(
          children: [
            _avatar(event.actorPuuid),
            const SizedBox(width: 8),
            const _SpikeIcon(color: Colors.orangeAccent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.plantedAtFormat(resolveName(event.actorPuuid), timeLabel),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
        break;
      case _RoundEventType.defuse:
        rowColor = Colors.blueAccent;
        content = Row(
          children: [
            _avatar(event.actorPuuid),
            const SizedBox(width: 8),
            const _SpikeIcon(color: Colors.blueAccent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.defusedAtFormat(resolveName(event.actorPuuid), timeLabel),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
        break;
      case _RoundEventType.explosion:
        rowColor = Colors.deepOrange;
        content = Row(
          children: [
            const _SpikeIcon(color: Colors.deepOrange, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.explodedAtFormat(timeLabel),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: rowColor.withValues(
            alpha: isSelected ? 0.22 : (involvesFocused ? 0.16 : 0.08),
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.onSurface
                : rowColor.withValues(alpha: involvesFocused ? 0.6 : 0),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(
                timeLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

class _RoundMinimap extends StatelessWidget {
  final RoundSummary round;
  final Map<String, dynamic>? mapData;
  final Map<String, String> teamBySubject;
  final Map<String, dynamic> agentIconByPuuid;
  final _RoundEvent? selected;

  const _RoundMinimap({
    required this.round,
    required this.mapData,
    required this.teamBySubject,
    required this.agentIconByPuuid,
    required this.selected,
  });

  bool _hasKnownSite(String? site) {
    if (site == null || site.isEmpty) return false;
    return site.toLowerCase() != 'unknown';
  }

  Offset? _project(Map<String, dynamic>? location) {
    if (location == null || mapData == null) return null;
    final x = (location['x'] as num?)?.toDouble();
    final y = (location['y'] as num?)?.toDouble();
    final xMultiplier = (mapData!['xMultiplier'] as num?)?.toDouble();
    final yMultiplier = (mapData!['yMultiplier'] as num?)?.toDouble();
    final xScalarToAdd = (mapData!['xScalarToAdd'] as num?)?.toDouble();
    final yScalarToAdd = (mapData!['yScalarToAdd'] as num?)?.toDouble();
    if (x == null || y == null || xMultiplier == null || yMultiplier == null) {
      return null;
    }
    final fracX = (y * xMultiplier) + (xScalarToAdd ?? 0);
    final fracY = (x * yMultiplier) + (yScalarToAdd ?? 0);
    if (fracX.isNaN || fracY.isNaN) return null;
    return Offset(fracX.clamp(0.0, 1.0), fracY.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minimapUrl = mapData?['displayIcon']?.toString();
    final selectedKill = selected?.type == _RoundEventType.kill
        ? selected!.kill
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (minimapUrl != null)
              CachedNetworkImage(imageUrl: minimapUrl, fit: BoxFit.cover)
            else
              Container(color: theme.colorScheme.surfaceContainerHighest),
            LayoutBuilder(
              builder: (context, constraints) {
                final markers = <Widget>[];

                Offset? killerLocationFor(
                  Map<String, dynamic> kill,
                  String? killerId,
                ) {
                  final playerLocations =
                      (kill['playerLocations'] as List?) ?? const [];
                  for (final entry in playerLocations) {
                    if (entry is Map &&
                        entry['subject']?.toString() == killerId) {
                      return _project(
                        entry['location'] as Map<String, dynamic>?,
                      );
                    }
                  }
                  return null;
                }

                for (final kill in round.kills) {
                  final isSelectedKill = kill == selectedKill;
                  final victimLoc = _project(
                    kill['victimLocation'] as Map<String, dynamic>?,
                  );
                  if (victimLoc == null) continue;
                  final killerId = kill['killer']?.toString();
                  final victimId = kill['victim']?.toString();
                  final killerTeam = teamBySubject[killerId];
                  final color = killerTeam == 'Blue'
                      ? Colors.blueAccent
                      : Colors.redAccent;

                  if (isSelectedKill) {
                    final killerLoc =
                        killerLocationFor(kill, killerId) ?? victimLoc;
                    final killerIcon = agentIconByPuuid[killerId];
                    final victimIcon = agentIconByPuuid[victimId];

                    markers.add(
                      CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        painter: _KillLinePainter(
                          from: Offset(
                            killerLoc.dx * constraints.maxWidth,
                            killerLoc.dy * constraints.maxHeight,
                          ),
                          to: Offset(
                            victimLoc.dx * constraints.maxWidth,
                            victimLoc.dy * constraints.maxHeight,
                          ),
                          color: color,
                        ),
                      ),
                    );
                    markers.add(
                      _MapPlayerMarker(
                        left: killerLoc.dx * constraints.maxWidth,
                        top: killerLoc.dy * constraints.maxHeight,
                        color: color,
                        iconUrl: killerIcon,
                        large: true,
                      ),
                    );
                    markers.add(
                      _MapPlayerMarker(
                        left: victimLoc.dx * constraints.maxWidth,
                        top: victimLoc.dy * constraints.maxHeight,
                        color: color,
                        iconUrl: victimIcon,
                        large: true,
                        showDeathMark: true,
                      ),
                    );
                  } else {
                    markers.add(
                      Positioned(
                        left: victimLoc.dx * constraints.maxWidth - 5,
                        top: victimLoc.dy * constraints.maxHeight - 5,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color.withValues(
                              alpha: selected == null ? 0.9 : 0.35,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                        ),
                      ),
                    );
                  }
                }
                return Stack(children: markers);
              },
            ),
            if (round.bombPlanter == null || round.bombPlanter!.isEmpty)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.spikeNotPlanted,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              )
            else if (_hasKnownSite(round.plantSite))
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Site ${round.plantSite}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MapPlayerMarker extends StatelessWidget {
  final double left;
  final double top;
  final Color color;
  final dynamic iconUrl;
  final bool large;
  final bool showDeathMark;

  const _MapPlayerMarker({
    required this.left,
    required this.top,
    required this.color,
    required this.iconUrl,
    this.large = false,
    this.showDeathMark = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = large ? 32.0 : 20.0;
    return Positioned(
      left: left - size / 2,
      top: top - size / 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8),
              ],
            ),
            child: iconUrl != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: iconUrl,
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(Icons.person, color: color),
          ),
          if (showDeathMark)
            Positioned.fill(
              child: Icon(Icons.close, color: Colors.redAccent, size: size),
            ),
        ],
      ),
    );
  }
}

class _KillLinePainter extends CustomPainter {
  final Offset from;
  final Offset to;
  final Color color;

  _KillLinePainter({required this.from, required this.to, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(from, to, paint);
  }

  @override
  bool shouldRepaint(covariant _KillLinePainter oldDelegate) {
    return oldDelegate.from != from ||
        oldDelegate.to != to ||
        oldDelegate.color != color;
  }
}
