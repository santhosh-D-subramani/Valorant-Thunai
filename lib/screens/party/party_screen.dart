import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/widgets/wavy_linear_progress_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:valorant_thunai/screens/profile/player_search_screen.dart';
import 'package:valorant_thunai/providers/party_provider.dart';
import 'package:valorant_thunai/providers/profile_provider.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/providers/auto_loadout_provider.dart';
import 'package:valorant_thunai/providers/friends_provider.dart';
import 'package:valorant_thunai/utils/cache_managers.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class PartyPage extends ConsumerStatefulWidget {
  final bool gameViewOnly;

  const PartyPage({super.key, this.gameViewOnly = false});

  @override
  ConsumerState<PartyPage> createState() => _PartyPageState();
}

class _PartyPageState extends ConsumerState<PartyPage>
    with SingleTickerProviderStateMixin {
  Timer? _uiTimer;
  late final AnimationController _pollLoaderController;

  @override
  void initState() {
    super.initState();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final partyState = ref.read(partyProvider);
        if (partyState.phase == PartyPhase.matchmaking ||
            partyState.state == 'MATCHMAKING') {
          setState(() {});
        }
      }
    });
    _pollLoaderController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _pollLoaderController.dispose();
    super.dispose();
  }

  String _getTimerText(String? queueEntryTime) {
    if (queueEntryTime == null) return '00:00';
    final entryTime = DateTime.tryParse(queueEntryTime)?.toLocal();
    if (entryTime == null) return '00:00';

    final duration = DateTime.now().difference(entryTime);
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _resolveMapName(String mapUrl, Map<String, dynamic> mapsMap) {
    if (mapUrl.isEmpty) return 'Unknown Map';
    final lower = mapUrl.toLowerCase();
    if (mapsMap.containsKey(lower)) {
      return mapsMap[lower]?['displayName'] ?? mapUrl.split('/').last;
    }
    for (var m in mapsMap.values) {
      if (m is Map<String, dynamic>) {
        if (m['mapUrl']?.toString().toLowerCase() == lower ||
            m['uuid']?.toString().toLowerCase() == lower) {
          return m['displayName'] ?? mapUrl.split('/').last;
        }
      }
    }
    final name = mapUrl.split('/').last;
    return name.isNotEmpty ? name : 'Map';
  }

  String? _resolveMapSplash(String mapUrl, Map<String, dynamic> mapsMap) {
    if (mapUrl.isEmpty) return null;
    final lower = mapUrl.toLowerCase();
    if (mapsMap.containsKey(lower)) {
      return mapsMap[lower]?['splash'] ?? mapsMap[lower]?['listViewIcon'];
    }
    for (var m in mapsMap.values) {
      if (m is Map<String, dynamic>) {
        if (m['mapUrl']?.toString().toLowerCase() == lower ||
            m['uuid']?.toString().toLowerCase() == lower) {
          return m['splash'] ?? m['listViewIcon'];
        }
      }
    }
    return null;
  }

  Map<String, dynamic>? _resolveAgent(
    String agentUuid,
    Map<String, dynamic> agentsMap,
  ) {
    if (agentUuid.isEmpty) return null;
    final lower = agentUuid.toLowerCase();
    return agentsMap[lower] as Map<String, dynamic>?;
  }

  static const List<String> _standardRoles = [
    'Duelist',
    'Initiator',
    'Controller',
    'Sentinel',
  ];

  Widget _buildRoleCompositionBanner(
    PregameMatch pregameMatch,
    Map<String, dynamic> agentsMap,
  ) {
    final lockedRoles = <String>{};
    var lockedCount = 0;
    for (final player in pregameMatch.allyTeam) {
      if (player.characterId.isEmpty) continue;
      lockedCount++;
      final agentData = _resolveAgent(player.characterId, agentsMap);
      final role = agentData?['role'] as Map<String, dynamic>?;
      final roleName = role?['displayName']?.toString();
      if (roleName != null && roleName.isNotEmpty) {
        lockedRoles.add(roleName);
      }
    }

    if (lockedCount == 0) return const SizedBox.shrink();

    final missingRoles = _standardRoles
        .where((role) => !lockedRoles.contains(role))
        .toList();
    if (missingRoles.isEmpty) return const SizedBox.shrink();

    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.groups_outlined,
              color: Theme.of(context).colorScheme.onTertiaryContainer,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Missing from your comp',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    missingRoles.join(' • '),
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final partyState = ref.watch(partyProvider);
    final tiersAsync = ref.watch(competitiveTiersProvider);
    final agentsAsync = ref.watch(agentsMapProvider);
    final mapsAsync = ref.watch(mapsMapProvider);
    final currentUserPuuid = ref.watch(authProvider).user?.puuid;

    final myMember = partyState.members.firstWhere(
      (m) => m.puuid == currentUserPuuid,
      orElse: () => PartyMember(
        puuid: currentUserPuuid ?? '',
        gameName: '',
        tagLine: '',
        playerCardId: '',
        competitiveTier: 0,
        isReady: false,
        isOwner: false,
      ),
    );

    final isOwner = myMember.isOwner;
    final isMatchmaking =
        partyState.phase == PartyPhase.matchmaking ||
        partyState.state == 'MATCHMAKING';
    final allReadyExceptOwner = partyState.members.every(
      (m) => m.isOwner || m.isReady,
    );

    final tiersData = tiersAsync.value ?? const {};
    final agentsMap = agentsAsync.value ?? const {};
    final mapsMap = mapsAsync.value ?? const {};

    if (widget.gameViewOnly) {
      if (partyState.phase != PartyPhase.agentSelect &&
          partyState.phase != PartyPhase.inMatch) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
      }
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(switch (partyState.phase) {
            PartyPhase.agentSelect => l10n.agentSelect,
            PartyPhase.inMatch => l10n.currentMatch,
            _ => l10n.currentMatch,
          }, style: const TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(10),
            child: AnimatedBuilder(
              animation: _pollLoaderController,
              builder: (context, _) => WavyLinearProgressIndicator(
                value: _pollLoaderController.value,
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                strokeWidth: 3.5,
                amplitude: 2.5,
                wavelength: 28.0,
              ),
            ),
          ),
        ),
        body: switch (partyState.phase) {
          PartyPhase.agentSelect => _buildAgentSelectView(
            context: context,
            pregameMatch: partyState.pregameMatch,
            tiersData: tiersData,
            agentsMap: agentsMap,
            mapsMap: mapsMap,
            partyState: partyState,
            currentUserPuuid: currentUserPuuid,
          ),
          PartyPhase.inMatch => _buildCurrentMatchView(
            context: context,
            currentMatch: partyState.currentGameMatch,
            tiersData: tiersData,
            agentsMap: agentsMap,
            mapsMap: mapsMap,
            partyState: partyState,
            currentUserPuuid: currentUserPuuid,
          ),
          _ => const Center(child: FunnyLoadingView()),
        },
        floatingActionButton: partyState.phase == PartyPhase.inMatch
            ? FloatingActionButton.extended(
                onPressed: () =>
                    ref.read(partyProvider.notifier).refreshParty(),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context)
                    .colorScheme
                    .onPrimaryContainer,
                icon: const Icon(Icons.sports_esports),
                label: Text(
                  l10n.inMatch,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              )
            : partyState.phase == PartyPhase.agentSelect
            ? FloatingActionButton.extended(
                onPressed: () =>
                    ref.read(partyProvider.notifier).refreshParty(),
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .tertiaryContainer,
                foregroundColor: Theme.of(context)
                    .colorScheme
                    .onTertiaryContainer,
                icon: const Icon(Icons.how_to_reg),
                label: Text(
                  l10n.agentSelect,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              )
            : null,
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          partyState.phase == PartyPhase.matchmaking
              ? l10n.matchmaking
              : l10n.partyLobbyHeader,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10),
          child: AnimatedBuilder(
            animation: _pollLoaderController,
            builder: (context, _) => WavyLinearProgressIndicator(
              value: _pollLoaderController.value,
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              strokeWidth: 3.5,
              amplitude: 2.5,
              wavelength: 28.0,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildAutoLoadoutConflictBanner(context),

          _buildGameStateBanner(context, partyState),

          Expanded(
            child: _buildPhaseContent(
              context: context,
              partyState: partyState,
              tiersData: tiersData,
              agentsMap: agentsMap,
              mapsMap: mapsMap,
              currentUserPuuid: currentUserPuuid,
              isOwner: isOwner,
              isMatchmaking: isMatchmaking,
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(
        partyState: partyState,
        isOwner: isOwner,
        isMatchmaking: isMatchmaking,
        allReadyExceptOwner: allReadyExceptOwner,
        myMember: myMember,
        context: context,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildAutoLoadoutConflictBanner(BuildContext context) {
    final autoState = ref.watch(autoLoadoutProvider).value;
    final conflict = autoState?.pendingConflict;
    if (conflict == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        color: theme.colorScheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.rule,
                    color: theme.colorScheme.onTertiaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Two Auto Loadout rules match — pick one',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                    tooltip: 'Keep current loadout for this match',
                    onPressed: () => ref
                        .read(autoLoadoutProvider.notifier)
                        .dismissConflict(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ref
                          .read(autoLoadoutProvider.notifier)
                          .resolveConflict(true),
                      child: Text(
                        'Agent: ${conflict.agentRule.targetName}\n${conflict.agentPresetName}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ref
                          .read(autoLoadoutProvider.notifier)
                          .resolveConflict(false),
                      child: Text(
                        'Map: ${conflict.mapRule.targetName}\n${conflict.mapPresetName}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseContent({
    required BuildContext context,
    required PartyState partyState,
    required Map<int, dynamic> tiersData,
    required Map<String, dynamic> agentsMap,
    required Map<String, dynamic> mapsMap,
    required String? currentUserPuuid,
    required bool isOwner,
    required bool isMatchmaking,
  }) {
    if (partyState.isLoading &&
        partyState.members.isEmpty &&
        partyState.pregameMatch == null &&
        partyState.currentGameMatch == null) {
      return const Center(child: FunnyLoadingView());
    }

    if (partyState.error != null &&
        partyState.members.isEmpty &&
        partyState.pregameMatch == null &&
        partyState.currentGameMatch == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: ${partyState.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(partyProvider.notifier).refreshParty(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return _buildPartyLobby(
      context: context,
      partyState: partyState,
      tiersData: tiersData,
      currentUserPuuid: currentUserPuuid,
      isOwner: isOwner,
      isMatchmaking: isMatchmaking,
    );
  }

  Widget _buildGameStateBanner(BuildContext context, PartyState partyState) {
    final l10n = AppLocalizations.of(context)!;
    final phase = partyState.phase;
    if (phase != PartyPhase.agentSelect && phase != PartyPhase.inMatch) {
      return const SizedBox.shrink();
    }

    final String stateLabel = phase == PartyPhase.agentSelect
        ? l10n.agentSelect
        : l10n.currentMatch;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const PartyPage(gameViewOnly: true),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  phase == PartyPhase.agentSelect
                      ? Icons.how_to_reg
                      : Icons.sports_esports,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stateLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartyLobby({
    required BuildContext context,
    required PartyState partyState,
    required Map<int, dynamic> tiersData,
    required String? currentUserPuuid,
    required bool isOwner,
    required bool isMatchmaking,
  }) {
    final l10n = AppLocalizations.of(context)!;
    if (partyState.partyId == null) {
      return Center(child: Text(l10n.noPartyDetailsAvailable));
    }

    final activeQueue = partyState.queueId ?? 'unrated';

    return RefreshIndicator(
      onRefresh: () => ref.read(partyProvider.notifier).refreshParty(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.2),
            margin: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.sports_esports,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    l10n.matchTypeTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    partyState.availableQueues[activeQueue] ?? activeQueue,
                  ),
                  trailing: isOwner && !isMatchmaking
                      ? const Icon(Icons.edit, size: 18)
                      : null,
                  onTap: isOwner && !isMatchmaking
                      ? () => _showQueueSelectionDialog(context, activeQueue)
                      : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.dns,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    l10n.preferredServersTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    partyState.preferredGamePods.isEmpty
                        ? l10n.automaticSelection
                        : l10n.serversSelectedCount(
                            partyState.preferredGamePods.length,
                            partyState.availableGamePods.length,
                            partyState.preferredGamePods
                                .map(
                                  (k) => partyState.availableGamePods[k] ?? k,
                                )
                                .join(', '),
                          ),
                  ),
                  trailing: const Icon(Icons.edit, size: 18),
                  onTap: () =>
                      _showServerSelectionSheet(context, partyState, isOwner),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.vpn_key,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    l10n.partyCodeTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: partyState.inviteCode != null
                      ? null
                      : Text(l10n.disabledLabel),
                  trailing: partyState.inviteCode != null
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                partyState.inviteCode!,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              tooltip: l10n.copyCodeTooltip,
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: partyState.inviteCode!),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.partyCodeCopiedSnackbar),
                                  ),
                                );
                              },
                            ),
                            if (isOwner)
                              IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                                tooltip: l10n.disableCodeTooltip,
                                onPressed: () {
                                  ref
                                      .read(partyProvider.notifier)
                                      .disablePartyCode();
                                },
                              ),
                          ],
                        )
                      : (isOwner
                            ? TextButton.icon(
                                icon: const Icon(Icons.add, size: 16),
                                label: Text(l10n.generateButton),
                                onPressed: () {
                                  ref
                                      .read(partyProvider.notifier)
                                      .generatePartyCode();
                                },
                              )
                            : Text(l10n.disabledLabel)),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            partyState.accessibility == 'OPEN'
                                ? Icons.lock_open
                                : Icons.lock,
                            color: partyState.accessibility == 'OPEN'
                                ? Theme.of(context).colorScheme.primary
                                : Colors.redAccent,
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.partyAccessibility,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                partyState.accessibility == 'OPEN'
                                    ? l10n.openToFriends
                                    : l10n.closedInviteOnly,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch.adaptive(
                        value: partyState.accessibility == 'OPEN',
                        onChanged: isOwner
                            ? (val) {
                                ref
                                    .read(partyProvider.notifier)
                                    .toggleAccessibility();
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.partyMembersHeader(partyState.members.length),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ...partyState.members.map((member) {
            final tierData = tiersData[member.competitiveTier];
            final tierIcon =
                tierData?['largeIcon'] ??
                'https://media.valorant-api.com/competitivetiers/564d8e28-c226-3180-6285-e19a31071cb2/0/largeicon.png';
            final tierName = tierData?['tierName'] ?? 'Unranked';

            return Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            'https://media.valorant-api.com/playercards/${member.playerCardId}/displayicon.png',
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 56,
                                  height: 56,
                                  color: Colors.grey.withValues(alpha: 0.2),
                                  child: const Icon(Icons.person),
                                ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${member.gameName}#${member.tagLine}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (member.isOwner) ...[
                                    const SizedBox(width: 6),
                                    Tooltip(
                                      message: 'Party Leader',
                                      child: Icon(
                                        Icons.emoji_events,
                                        size: 18,
                                        color: Colors.amber[700],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tierName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        CachedNetworkImage(
                          imageUrl: tierIcon,
                          width: 44,
                          height: 44,
                          cacheManager:
                              CustomCacheManagers.tierImageCacheManager,
                          errorWidget: (context, url, error) =>
                              const SizedBox(width: 44, height: 44),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: member.puuid == currentUserPuuid && !isMatchmaking
                        ? () => ref.read(partyProvider.notifier).toggleReady()
                        : null,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: member.isReady
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.red.withValues(alpha: 0.15),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 16,
                      ),
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            member.isReady ? Icons.check_circle : Icons.cancel,
                            size: 14,
                            color: member.isReady ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            member.isReady ? 'READY' : 'NOT READY',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: member.isReady
                                  ? Colors.green[700]
                                  : Colors.red[700],
                            ),
                          ),
                          if (member.puuid == currentUserPuuid) ...[
                            const Spacer(),
                            SizedBox(
                              height: 24,
                              child: Switch.adaptive(
                                value: member.isReady,
                                activeThumbColor: Colors.green,
                                onChanged: isMatchmaking
                                    ? null
                                    : (val) {
                                        ref
                                            .read(partyProvider.notifier)
                                            .toggleReady();
                                      },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildAgentSelectView({
    required BuildContext context,
    required PregameMatch? pregameMatch,
    required Map<int, dynamic> tiersData,
    required Map<String, dynamic> agentsMap,
    required Map<String, dynamic> mapsMap,
    required PartyState partyState,
    required String? currentUserPuuid,
  }) {
    if (pregameMatch == null) {
      return const Center(child: FunnyLoadingView());
    }

    final mapName = _resolveMapName(pregameMatch.mapId, mapsMap);
    final mapSplash = _resolveMapSplash(pregameMatch.mapId, mapsMap);
    final queueName =
        partyState.availableQueues[pregameMatch.queueId] ??
        (pregameMatch.queueId.isNotEmpty
            ? pregameMatch.queueId[0].toUpperCase() +
                  pregameMatch.queueId.substring(1)
            : 'Standard');

    return RefreshIndicator(
      onRefresh: () => ref.read(partyProvider.notifier).refreshParty(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            margin: const EdgeInsets.only(bottom: 16),
            child: Stack(
              children: [
                if (mapSplash != null)
                  Positioned.fill(
                    child: Image.network(
                      mapSplash,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context).colorScheme.surface
                            .withValues(alpha: 0.85),
                        Theme.of(context).colorScheme.surface
                            .withValues(alpha: 0.95),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .tertiaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.how_to_reg,
                          color: Theme.of(context)
                              .colorScheme
                              .onTertiaryContainer,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mapName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Agent Select • $queueName',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          _buildRoleCompositionBanner(pregameMatch, agentsMap),

          Text(
            'YOUR TEAM (${pregameMatch.allyTeam.length})',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.1,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),

          ...pregameMatch.allyTeam.map((player) {
            return _buildPregamePlayerCard(
              context: context,
              player: player,
              tiersData: tiersData,
              agentsMap: agentsMap,
              isCurrentUser: player.puuid == currentUserPuuid,
            );
          }),

          if (pregameMatch.enemyTeam.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'ENEMY TEAM (${pregameMatch.enemyTeam.length})',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.1,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            ...pregameMatch.enemyTeam.map((player) {
              return _buildPregamePlayerCard(
                context: context,
                player: player,
                tiersData: tiersData,
                agentsMap: agentsMap,
                isCurrentUser: false,
              );
            }),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  String _resolveGamePodName(String? podId, Map<String, String> availablePods) {
    if (podId == null || podId.isEmpty) return 'Global Server';
    if (availablePods.containsKey(podId)) {
      return availablePods[podId]!;
    }
    final lower = podId.toLowerCase();
    if (lower.contains('bom')) return 'Mumbai';
    if (lower.contains('fra') || lower.contains('frankfurt')) {
      return 'Frankfurt';
    }
    if (lower.contains('par') || lower.contains('paris')) return 'Paris';
    if (lower.contains('lon') || lower.contains('london')) return 'London';
    if (lower.contains('tok') || lower.contains('tokyo')) return 'Tokyo';
    if (lower.contains('sin') || lower.contains('singapore')) {
      return 'Singapore';
    }
    if (lower.contains('syd') || lower.contains('sydney')) return 'Sydney';
    if (lower.contains('ash') || lower.contains('virginia')) {
      return 'N. Virginia';
    }
    if (lower.contains('chi') || lower.contains('chicago')) {
      return 'N. Illinois';
    }
    if (lower.contains('dal') || lower.contains('dallas')) return 'Texas';
    if (lower.contains('lax') || lower.contains('california')) {
      return 'N. California';
    }
    if (lower.contains('sea') || lower.contains('oregon')) return 'Oregon';
    if (lower.contains('mad') || lower.contains('madrid')) return 'Madrid';
    if (lower.contains('waw') || lower.contains('warsaw')) return 'Warsaw';
    if (lower.contains('ist') || lower.contains('istanbul')) return 'Istanbul';
    if (lower.contains('dxb') || lower.contains('dubai')) return 'Bahrain';
    if (lower.contains('gru') || lower.contains('sao')) return 'São Paulo';
    if (lower.contains('scl') || lower.contains('santiago')) return 'Santiago';
    if (lower.contains('bog') || lower.contains('bogota')) return 'Bogota';
    if (lower.contains('mex') || lower.contains('mexico')) return 'Mexico City';
    return 'Custom Game Pod';
  }

  Widget _buildCurrentMatchView({
    required BuildContext context,
    required CurrentGameMatch? currentMatch,
    required Map<int, dynamic> tiersData,
    required Map<String, dynamic> agentsMap,
    required Map<String, dynamic> mapsMap,
    required PartyState partyState,
    required String? currentUserPuuid,
  }) {
    if (currentMatch == null) {
      return const Center(child: FunnyLoadingView());
    }

    final mapName = _resolveMapName(currentMatch.mapId, mapsMap);
    final mapSplash = _resolveMapSplash(currentMatch.mapId, mapsMap);
    final queueName =
        partyState.availableQueues[currentMatch.queueId] ??
        (currentMatch.queueId.isNotEmpty
            ? currentMatch.queueId[0].toUpperCase() +
                  currentMatch.queueId.substring(1)
            : 'Match');

    final serverName = _resolveGamePodName(
      currentMatch.gamePodId,
      partyState.availableGamePods,
    );

    final myPlayer = currentMatch.allyTeam.firstWhere(
      (p) => p.puuid == currentUserPuuid,
      orElse: () => currentMatch.allyTeam.isNotEmpty
          ? currentMatch.allyTeam.first
          : currentMatch.enemyTeam.first,
    );
    final isAttackers = myPlayer.teamId.toLowerCase() == 'red';
    final sideName = isAttackers ? 'Attackers' : 'Defenders';
    final sideColor = isAttackers
        ? const Color(0xFFFF4655)
        : const Color(0xFF00DF9A);

    return RefreshIndicator(
      onRefresh: () => ref.read(partyProvider.notifier).refreshParty(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.sports_esports,
                        size: 26,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          queueName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          serverName,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      sideName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: sideColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Started as',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (mapSplash != null)
                  Image.network(
                    mapSplash,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 120,
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                    ),
                  )
                else
                  Container(
                    height: 120,
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                  ),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  left: 14,
                  bottom: 10,
                  child: Text(
                    mapName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14191E).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '0',
                        style: TextStyle(
                          color: Color(0xFF00DF9A),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '—',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const Text(
                        '0',
                        style: TextStyle(
                          color: Color(0xFFFF4655),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          ...currentMatch.allyTeam.map((player) {
            return _buildCurrentGamePlayerCard(
              context: context,
              player: player,
              tiersData: tiersData,
              agentsMap: agentsMap,
              isCurrentUser: player.puuid == currentUserPuuid,
            );
          }),

          const SizedBox(height: 10),
          ...currentMatch.enemyTeam.map((player) {
            return _buildCurrentGamePlayerCard(
              context: context,
              player: player,
              tiersData: tiersData,
              agentsMap: agentsMap,
              isCurrentUser: false,
            );
          }),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildPregamePlayerCard({
    required BuildContext context,
    required PregamePlayer player,
    required Map<int, dynamic> tiersData,
    required Map<String, dynamic> agentsMap,
    required bool isCurrentUser,
  }) {
    final agentData = _resolveAgent(player.characterId, agentsMap);
    final agentName =
        agentData?['displayName'] ??
        (player.characterId.isNotEmpty ? 'Agent Selected' : 'Selecting...');
    final agentIcon = agentData?['displayIcon'];

    final stats = ref.watch(playerMatchStatsProvider)[player.puuid];
    final compTier = (stats != null && stats.currentTier > 0)
        ? stats.currentTier
        : player.competitiveTier;
    final tierData = tiersData[compTier];
    final tierIcon =
        stats?.currentTierIcon ??
        tierData?['largeIcon'] ??
        'https://media.valorant-api.com/competitivetiers/564d8e28-c226-3180-6285-e19a31071cb2/0/largeicon.png';

    final teamAccentColor = player.isAlly
        ? const Color(0xFF00DF9A)
        : const Color(0xFFFF4655);

    final riotId = player.tagLine.isNotEmpty
        ? '${player.gameName}#${player.tagLine}'
        : player.gameName;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? Theme.of(context).colorScheme.primaryContainer
                  .withValues(alpha: 0.25)
            : Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: teamAccentColor, width: 3.5),
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: 0.2),
          ),
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: 0.2),
          ),
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: 0.2),
          ),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showPlayerDetailsModal(
          context: context,
          puuid: player.puuid,
          gameName: player.gameName,
          tagLine: player.tagLine,
          characterId: player.characterId,
          playerCardId: player.playerCardId,
          accountLevel: player.accountLevel,
          competitiveTier: compTier,
          isCurrentUser: isCurrentUser,
          isAlly: player.isAlly,
          agentsMap: agentsMap,
          tiersData: tiersData,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: agentIcon != null
                        ? Image.network(
                            agentIcon,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _defaultAvatar(player.playerCardId),
                          )
                        : _defaultAvatar(player.playerCardId),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                riotId,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isCurrentUser
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrentUser) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'YOU',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              agentName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            if (player.isLocked) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.lock,
                                size: 12,
                                color: Colors.green[600],
                              ),
                            ],
                            if (player.accountLevel > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '• Level ${player.accountLevel}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  CachedNetworkImage(
                    imageUrl: tierIcon,
                    width: 36,
                    height: 36,
                    cacheManager: CustomCacheManagers.tierImageCacheManager,
                    errorWidget: (context, url, error) =>
                        const SizedBox(width: 36, height: 36),
                  ),
                  const SizedBox(width: 4),

                  IconButton(
                    icon: const Icon(Icons.more_horiz, size: 20),
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    onPressed: () => _showPlayerActionMenu(
                      context: context,
                      puuid: player.puuid,
                      gameName: player.gameName,
                      tagLine: player.tagLine,
                    ),
                  ),

                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    label: 'K/D',
                    value: stats != null && stats.totalMatches > 0
                        ? stats.kdRatio.toStringAsFixed(2)
                        : '—',
                    context: context,
                  ),
                  _buildStatColumn(
                    label: 'HS%',
                    value: stats != null && stats.totalMatches > 0
                        ? '${stats.headshotPct.toStringAsFixed(1)}%'
                        : '—',
                    context: context,
                  ),
                  _buildStatColumn(
                    label: 'KAST',
                    value: stats != null && stats.totalMatches > 0
                        ? '${stats.kastPct.toStringAsFixed(0)}%'
                        : '—',
                    context: context,
                  ),
                  _buildStatColumn(
                    label: 'WIN%',
                    value: stats != null && stats.totalMatches > 0
                        ? '${stats.winRate.toStringAsFixed(0)}%'
                        : '—',
                    context: context,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentGamePlayerCard({
    required BuildContext context,
    required CurrentGamePlayer player,
    required Map<int, dynamic> tiersData,
    required Map<String, dynamic> agentsMap,
    required bool isCurrentUser,
  }) {
    final agentData = _resolveAgent(player.characterId, agentsMap);
    final agentName =
        agentData?['displayName'] ??
        (player.characterId.isNotEmpty ? 'Agent' : 'Selecting');
    final agentIcon = agentData?['displayIcon'];

    final stats = ref.watch(playerMatchStatsProvider)[player.puuid];
    final compTier = (stats != null && stats.currentTier > 0)
        ? stats.currentTier
        : player.competitiveTier;
    final tierData = tiersData[compTier];
    final tierIcon =
        stats?.currentTierIcon ??
        tierData?['largeIcon'] ??
        'https://media.valorant-api.com/competitivetiers/564d8e28-c226-3180-6285-e19a31071cb2/0/largeicon.png';

    final teamAccentColor = player.isAlly
        ? const Color(0xFF00DF9A)
        : const Color(0xFFFF4655);

    final riotId = player.tagLine.isNotEmpty
        ? '${player.gameName}#${player.tagLine}'
        : player.gameName;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? Theme.of(context).colorScheme.primaryContainer
                  .withValues(alpha: 0.25)
            : Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: teamAccentColor, width: 3.5),
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: 0.2),
          ),
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: 0.2),
          ),
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: 0.2),
          ),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showPlayerDetailsModal(
          context: context,
          puuid: player.puuid,
          gameName: player.gameName,
          tagLine: player.tagLine,
          characterId: player.characterId,
          playerCardId: player.playerCardId,
          accountLevel: player.accountLevel,
          competitiveTier: compTier,
          isCurrentUser: isCurrentUser,
          isAlly: player.isAlly,
          agentsMap: agentsMap,
          tiersData: tiersData,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: agentIcon != null
                        ? Image.network(
                            agentIcon,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _defaultAvatar(player.playerCardId),
                          )
                        : _defaultAvatar(player.playerCardId),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                riotId,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isCurrentUser
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrentUser) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'YOU',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              agentName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            if (player.accountLevel > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '• Level ${player.accountLevel}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  CachedNetworkImage(
                    imageUrl: tierIcon,
                    width: 36,
                    height: 36,
                    cacheManager: CustomCacheManagers.tierImageCacheManager,
                    errorWidget: (context, url, error) =>
                        const SizedBox(width: 36, height: 36),
                  ),
                  const SizedBox(width: 4),

                  IconButton(
                    icon: const Icon(Icons.more_horiz, size: 20),
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    onPressed: () => _showPlayerActionMenu(
                      context: context,
                      puuid: player.puuid,
                      gameName: player.gameName,
                      tagLine: player.tagLine,
                    ),
                  ),

                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    label: 'K/D',
                    value: stats != null && stats.totalMatches > 0
                        ? stats.kdRatio.toStringAsFixed(2)
                        : '—',
                    context: context,
                  ),
                  _buildStatColumn(
                    label: 'HS%',
                    value: stats != null && stats.totalMatches > 0
                        ? '${stats.headshotPct.toStringAsFixed(1)}%'
                        : '—',
                    context: context,
                  ),
                  _buildStatColumn(
                    label: 'KAST',
                    value: stats != null && stats.totalMatches > 0
                        ? '${stats.kastPct.toStringAsFixed(0)}%'
                        : '—',
                    context: context,
                  ),
                  _buildStatColumn(
                    label: 'WIN%',
                    value: stats != null && stats.totalMatches > 0
                        ? '${stats.winRate.toStringAsFixed(0)}%'
                        : '—',
                    context: context,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn({
    required String label,
    required String value,
    required BuildContext context,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  void _showPlayerActionMenu({
    required BuildContext context,
    required String puuid,
    required String gameName,
    required String tagLine,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final riotId = tagLine.isNotEmpty ? '$gameName#$tagLine' : gameName;
    bool isConnectExpanded = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setMenuState) {
            return Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: const Color(0xFF191F24),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          riotId,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 10),

                      _buildActionMenuItem(
                        icon: Icons.account_circle_outlined,
                        title: l10n.openProfileButton,
                        onTap: () {
                          Navigator.pop(dialogContext);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  PlayerSearchPage(initialQuery: riotId),
                            ),
                          );
                        },
                      ),

                      _buildActionMenuItem(
                        icon: Icons.copy_outlined,
                        title: l10n.copyPlayerName,
                        onTap: () {
                          Navigator.pop(dialogContext);
                          Clipboard.setData(ClipboardData(text: riotId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.copiedPlayerNameToClipboard(riotId),
                              ),
                            ),
                          );
                        },
                      ),

                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setMenuState(() {
                            isConnectExpanded = !isConnectExpanded;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person_add_alt_1_outlined,
                                color: Color(0xFF00DF9A),
                                size: 20,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  l10n.connectButton,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Icon(
                                isConnectExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: Colors.white.withValues(alpha: 0.7),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (isConnectExpanded) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Column(
                            children: [
                              _buildActionMenuItem(
                                icon: Icons.group_add_outlined,
                                title: l10n.inviteToPartyMenu,
                                onTap: () async {
                                  Navigator.pop(dialogContext);
                                  final success = await ref
                                      .read(partyProvider.notifier)
                                      .invitePlayer(gameName, tagLine);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? l10n.invitedPlayerToParty(
                                                  riotId,
                                                )
                                              : l10n.failedToInvitePlayer(
                                                  riotId,
                                                ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),

                              _buildActionMenuItem(
                                icon: Icons.person_add_outlined,
                                title: l10n.addFriendMenu,
                                onTap: () {
                                  Navigator.pop(dialogContext);
                                  _showAddFriendDialog(
                                    context,
                                    gameName,
                                    tagLine,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF00DF9A), size: 20),
            const SizedBox(width: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar(String playerCardId) {
    if (playerCardId.isNotEmpty) {
      return Image.network(
        'https://media.valorant-api.com/playercards/$playerCardId/displayicon.png',
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 48,
          height: 48,
          color: Colors.grey.withValues(alpha: 0.2),
          child: const Icon(Icons.person, size: 24),
        ),
      );
    }
    return Container(
      width: 48,
      height: 48,
      color: Colors.grey.withValues(alpha: 0.2),
      child: const Icon(Icons.person, size: 24),
    );
  }

  void _showPlayerDetailsModal({
    required BuildContext context,
    required String puuid,
    required String gameName,
    required String tagLine,
    required String characterId,
    required String playerCardId,
    required int accountLevel,
    required int competitiveTier,
    required bool isCurrentUser,
    required bool isAlly,
    required Map<String, dynamic> agentsMap,
    required Map<int, dynamic> tiersData,
  }) {
    final user = ref.read(authProvider).user;
    final agentData = _resolveAgent(characterId, agentsMap);
    final agentName = agentData?['displayName'] ?? 'Agent';
    final agentIcon = agentData?['displayIcon'];

    if (user != null && puuid.isNotEmpty) {
      ref
          .read(playerMatchStatsProvider.notifier)
          .fetchPlayerStats(
            puuid,
            region: user.region,
            shard: user.shard,
            accessToken: user.accessToken,
            entitlementsToken: user.entitlementsToken,
          );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return Consumer(
          builder: (context, ref, child) {
            final stats = ref.watch(playerMatchStatsProvider)[puuid];
            final effectiveTier = (stats != null && stats.currentTier > 0)
                ? stats.currentTier
                : competitiveTier;
            final tierData = tiersData[effectiveTier];
            final tierIcon =
                stats?.currentTierIcon ??
                tierData?['largeIcon'] ??
                'https://media.valorant-api.com/competitivetiers/564d8e28-c226-3180-6285-e19a31071cb2/0/largeicon.png';
            final tierName =
                (stats != null && stats.currentTierName != 'Unranked')
                ? stats.currentTierName
                : (tierData?['tierName'] ?? 'Unranked');

            final peakTier = stats?.peakTier ?? 0;
            final peakTierData = tiersData[peakTier];
            final peakTierIcon =
                stats?.peakTierIcon ?? peakTierData?['largeIcon'];
            final peakTierName =
                stats?.peakTierName ?? peakTierData?['tierName'] ?? 'Unranked';
            final peakSeason = stats?.peakSeason ?? 'Career Peak';

            final riotId = tagLine.isNotEmpty ? '$gameName#$tagLine' : gameName;

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.45,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                final l10n = AppLocalizations.of(context)!;
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant
                              .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: agentIcon != null
                                ? Image.network(
                                    agentIcon,
                                    width: 58,
                                    height: 58,
                                    fit: BoxFit.cover,
                                    errorBuilder: (
                                      context,
                                      error,
                                      stackTrace,
                                    ) => _defaultAvatar(playerCardId),
                                  )
                                : _defaultAvatar(playerCardId),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        riotId,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 18),
                                      tooltip: 'Copy Riot ID',
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: riotId),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Copied "$riotId" to clipboard!',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      agentName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                    if (accountLevel > 0) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '• Lvl $accountLevel',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isAlly
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .primaryContainer
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .errorContainer,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isAlly ? 'ALLY' : 'ENEMY',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isAlly
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .onPrimaryContainer
                                              : Theme.of(context)
                                                    .colorScheme
                                                    .onErrorContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Card(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.2),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.account_circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: Text(
                              l10n.openProfileButton,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: const Text(
                              'View career match history and stats',
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pop(bottomSheetContext);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PlayerSearchPage(initialQuery: riotId),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              Icons.person_add,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: Text(
                              l10n.addFriendMenu,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              l10n.addFriendSubtitle,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pop(bottomSheetContext);
                              _showAddFriendDialog(context, gameName, tagLine);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      l10n.competitiveRankHeader,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.1,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  l10n.currentRankHeader,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                CachedNetworkImage(
                                  imageUrl: tierIcon,
                                  width: 48,
                                  height: 48,
                                  cacheManager:
                                      CustomCacheManagers.tierImageCacheManager,
                                  errorWidget: (context, url, error) =>
                                      const SizedBox(width: 48, height: 48),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  tierName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (stats != null && stats.currentRR > 0) ...[
                                  Text(
                                    '${stats.currentRR} RR',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Peak Rank',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (peakTierIcon != null)
                                  CachedNetworkImage(
                                    imageUrl: peakTierIcon,
                                    width: 48,
                                    height: 48,
                                    cacheManager: CustomCacheManagers
                                        .tierImageCacheManager,
                                    errorWidget: (context, url, error) =>
                                        const SizedBox(width: 48, height: 48),
                                  )
                                else
                                  const Icon(Icons.shield, size: 48),
                                const SizedBox(height: 8),
                                Text(
                                  peakTierName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  peakSeason,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Text(
                      l10n.performanceStatsHeader,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.1,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: (stats != null && stats.totalMatches > 0)
                          ? Column(
                              children: [
                                _buildStatDetailRow(
                                  'Win Rate',
                                  '${stats.winRate.toStringAsFixed(1)}%',
                                  context,
                                ),
                                const Divider(height: 16),
                                _buildStatDetailRow(
                                  'K/D Ratio',
                                  stats.kdRatio.toStringAsFixed(2),
                                  context,
                                ),
                                const Divider(height: 16),
                                _buildStatDetailRow(
                                  'Headshot %',
                                  '${stats.headshotPct.toStringAsFixed(1)}%',
                                  context,
                                ),
                                if (stats.avgDamagePerRound > 0) ...[
                                  const Divider(height: 16),
                                  _buildStatDetailRow(
                                    'Avg Damage / Round (ADR)',
                                    stats.avgDamagePerRound.toStringAsFixed(1),
                                    context,
                                  ),
                                ],
                                if (stats.combatScore > 0) ...[
                                  const Divider(height: 16),
                                  _buildStatDetailRow(
                                    'Avg Combat Score (ACS)',
                                    stats.combatScore.toStringAsFixed(1),
                                    context,
                                  ),
                                ],
                                const Divider(height: 16),
                                _buildStatDetailRow(
                                  'Matches Tracked',
                                  '${stats.totalMatches} (${stats.wins}W / ${stats.losses}L)',
                                  context,
                                ),
                              ],
                            )
                          : (stats?.isLoading == true
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: Center(
                                      child:
                                          CircularProgressIndicator.adaptive(),
                                    ),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Center(
                                      child: Text(
                                        stats?.error != null
                                            ? 'No public career stats found'
                                            : 'Stats unavailable for this player',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  )),
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatDetailRow(String label, String value, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _showAddFriendDialog(
    BuildContext context,
    String initialName,
    String initialTag,
  ) {
    final nameController = TextEditingController(text: initialName);
    final tagController = TextEditingController(text: initialTag);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Friend'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Game Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: tagController,
                  decoration: const InputDecoration(
                    labelText: 'Tagline',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  ref
                      .read(addFriendProvider.notifier)
                      .sendRequest(
                        nameController.text.trim(),
                        tagController.text.trim(),
                      );
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Friend request sent to ${nameController.text.trim()}#${tagController.text.trim()}!',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Send Request'),
            ),
          ],
        );
      },
    );
  }

  Widget? _buildFloatingActionButton({
    required PartyState partyState,
    required bool isOwner,
    required bool isMatchmaking,
    required bool allReadyExceptOwner,
    required PartyMember myMember,
    required BuildContext context,
  }) {
    final l10n = AppLocalizations.of(context)!;

    if (partyState.partyId == null) return null;

    final isLoading = partyState.isLoading;

    if (isMatchmaking) {
      final timerText = _getTimerText(partyState.queueEntryTime);
      return FloatingActionButton.extended(
        onPressed: isLoading
            ? null
            : () => ref.read(partyProvider.notifier).stopMatchmaking(),
        backgroundColor: Theme.of(context).colorScheme.error,
        foregroundColor: Theme.of(context).colorScheme.onError,
        icon: const Icon(Icons.cancel),
        label: Text(
          '$timerText  ${l10n.cancelButton}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      );
    }

    if (isOwner) {
      return FloatingActionButton.extended(
        onPressed: (isLoading || !allReadyExceptOwner)
            ? null
            : () => ref.read(partyProvider.notifier).startMatchmaking(),
        backgroundColor: allReadyExceptOwner
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.play_arrow),
        label: Text(
          l10n.startMatch,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      );
    } else {
      return FloatingActionButton.extended(
        onPressed: isLoading
            ? null
            : () => ref.read(partyProvider.notifier).toggleReady(),
        backgroundColor: myMember.isReady
            ? Theme.of(context).colorScheme.tertiary
            : Theme.of(context).colorScheme.secondary,
        foregroundColor: myMember.isReady
            ? Theme.of(context).colorScheme.onTertiary
            : Theme.of(context).colorScheme.onSecondary,
        icon: Icon(
          myMember.isReady ? Icons.check_circle : Icons.radio_button_unchecked,
        ),
        label: Text(
          myMember.isReady ? l10n.readyStatus : l10n.notReadyStatus,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      );
    }
  }

  void _showQueueSelectionDialog(BuildContext context, String activeQueue) {
    final l10n = AppLocalizations.of(context)!;
    final availableQueues = ref.read(partyProvider).availableQueues;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.selectMatchTypeTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: RadioGroup<String>(
              groupValue: activeQueue,
              onChanged: (value) {
                if (value != null) {
                  ref.read(partyProvider.notifier).changeQueue(value);
                  Navigator.pop(context);
                }
              },
              child: ListView(
                shrinkWrap: true,
                children: availableQueues.entries.map((entry) {
                  return RadioListTile<String>(
                    title: Text(entry.value),
                    value: entry.key,
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showServerSelectionSheet(
    BuildContext context,
    PartyState partyState,
    bool isOwner,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final availablePods = partyState.availableGamePods;
    final List<String> tempSelected = List.from(partyState.preferredGamePods);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.selectServersTitle,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (isOwner)
                        TextButton(
                          onPressed: () {
                            ref
                                .read(partyProvider.notifier)
                                .updatePreferredGamePods(tempSelected);
                            Navigator.pop(context);
                          },
                          child: Text(l10n.applyButton),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!isOwner)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        l10n.viewingPreferredPodsInfo,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Expanded(
                    child: availablePods.isEmpty
                        ? Center(child: Text(l10n.noServersAvailable))
                        : ListView(
                            children: availablePods.entries.map((entry) {
                              final isSelected = tempSelected.contains(
                                entry.key,
                              );
                              return CheckboxListTile(
                                title: Text(entry.value),
                                value: isSelected,
                                onChanged: isOwner
                                    ? (value) {
                                        setBottomSheetState(() {
                                          if (value == true) {
                                            tempSelected.add(entry.key);
                                          } else {
                                            tempSelected.remove(entry.key);
                                          }
                                        });
                                      }
                                    : null,
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
