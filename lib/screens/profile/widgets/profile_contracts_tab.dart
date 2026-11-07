import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:valorant_thunai/providers/contracts_provider.dart';
import 'package:valorant_thunai/providers/display_settings_provider.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:valorant_thunai/providers/profile_provider.dart';
import 'package:valorant_thunai/theme/app_theme.dart';
import 'package:valorant_thunai/utils/format_utils.dart';

class ProfileContractsTab extends ConsumerStatefulWidget {
  const ProfileContractsTab({super.key});

  @override
  ConsumerState<ProfileContractsTab> createState() =>
      _ProfileContractsTabState();
}

class _ProfileContractsTabState extends ConsumerState<ProfileContractsTab> {
  String _activeTab = 'Missions';
  Timer? _countdownTimer;
  int _secondsOffset = 0;
  bool _futureWeekliesExpanded = false;
  bool _recentXpExpanded = false;

  DisplaySettings get _displaySettings => ref.read(displaySettingsProvider);

  @override
  void initState() {
    super.initState();
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
    if (hours < 10 && _activeTab == 'Missions') {
      return '$hours:$mStr:$sStr';
    }
    return '$hStr:$mStr:$sStr';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(displaySettingsProvider);
    final contractsAsync = ref.watch(contractsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161618) : Colors.grey[100],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Contracts',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () {
                  ref.invalidate(contractsProvider);
                },
                icon: const Icon(Icons.refresh),
                color: const Color(0xFFFF4655),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  [
                    'Missions',
                    'Battle Pass',
                    'Account',
                    'Event Pass',
                    'Agents',
                  ].map((tab) {
                    final isSelected = _activeTab == tab;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InkWell(
                        onTap: () => setState(() => _activeTab = tab),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF4655)
                                      .withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFF4655)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            tab,
                            style: GoogleFonts.inter(
                              color: isSelected
                                  ? const Color(0xFFFF4655)
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          contractsAsync.when(
            data: (data) {
              if (data == null) {
                return const Center(
                  child: Text('Progression data not available'),
                );
              }
              return _buildTabContent(data, isDark);
            },
            loading: () => const Center(child: FunnyLoadingView()),
            error: (err, stack) =>
                Center(child: Text('Error loading contracts: $err')),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(ContractsData data, bool isDark) {
    switch (_activeTab) {
      case 'Missions':
        return _buildMissionsTab(data, isDark);
      case 'Battle Pass':
        return _buildPassTab(data.battlePass, 'Season 2026 // Act IV', isDark);
      case 'Account':
        return _buildAccountTab(data, isDark);
      case 'Event Pass':
        return _buildPassTab(data.eventPass, 'Event Pass', isDark);
      case 'Agents':
        return _buildAgentsTab(data.agentContracts, isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMissionsTab(ContractsData data, bool isDark) {
    final dailyReset = (data.dailyResetSeconds - _secondsOffset).clamp(
      0,
      9999999,
    );
    final weeklyReset = (data.weeklyResetSeconds - _secondsOffset).clamp(
      0,
      9999999,
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
                  Text(
                    'Daily Checkpoints',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _formatDuration(dailyReset),
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey,
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
                    'Weekly Missions',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _formatDuration(weeklyReset),
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey,
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
                    'All weeklies completed!',
                    style: GoogleFonts.inter(color: Colors.grey),
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
                  color: isDone ? const Color(0xFFFF4655) : Colors.grey[900],
                  border: Border.all(
                    color: isDone ? const Color(0xFFFF4655) : Colors.grey[800]!,
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
                        ? const Color(0xFFFF4655)
                        : Colors.grey[800],
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildMissionItem(MissionProgress m, bool isDark) {
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
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              if (m.isComplete)
                const Icon(Icons.check_circle, color: Colors.green)
              else
                Text(
                  '+${FormatUtils.formatNumber(m.xpGrant, _displaySettings)} XP',
                  style: GoogleFonts.inter(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          if (!m.isComplete) ...[
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
                      backgroundColor: Colors.grey[800],
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFFFF4655),
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
                    color: Colors.grey,
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
      elevation: 0,
      child: ExpansionTile(
        title: Text(
          '$totalCount Future Weeklies',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '+$xpStr XP',
              style: GoogleFonts.inter(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _futureWeekliesExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey,
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
                            'in $weekIndex week${weekIndex > 1 ? 's' : ''}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFFF4655),
                            ),
                          ),
                          Text(
                            '+$weekXpStr XP',
                            style: GoogleFonts.inter(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...list.map((m) {
                      final title = m['title'] ?? 'Mission';
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
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[800],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '+$singleXpStr XP',
                              style: GoogleFonts.inter(
                                color: Colors.grey,
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

  Widget _buildPassTab(PassProgress? pass, String defaultName, bool isDark) {
    if (pass == null) {
      return _buildSectionCard(
        isDark: isDark,
        child: Center(
          child: Text(
            'No active pass available currently.',
            style: GoogleFonts.inter(color: Colors.grey),
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
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _formatDuration(remaining),
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey,
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
                      color: isDark ? Colors.grey[900] : Colors.grey[200],
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
                          pass.activeRewardName ?? 'Next Reward',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Level ${pass.currentLevel} / ${pass.totalLevels}',
                          style: GoogleFonts.inter(
                            color: Colors.grey,
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
                  backgroundColor: Colors.grey[800],
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFFF4655)),
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
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '$remainingXpStr XP',
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.circle_outlined,
                        size: 12,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 0,
          ),
          child: Text(
            'View ${pass.displayName}',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountTab(ContractsData data, bool isDark) {
    final accountXp = ref.read(profileProvider).value?.accountXp ?? {};
    final progress = accountXp['Progress'] ?? {};
    final level = progress['Level'] ?? 1;
    final xp = progress['XP'] ?? 0;
    final maxLvlXp = 5000;
    final remainingLvlXp = maxLvlXp - xp;
    final nextFirstWinStr = accountXp['NextTimeFirstWinAvailable'] ?? '';
    final nextFirstWin = DateTime.tryParse(nextFirstWinStr) ?? DateTime.now();
    final firstWinResetSeconds =
        nextFirstWin.difference(DateTime.now()).inSeconds.clamp(0, 9999999) -
        _secondsOffset;

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
                    'Account Level',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    level.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFF4655),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: xp / maxLvlXp,
                  backgroundColor: Colors.grey[800],
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFFF4655)),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${FormatUtils.formatNumber(xp, _displaySettings)} / ${FormatUtils.formatNumber(5000, _displaySettings)} XP',
                    style: GoogleFonts.inter(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${FormatUtils.formatNumber(remainingLvlXp, _displaySettings)} remaining',
                    style: GoogleFonts.inter(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'First Win of the Day',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _formatDuration(firstWinResetSeconds),
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
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
                    'Recent XP',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    'Last ${data.recentXpHistory.length} matches',
                    style: GoogleFonts.inter(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (data.recentXpHistory.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'No recent match history found.',
                    style: GoogleFonts.inter(color: Colors.grey),
                  ),
                )
              else ...[
                Column(
                  children: data.recentXpHistory
                      .take(_recentXpExpanded ? data.recentXpHistory.length : 3)
                      .map((rx) => _buildRecentXpItem(rx, isDark))
                      .toList(),
                ),
                if (data.recentXpHistory.length > 3) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () =>
                        setState(() => _recentXpExpanded = !_recentXpExpanded),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _recentXpExpanded ? 'Show Less' : 'Show More',
                          style: GoogleFonts.inter(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(
                          _recentXpExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentXpItem(RecentMatchXp rx, bool isDark) {
    final difference = DateTime.now().difference(rx.matchTime);
    String timeAgo = '';
    if (difference.inDays > 0) {
      timeAgo = '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      timeAgo = '${difference.inHours}h ago';
    } else {
      timeAgo = '${difference.inMinutes}m ago';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '+${FormatUtils.formatNumber(rx.totalXp, _displaySettings)} XP',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFF4655),
                  fontSize: 15,
                ),
              ),
              Text(
                timeAgo,
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Column(
              children: rx.xpBreakdown.entries.map((entry) {
                IconData icon = Icons.access_time;
                if (entry.key.contains('Win')) icon = Icons.emoji_events;
                if (entry.key.contains('Mission')) icon = Icons.check_circle;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      Icon(icon, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        entry.key,
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '+${FormatUtils.formatNumber(entry.value, _displaySettings)}',
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildAgentsTab(AgentContractsData agent, bool isDark) {
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
                'Agent Contracts',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
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
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unlocked',
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[800]),
                  Column(
                    children: [
                      Text(
                        agent.completedCount.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Completed',
                        style: GoogleFonts.inter(
                          color: Colors.grey,
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
                  backgroundColor: Colors.grey[800],
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFFF4655)),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.circle_outlined,
                        size: 12,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$curXpStr / $maxAgentXpStr',
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.toll,
                        size: 14,
                        color: Color(0xFFFF4655),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        kCreditsStr,
                        style: GoogleFonts.inter(
                          color: Colors.grey,
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
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 0,
          ),
          child: Text(
            'View Agent Contracts',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required bool isDark, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.brXl,
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}
