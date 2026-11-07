import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/providers/career_stats_provider.dart';
import 'package:valorant_thunai/providers/display_settings_provider.dart';
import 'package:valorant_thunai/providers/profile_provider.dart';
import 'package:valorant_thunai/providers/seasons_provider.dart';
import 'package:valorant_thunai/utils/format_utils.dart';

class CareerStatsScreen extends ConsumerStatefulWidget {
  const CareerStatsScreen({super.key});

  @override
  ConsumerState<CareerStatsScreen> createState() => _CareerStatsScreenState();
}

class _CareerStatsScreenState extends ConsumerState<CareerStatsScreen> {
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_requested) {
      _requested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final actLabels = await ref
        .read(actLabelsBySeasonIdProvider.future)
        .catchError((_) => <String, String>{});
    final profileData = await ref
        .read(profileProvider.future)
        .catchError((_) => null);

    if (!mounted) return;
    await ref
        .read(careerStatsProvider.notifier)
        .load(
          user: user,
          actLabelsBySeasonId: actLabels,
          currentTier: profileData?.currentTier ?? 0,
          currentRR: profileData?.currentRR ?? 0,
          peakTierFromRankHistory:
              (profileData?.henrikMmr?['highest_rank']?['tier'] as num?)
                  ?.toInt() ??
              0,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authProvider).user;
    final statsAsync = ref.watch(careerStatsProvider);
    final competitiveTiers =
        ref.watch(competitiveTiersProvider).value ?? const {};

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.careerStatsTitle)),
        body: Center(child: Text(l10n.notLoggedIn)),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.careerStatsTitle),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: l10n.careerStatsTabOverall),
              Tab(text: l10n.careerStatsTabSummary),
              Tab(text: l10n.careerStatsTabCompetitive),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.tryAgainButton,
              onPressed: () => _load(),
            ),
          ],
        ),
        body: statsAsync.when(
          loading: () => const Center(child: FunnyLoadingView()),
          error: (error, stack) => _buildErrorState(context, l10n, error),
          data: (stats) {
            if (stats.matchesAnalyzed == 0) {
              return _buildEmptyState(context, l10n);
            }
            return TabBarView(
              children: [
                _OverallStatsTab(
                  stats: stats,
                  competitiveTiers: competitiveTiers,
                ),
                _CareerSummaryTab(
                  stats: stats,
                  competitiveTiers: competitiveTiers,
                ),
                _AllTimeCompetitiveTab(stats: stats),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    AppLocalizations l10n,
    Object error,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.genericError(error.toString()),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: Text(l10n.tryAgainButton)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.careerStatsEmptyTitle,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.careerStatsEmptyMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatPlaytime(int millis, AppLocalizations l10n) {
  final totalMinutes = millis ~/ 60000;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return l10n.careerStatsPlaytimeFormat(hours, minutes);
}

String _tierName(
  Map<int, dynamic> competitiveTiers,
  int tier,
  AppLocalizations l10n,
) {
  if (tier == 0) return l10n.unranked;
  final data = competitiveTiers[tier];
  return data?['tierName']?.toString() ?? l10n.unranked;
}

Widget _statTile(String label, String value, Color color) {
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

Widget _sectionCard(BuildContext context, {required Widget child}) {
  final theme = Theme.of(context);
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: theme.colorScheme.outlineVariant),
    ),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

class _OverallStatsTab extends ConsumerWidget {
  final CareerStats stats;
  final Map<int, dynamic> competitiveTiers;

  const _OverallStatsTab({required this.stats, required this.competitiveTiers});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final displaySettings = ref.watch(displaySettingsProvider);
    final textColor = Theme.of(context).colorScheme.onSurface;
    final kd = stats.kd.toStringAsFixed(2);
    final winRate = stats.winRate.toStringAsFixed(1);
    final hs = stats.hsPercent.toStringAsFixed(1);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.careerStatsSampleSize(stats.matchesAnalyzed),
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          context,
          child: Wrap(
            runSpacing: 16,
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width / 2 - 40,
                child: _statTile(
                  l10n.statWinrate,
                  '$winRate%',
                  stats.winRate >= 50 ? Colors.green : Colors.red,
                ),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width / 2 - 40,
                child: _statTile(
                  l10n.statKd,
                  kd,
                  stats.kd >= 1.0 ? Colors.green : Colors.red,
                ),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width / 2 - 40,
                child: _statTile(
                  l10n.careerStatsHeadshotPercent,
                  '$hs%',
                  Colors.blueAccent,
                ),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width / 2 - 40,
                child: _statTile(
                  l10n.statHours,
                  _formatPlaytime(stats.totalPlaytimeMillis, l10n),
                  Colors.orangeAccent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.careerStatsRankSectionTitle,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statTile(
                    l10n.careerStatsCurrentRank,
                    '${_tierName(competitiveTiers, stats.currentTier, l10n)} (${FormatUtils.formatNumber(stats.currentRR, displaySettings)} RR)',
                    Colors.tealAccent,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statTile(
                    l10n.careerStatsPeakRank,
                    _tierName(competitiveTiers, stats.peakTier, l10n),
                    Colors.amberAccent,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.careerStatsRecordTitle,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.careerStatsRecordFormat(
                  stats.totalWins,
                  stats.totalLosses,
                  stats.totalDraws,
                ),
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CareerSummaryTab extends StatelessWidget {
  final CareerStats stats;
  final Map<int, dynamic> competitiveTiers;

  const _CareerSummaryTab({
    required this.stats,
    required this.competitiveTiers,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textColor = Theme.of(context).colorScheme.onSurface;

    if (stats.acts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.careerStatsNoCompetitiveActs,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.grey),
          ),
        ),
      );
    }

    final acts = [...stats.acts]..sort((a, b) => b.games.compareTo(a.games));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: acts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final act = acts[index];
        return _sectionCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      act.actLabel,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  Text(
                    _tierName(competitiveTiers, act.peakTier, l10n),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.amberAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statTile(
                    l10n.statWinrate,
                    '${act.winRate.toStringAsFixed(1)}%',
                    act.winRate >= 50 ? Colors.green : Colors.red,
                  ),
                  _statTile(
                    l10n.careerStatsWinsGames,
                    l10n.careerStatsWinsGamesFormat(act.wins, act.games),
                    Colors.blueAccent,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AllTimeCompetitiveTab extends StatelessWidget {
  final CareerStats stats;

  const _AllTimeCompetitiveTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textColor = Theme.of(context).colorScheme.onSurface;

    if (stats.competitiveMatches == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.careerStatsNoCompetitiveActs,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          context,
          child: Column(
            children: [
              Text(
                l10n.careerStatsAllTimeCompetitiveTitle,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statTile(
                    l10n.statWinrate,
                    '${stats.competitiveWinRate.toStringAsFixed(1)}%',
                    stats.competitiveWinRate >= 50 ? Colors.green : Colors.red,
                  ),
                  _statTile(
                    l10n.careerStatsWinsGames,
                    l10n.careerStatsWinsGamesFormat(
                      stats.competitiveWins,
                      stats.competitiveMatches,
                    ),
                    Colors.blueAccent,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.careerStatsRecordFormat(
                  stats.competitiveWins,
                  stats.competitiveLosses,
                  stats.competitiveDraws,
                ),
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
