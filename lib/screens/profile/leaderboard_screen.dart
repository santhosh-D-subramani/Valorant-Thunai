import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/providers/leaderboard_provider.dart';
import 'package:valorant_thunai/providers/profile_provider.dart';
import 'package:valorant_thunai/theme/app_theme.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(leaderboardProvider.notifier).loadNextPage();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 400) {
      ref.read(leaderboardProvider.notifier).loadNextPage();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(leaderboardFiltersProvider.notifier).setQuery(value.trim());
    });
  }

  void _reset() {
    _searchController.clear();
    _debounce?.cancel();
    ref.read(leaderboardFiltersProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = ref.watch(leaderboardProvider);
    final filters = ref.watch(leaderboardFiltersProvider);
    final myPuuid = ref.watch(authProvider).user?.puuid;
    final tiersAsync = ref.watch(competitiveTiersProvider);
    final tiers = tiersAsync.value ?? const {};
    final actsAsync = ref.watch(allActsProvider);
    final acts = actsAsync.value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.leaderboardTitle),
        actions: [
          if (state.totalPlayers > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  l10n.leaderboardTotalPlayers(state.totalPlayers),
                  style: GoogleFonts.inter(fontSize: 12),
                ),
              ),
            ),
          IconButton(
            tooltip: l10n.leaderboardResetFilters,
            icon: const Icon(Icons.restart_alt),
            onPressed: _reset,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: l10n.leaderboardSearchHint,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _debounce?.cancel();
                                ref
                                    .read(leaderboardFiltersProvider.notifier)
                                    .setQuery('');
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: filters.shard,
                          isDense: true,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: l10n.leaderboardRegionLabel,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: leaderboardShards
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s.toUpperCase()),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              ref
                                  .read(leaderboardFiltersProvider.notifier)
                                  .setShard(value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: filters.seasonId,
                          isDense: true,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: l10n.leaderboardSeasonLabel,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          hint: Text(l10n.leaderboardCurrentSeason),
                          items: acts
                              .map(
                                (a) => DropdownMenuItem(
                                  value: a.uuid,
                                  child: Text(
                                    a.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              ref
                                  .read(leaderboardFiltersProvider.notifier)
                                  .setSeason(value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (state.entries.isEmpty && state.isLoading) {
                    return const FunnyLoadingView();
                  }
                  if (state.entries.isEmpty && state.error != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.leaderboard_outlined,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              state.error == 'noActiveAct'
                                  ? l10n.leaderboardNoActiveAct
                                  : l10n.leaderboardLoadFailed,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                ref.read(leaderboardProvider.notifier).reset();
                                ref
                                    .read(leaderboardProvider.notifier)
                                    .loadNextPage();
                              },
                              icon: const Icon(Icons.refresh),
                              label: Text(l10n.retryButton),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (state.entries.isEmpty) {
                    return Center(child: Text(l10n.leaderboardNoActiveAct));
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    itemCount: state.entries.length + 1,
                    itemBuilder: (context, index) {
                      if (index == state.entries.length) {
                        if (!state.hasMore) return const SizedBox(height: 24);
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final entry = state.entries[index];
                      final isMe = myPuuid != null && entry.puuid == myPuuid;
                      final tierIcon =
                          tiers[entry.competitiveTier]?['smallIcon'];
                      final avatarUrl = entry.playerCardId.isNotEmpty
                          ? 'https://media.valorant-api.com/playercards/${entry.playerCardId}/displayicon.png'
                          : null;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: isMe
                            ? theme.colorScheme.primaryContainer.withValues(
                                alpha: 0.4,
                              )
                            : null,
                        shape: isMe
                            ? RoundedRectangleBorder(
                                borderRadius: AppRadius.brXl,
                                side: BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 1.2,
                                ),
                              )
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 34,
                                child: Text(
                                  '#${entry.rank}',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w900,
                                    fontSize: entry.rank <= 3 ? 16 : 13,
                                    color: entry.rank == 1
                                        ? Colors.amber
                                        : entry.rank == 2
                                        ? Colors.grey
                                        : entry.rank == 3
                                        ? Colors.brown
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ClipOval(
                                child: avatarUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: avatarUrl,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                              width: 40,
                                              height: 40,
                                              color: theme
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                            ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                              width: 40,
                                              height: 40,
                                              color: theme
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              child: Icon(
                                                Icons.person,
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                      )
                                    : Container(
                                        width: 40,
                                        height: 40,
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        child: Icon(
                                          entry.isAnonymized
                                              ? Icons.visibility_off_outlined
                                              : Icons.person,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.displayName,
                                      style: GoogleFonts.inter(
                                        fontWeight: isMe
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        fontStyle: entry.isAnonymized
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      l10n.leaderboardWinsFormat(
                                        entry.numberOfWins,
                                      ),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (tierIcon != null)
                                    CachedNetworkImage(
                                      imageUrl: tierIcon,
                                      width: 26,
                                      height: 26,
                                      errorWidget: (_, _, _) =>
                                          const SizedBox(width: 26, height: 26),
                                    ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.leaderboardRrFormat(
                                      entry.rankedRating,
                                    ),
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
