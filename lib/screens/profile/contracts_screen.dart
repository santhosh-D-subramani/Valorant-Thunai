import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:valorant_thunai/providers/contracts_provider.dart';
import 'package:valorant_thunai/providers/display_settings_provider.dart';
import 'package:valorant_thunai/services/xp_forecast_service.dart';
import 'package:valorant_thunai/screens/profile/agent_gear_screen.dart';
import 'package:valorant_thunai/screens/profile/battlepass_screen.dart';
import 'package:valorant_thunai/utils/format_utils.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class ContractsPage extends ConsumerStatefulWidget {
  const ContractsPage({super.key});

  @override
  ConsumerState<ContractsPage> createState() => _ContractsPageState();
}

class _ContractsPageState extends ConsumerState<ContractsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _countdownTimer;
  int _secondsOffset = 0;
  bool _futureWeekliesExpanded = false;

  DisplaySettings get _displaySettings => ref.read(displaySettingsProvider);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsOffset++;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00:00';
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = secs.toString().padLeft(2, '0');

    if (days > 0) {
      return '${days}d $hStr:$mStr:$sStr';
    }
    return '$hStr:$mStr:$sStr';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final contractsAsync = ref.watch(contractsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    ref.watch(displaySettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.contractsMissionsTitle),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          tabs: [
            Tab(text: l10n.missionsTab),
            Tab(text: l10n.battlePassTab),
            Tab(text: l10n.eventPassTab),
            Tab(text: l10n.agentsTab),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(contractsProvider);
            },
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refreshDataTooltip,
          ),
        ],
      ),
      body: SafeArea(
        child: contractsAsync.when(
          data: (data) {
            if (data == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.hourglass_empty_rounded,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.progressionDataNotAvailable,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          ref.invalidate(contractsProvider);
                        },
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.refreshDataTooltip),
                      ),
                    ],
                  ),
                ),
              );
            }
            return TabBarView(
              controller: _tabController,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildMissionsTab(data, isDark),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildPassTab(
                    data.battlePass,
                    isDark,
                    isBattlePass: true,
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildPassTab(data.eventPass, isDark),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildAgentsTab(data.agentContracts, isDark),
                ),
              ],
            );
          },
          loading: () => const Center(child: FunnyLoadingView()),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.errorLoadingContracts(err.toString()),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: theme.colorScheme.error,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      ref.invalidate(contractsProvider);
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.refreshDataTooltip),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissionsTab(ContractsData data, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final dailyReset = (data.dailyResetSeconds - _secondsOffset).clamp(
      0,
      9999999,
    );
    final weeklyReset = (data.weeklyResetSeconds - _secondsOffset).clamp(
      0,
      9999999,
    );
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.dailyCheckpointsHeader,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _formatDuration(dailyReset),
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDailyCheckpoints(data.activeDailyCheckpoints),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildSectionCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.weeklyMissionsHeader,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _formatDuration(weeklyReset),
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (data.activeWeeklyMissions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    l10n.allWeekliesCompleted,
                    style: GoogleFonts.inter(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Column(
                  children: data.activeWeeklyMissions
                      .map((m) => _buildMissionItem(m, isDark))
                      .toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildFutureWeekliesAccordion(data, isDark),
      ],
    );
  }

  Widget _buildDailyCheckpoints(int completed) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (index) {
        final isDone = index < completed;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  border: Border.all(
                    color: isDone
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    width: 2,
                  ),
                ),
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
              if (index < 3)
                Expanded(
                  child: Container(
                    height: 2,
                    color: index < (completed - 1)
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildMissionItem(MissionProgress m, bool isDark) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  m.title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
              if (m.isComplete)
                const Icon(Icons.check_circle, color: Colors.green)
              else
                Text(
                  '+${FormatUtils.formatNumber(m.xpGrant, _displaySettings)} XP',
                  style: GoogleFonts.inter(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: m.progressToComplete > 0
                          ? m.progress / m.progressToComplete
                          : 0,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        theme.colorScheme.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${m.progress}/${m.progressToComplete}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFutureWeekliesAccordion(ContractsData data, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    int totalXP = 0;
    int totalCount = 0;
    data.futureWeeklyMissions.forEach((key, list) {
      for (var m in list) {
        totalXP += (m['xpGrant'] as int? ?? 0);
        totalCount++;
      }
    });

    if (totalCount == 0) return const SizedBox.shrink();

    final xpStr = FormatUtils.formatNumber(totalXP, _displaySettings);

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      elevation: 0,
      child: ExpansionTile(
        title: Text(
          l10n.futureWeekliesCountHeader(totalCount),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '+$xpStr XP',
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _futureWeekliesExpanded ? Icons.expand_less : Icons.expand_more,
            ),
          ],
        ),
        onExpansionChanged: (val) {
          setState(() {
            _futureWeekliesExpanded = val;
          });
        },
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: data.futureWeeklyMissions.entries.map((entry) {
                final weekIndex = entry.key;
                final list = entry.value;
                int weekXP = list.fold(
                  0,
                  (sum, m) => sum + (m['xpGrant'] as int? ?? 0),
                );
                final weekXpStr =
                    FormatUtils.formatNumber(weekXP, _displaySettings);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.inWeeks(
                              weekIndex,
                              weekIndex > 1 ? 'weeks' : 'week',
                            ),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            '+$weekXpStr XP',
                            style: GoogleFonts.inter(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...list.map((m) {
                      final title =
                          m['displayTitle'] ??
                          m['title'] ??
                          l10n.missionDefaultTitle;
                      final xp = m['xpGrant'] ?? 0;
                      final singleXpStr =
                          FormatUtils.formatNumber(xp, _displaySettings);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: GoogleFonts.inter(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '+$singleXpStr XP',
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 20),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassTab(
    PassProgress? pass,
    bool isDark, {
    bool isBattlePass = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (pass == null) {
      return _buildSectionCard(
        isDark: isDark,
        child: Center(
          child: Text(
            l10n.noActivePassAvailable,
            style: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final remaining = pass.expirationTime != null
        ? pass.expirationTime!
                  .difference(DateTime.now())
                  .inSeconds
                  .clamp(0, 9999999) -
              _secondsOffset
        : 0;

    final progressPercent = pass.percentage.toStringAsFixed(0);
    final currentXpStr =
        FormatUtils.formatNumber(pass.currentLevelXp, _displaySettings);
    final neededXpStr =
        FormatUtils.formatNumber(pass.nextLevelXpNeeded, _displaySettings);
    final remainingXpStr = FormatUtils.formatNumber(
      pass.nextLevelXpNeeded - pass.currentLevelXp,
      _displaySettings,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      pass.displayName,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _formatDuration(remaining),
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 64,
                      height: 64,
                      color: theme.colorScheme.surfaceContainerHighest,
                      padding: const EdgeInsets.all(4),
                      child:
                          pass.activeRewardIcon != null &&
                              pass.activeRewardIcon!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: pass.activeRewardIcon!,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: FunnyLoadingView(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                              ),
                            )
                          : const Icon(Icons.emoji_events, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pass.activeRewardName ?? l10n.nextReward,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.passLevelFormat(
                            pass.currentLevel,
                            pass.totalLevels,
                          ),
                          style: GoogleFonts.inter(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pass.nextLevelXpNeeded > 0
                      ? pass.currentLevelXp / pass.nextLevelXpNeeded
                      : 0,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$progressPercent% — $currentXpStr / $neededXpStr XP',
                    style: GoogleFonts.inter(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '$remainingXpStr XP',
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.circle_outlined,
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildXpForecastCard(pass.forecast, isDark),
        if (isBattlePass) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BattlepassScreen(),
                ),
              );
            },
            icon: const Icon(Icons.grid_view_rounded),
            label: Text(l10n.battlepassViewAllTiers),
          ),
        ],
      ],
    );
  }

  Widget _buildXpForecastCard(BattlepassForecast forecast, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (!forecast.hasEstimate) {
      return _buildSectionCard(
        isDark: isDark,
        child: Row(
          children: [
            Icon(
              Icons.timeline,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.xpForecastGatheringData,
                style: GoogleFonts.inter(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final xpPerDayStr =
        FormatUtils.formatNumber(forecast.xpPerDay!.round(), _displaySettings);

    return _buildSectionCard(
      isDark: isDark,
      child: Row(
        children: [
          Icon(Icons.trending_up, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.xpForecastDaysFormat(forecast.estimatedDaysRemaining!),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.xpForecastRatePerDay(xpPerDayStr),
                  style: GoogleFonts.inter(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentsTab(AgentContractsData agent, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final curXpStr =
        FormatUtils.formatNumber(agent.currentProgressXp, _displaySettings);
    final maxAgentXpStr =
        FormatUtils.formatNumber(agent.totalNeededXp, _displaySettings);
    final kCreditsStr =
        FormatUtils.formatNumber(agent.kingdomCreditsBalance, _displaySettings);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.agentRecruitmentHeader,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text(
                        '${agent.unlockedCount}/${agent.totalAgents}',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.unlockedLabel,
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  Column(
                    children: [
                      Text(
                        agent.completedCount.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.completedLabel,
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: agent.totalNeededXp > 0
                      ? agent.currentProgressXp / agent.totalNeededXp
                      : 0,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.circle_outlined,
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$curXpStr / $maxAgentXpStr',
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.toll,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        kCreditsStr,
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AgentGearScreen()),
            );
          },
          icon: const Icon(Icons.diamond_outlined),
          label: Text(l10n.agentGearTitle),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required bool isDark, required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}
