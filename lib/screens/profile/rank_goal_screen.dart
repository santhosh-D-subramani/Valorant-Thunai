import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_thunai/providers/profile_provider.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/providers/display_settings_provider.dart';
import 'package:valorant_thunai/providers/rank_goal_provider.dart';
import 'package:valorant_thunai/screens/profile/widgets/rank_history_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/utils/cache_managers.dart';
import 'package:valorant_thunai/utils/format_utils.dart';
import 'package:valorant_thunai/utils/rank_goal_estimator.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class RankGoalScreen extends ConsumerStatefulWidget {
  const RankGoalScreen({super.key});

  @override
  ConsumerState<RankGoalScreen> createState() => _RankGoalScreenState();
}

class _RankGoalScreenState extends ConsumerState<RankGoalScreen> {
  int? _targetTierId;
  int? _startTierId;
  int? _startRR;
  DateTime? _goalSetDate;
  String? _savedSeasonName;
  List<Map<String, dynamic>> _archivedGoals = [];
  bool _isLoading = true;

  DisplaySettings get _displaySettings => ref.read(displaySettingsProvider);

  @override
  void initState() {
    super.initState();
    _loadGoal();
  }

  Future<void> _loadGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final archiveStrings = prefs.getStringList(RankGoalPrefsKeys.archive) ?? [];
    final List<Map<String, dynamic>> archive = [];
    for (final s in archiveStrings) {
      try {
        archive.add(Map<String, dynamic>.from(jsonDecode(s)));
      } catch (_) {}
    }

    setState(() {
      _targetTierId = prefs.getInt(RankGoalPrefsKeys.targetTierId);
      _startTierId = prefs.getInt(RankGoalPrefsKeys.startTierId);
      _startRR = prefs.getInt(RankGoalPrefsKeys.startRR);
      final dateStr = prefs.getString(RankGoalPrefsKeys.setDate);
      _goalSetDate = dateStr != null ? DateTime.tryParse(dateStr) : null;
      _savedSeasonName = prefs.getString(RankGoalPrefsKeys.seasonName);
      _archivedGoals = archive;
      _isLoading = false;
    });
  }

  Future<void> _saveGoal(
    int targetTierId,
    int startTierId,
    int startRR,
    String seasonName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setInt(RankGoalPrefsKeys.targetTierId, targetTierId);
    await prefs.setInt(RankGoalPrefsKeys.startTierId, startTierId);
    await prefs.setInt(RankGoalPrefsKeys.startRR, startRR);
    await prefs.setString(RankGoalPrefsKeys.setDate, now.toIso8601String());
    await prefs.setString(RankGoalPrefsKeys.seasonName, seasonName);

    setState(() {
      _targetTierId = targetTierId;
      _startTierId = startTierId;
      _startRR = startRR;
      _goalSetDate = now;
      _savedSeasonName = seasonName;
    });
    ref.invalidate(rankGoalProvider);
  }

  Future<void> _clearGoal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(RankGoalPrefsKeys.targetTierId);
    await prefs.remove(RankGoalPrefsKeys.startTierId);
    await prefs.remove(RankGoalPrefsKeys.startRR);
    await prefs.remove(RankGoalPrefsKeys.setDate);
    await prefs.remove(RankGoalPrefsKeys.seasonName);

    setState(() {
      _targetTierId = null;
      _startTierId = null;
      _startRR = null;
      _goalSetDate = null;
      _savedSeasonName = null;
    });
    ref.invalidate(rankGoalProvider);
  }

  Future<void> _archivePreviousGoal(ProfileData profileData) async {
    final prefs = await SharedPreferences.getInstance();
    final savedSeason = _savedSeasonName;
    if (savedSeason == null) return;

    int currentTierId = 0;
    int currentRR = 0;
    if (profileData.henrikMmr != null) {
      final currentData = profileData.henrikMmr!['current_data'];
      currentTierId = currentData?['currenttier'] ?? 0;
      currentRR = currentData?['ranking_in_tier'] ?? 0;
    }

    final targetTierId = _targetTierId ?? 0;
    final startTierId = _startTierId ?? 0;
    final startRR = _startRR ?? 0;
    final dateStr = prefs.getString(RankGoalPrefsKeys.setDate);
    final setDate = dateStr != null
        ? DateTime.tryParse(dateStr) ?? DateTime.now()
        : DateTime.now();

    final achieved = currentTierId >= targetTierId;

    final archiveItem = {
      'seasonName': savedSeason,
      'targetTierId': targetTierId,
      'startTierId': startTierId,
      'startRR': startRR,
      'finalTierId': currentTierId,
      'finalRR': currentRR,
      'setDate': setDate.toIso8601String(),
      'endDate': DateTime.now().toIso8601String(),
      'achieved': achieved,
    };

    final archiveListStr = prefs.getStringList(RankGoalPrefsKeys.archive) ?? [];
    archiveListStr.add(jsonEncode(archiveItem));
    await prefs.setStringList(RankGoalPrefsKeys.archive, archiveListStr);

    await _clearGoal();
    await _loadGoal();

    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      final targetName =
          profileData.competitiveTiers[targetTierId]?['tierName'] ??
          l10n.unknownItem;
      final finishedName =
          profileData.competitiveTiers[currentTierId]?['tierName'] ??
          l10n.unknownItem;
      final resultMsg = achieved
          ? l10n.goalReachedCongratulations
          : l10n.goalMissedEncouragement;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.seasonGoalArchivedTitle),
          content: Text(
            l10n.seasonGoalArchivedContent(
              savedSeason,
              targetName,
              finishedName,
              currentRR,
              resultMsg,
            ),
          ),
          actions: [
            TextButton(
              child: Text(l10n.ok),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  String _formatDate(DateTime dt) {
    return FormatUtils.formatDate(dt, _displaySettings);
  }

  void _showSetGoalDialog(
    ProfileData profileData,
    int currentTierId,
    int currentRR,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final tiers =
        profileData.competitiveTiers.entries
            .where((e) => e.key > currentTierId && e.key <= 25)
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    if (tiers.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.reachedMaxRankMessage)));
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.selectTargetRankGoal,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: tiers.length,
                  itemBuilder: (context, index) {
                    final tier = tiers[index].value;
                    final tierId = tiers[index].key;
                    final tierName = tier['tierName'] ?? l10n.unknownItem;
                    final tierIcon = tier['smallIcon'];

                    return ListTile(
                      leading: tierIcon != null
                          ? CachedNetworkImage(
                              imageUrl: tierIcon,
                              width: 36,
                              height: 36,
                              cacheManager:
                                  CustomCacheManagers.tierImageCacheManager,
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.star),
                            )
                          : const Icon(Icons.star),
                      title: Text(
                        tierName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        _saveGoal(
                          tierId,
                          currentTierId,
                          currentRR,
                          profileData.activeSeasonName,
                        );
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(displaySettingsProvider);
    final l10n = AppLocalizations.of(context)!;
    final profileState = ref.watch(profileProvider);
    final profileData = profileState.value;

    if (profileData != null &&
        _savedSeasonName != null &&
        _savedSeasonName != profileData.activeSeasonName) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _archivePreviousGoal(profileData);
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.seasonalRankGoalTitle)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (profileData != null)
          ? _buildContent(profileData)
          : profileState.when(
              data: (data) {
                if (data == null) {
                  return Center(child: Text(l10n.profileDataNotAvailable));
                }
                return _buildContent(data);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text(l10n.errorLoadingRankGoals(err.toString())),
              ),
            ),
    );
  }

  Widget _buildContent(ProfileData profileData) {
    final l10n = AppLocalizations.of(context)!;
    final currentTierId = profileData.currentTier;
    final currentRR = profileData.currentRR;

    if (_targetTierId == null) {
      final currentTierData = profileData.competitiveTiers[currentTierId];
      final currentTierName = currentTierData?['tierName'] ?? l10n.unranked;
      final currentTierIcon = currentTierData?['largeIcon'];

      return SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            if (currentTierIcon != null)
              CachedNetworkImage(
                imageUrl: currentTierIcon,
                width: 120,
                height: 120,
                cacheManager: CustomCacheManagers.tierImageCacheManager,
                errorWidget: (context, url, error) => const Icon(
                  Icons.emoji_events_outlined,
                  size: 80,
                  color: Colors.grey,
                ),
              )
            else
              const Icon(
                Icons.emoji_events_outlined,
                size: 80,
                color: Colors.grey,
              ),
            const SizedBox(height: 24),
            Text(
              l10n.noRankGoalSet,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noRankGoalSetDescription(currentTierName, currentRR),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(
                l10n.setTargetGoal,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              onPressed: () =>
                  _showSetGoalDialog(profileData, currentTierId, currentRR),
            ),
            if (_archivedGoals.isNotEmpty) _buildArchiveSection(profileData),
          ],
        ),
      );
    }

    String remainingTimeText = l10n.actEnded;
    if (profileData.activeActEndTime != null) {
      final diff = profileData.activeActEndTime!.difference(DateTime.now());
      final days = diff.inDays;
      final hours = diff.inHours;
      final minutes = diff.inMinutes;

      if (days > 0) {
        remainingTimeText = l10n.daysLeft(days);
      } else if (hours > 0) {
        remainingTimeText = l10n.hoursLeft(hours);
      } else if (minutes > 0) {
        remainingTimeText = l10n.minsLeft(minutes);
      } else {
        remainingTimeText = l10n.actEnded;
      }
    }

    final targetTierData = profileData.competitiveTiers[_targetTierId];
    final targetTierName = targetTierData?['tierName'] ?? l10n.unknownItem;
    final targetTierIcon =
        targetTierData?['largeIcon'] ?? targetTierData?['smallIcon'];

    final startTierId = _startTierId ?? currentTierId;
    final startRR = _startRR ?? currentRR;

    final totalRRDifference = ((_targetTierId! - startTierId) * 100) - startRR;
    final remainingRR = ((_targetTierId! - currentTierId) * 100) - currentRR;

    final currentProgressSinceSet = totalRRDifference - remainingRR;
    final progressPercent = totalRRDifference > 0
        ? (currentProgressSinceSet / totalRRDifference).clamp(0.0, 1.0)
        : 1.0;

    final hasReachedGoal = currentTierId >= _targetTierId!;

    final climbSteps = <int>[];
    for (int t = startTierId; t <= _targetTierId!; t++) {
      climbSteps.add(t);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.climbProgress,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_goalSetDate != null)
                        Text(
                          l10n.setPrefix(_formatDate(_goalSetDate!)),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: CircularProgressIndicator(
                          value: progressPercent,
                          strokeWidth: 8,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (targetTierIcon != null)
                            CachedNetworkImage(
                              imageUrl: targetTierIcon,
                              width: 44,
                              height: 44,
                              fit: BoxFit.contain,
                              cacheManager:
                                  CustomCacheManagers.tierImageCacheManager,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            "$targetTierName (${(progressPercent * 100).toInt()}%)",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profileData.activeSeasonName.isNotEmpty
                                ? profileData.activeSeasonName
                                : l10n.activeAct,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            remainingTimeText,
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildProgressMiniStat(
                        label: l10n.startingLabel,
                        value:
                            (profileData.competitiveTiers[startTierId]?['tierName'] ??
                                    l10n.start)
                                .toUpperCase(),
                        subValue: l10n.rrSuffix(startRR),
                      ),
                      const SizedBox(
                        height: 30,
                        child: VerticalDivider(width: 1),
                      ),
                      _buildProgressMiniStat(
                        label: l10n.currentLabel,
                        value:
                            (profileData.competitiveTiers[currentTierId]?['tierName'] ??
                                    l10n.currentRankHeader)
                                .toUpperCase(),
                        subValue: l10n.rrSuffix(currentRR),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        hasReachedGoal
                            ? l10n.goalAchieved
                            : l10n.rrToGo(remainingRR),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (currentProgressSinceSet >= 0
                                      ? Colors.green
                                      : Colors.red)
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          currentProgressSinceSet >= 0
                              ? l10n.plusRR(currentProgressSinceSet)
                              : "$currentProgressSinceSet RR",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: currentProgressSinceSet >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          _buildTrendCard(currentTierId, currentRR),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.theClimbTimeline,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: climbSteps.length,
                    itemBuilder: (context, index) {
                      final tierId = climbSteps[index];
                      final tierData = profileData.competitiveTiers[tierId];
                      final name = tierData?['tierName'] ?? l10n.unknownItem;
                      final icon = tierData?['smallIcon'];

                      final isStepCompleted =
                          currentTierId > tierId ||
                          (currentTierId == tierId && hasReachedGoal);
                      final isCurrentStep =
                          currentTierId == tierId && !hasReachedGoal;
                      final isFirst = index == 0;
                      final isLast = index == climbSteps.length - 1;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 2,
                                height: 16,
                                color: isFirst
                                    ? Colors.transparent
                                    : (isStepCompleted
                                          ? Colors.green
                                          : Theme.of(context)
                                                .colorScheme
                                                .outlineVariant),
                              ),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isStepCompleted
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : isCurrentStep
                                      ? Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.2)
                                      : Colors.grey.withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: isStepCompleted
                                        ? Colors.green
                                        : isCurrentStep
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey.shade400,
                                    width: isCurrentStep ? 4 : 2,
                                  ),
                                ),
                                child: isStepCompleted
                                    ? const Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Colors.green,
                                      )
                                    : null,
                              ),
                              Container(
                                width: 2,
                                height: 32,
                                color: isLast
                                    ? Colors.transparent
                                    : (currentTierId > tierId
                                          ? Colors.green
                                          : Theme.of(context)
                                                .colorScheme
                                                .outlineVariant),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  if (icon != null)
                                    Opacity(
                                      opacity: isStepCompleted || isCurrentStep
                                          ? 1.0
                                          : 0.4,
                                      child: CachedNetworkImage(
                                        imageUrl: icon,
                                        width: 28,
                                        height: 28,
                                        cacheManager: CustomCacheManagers
                                            .tierImageCacheManager,
                                        errorWidget: (context, url, error) =>
                                            const Icon(
                                              Icons.star_border,
                                              size: 28,
                                            ),
                                      ),
                                    )
                                  else
                                    const Icon(Icons.star_border, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isStepCompleted
                                            ? Colors.grey.shade400
                                            : isCurrentStep
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                            : Colors.grey.shade500,
                                        decoration: isStepCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                  if (isCurrentStep)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        l10n.rrSuffix(currentRR),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.delete_forever_outlined),
            label: Text(
              l10n.deleteGoal,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.deleteActiveGoalTitle),
                  content: Text(l10n.deleteActiveGoalContent),
                  actions: [
                    TextButton(
                      child: Text(l10n.cancel),
                      onPressed: () => Navigator.pop(context),
                    ),
                    TextButton(
                      child: Text(
                        l10n.delete,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        _clearGoal();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          if (_archivedGoals.isNotEmpty) _buildArchiveSection(profileData),
        ],
      ),
    );
  }

  Widget _buildTrendCard(int currentTierId, int currentRR) {
    final l10n = AppLocalizations.of(context)!;
    final puuid = ref.watch(authProvider).user?.puuid;
    if (puuid == null) return const SizedBox.shrink();

    final historyAsync = ref.watch(rankHistoryProvider(puuid));

    return historyAsync.when(
      data: (history) {
        final estimate = computeRankGoalEstimate(
          history: history,
          targetTierId: _targetTierId!,
          currentTierId: currentTierId,
          currentRR: currentRR,
        );

        String headline;
        String? subline;
        Color color = Theme.of(context).colorScheme.primary;

        switch (estimate.status) {
          case RankGoalTrendStatus.goalReached:
            headline = l10n.goalAchieved;
            color = Colors.green;
            break;
          case RankGoalTrendStatus.notEnoughData:
            headline = l10n.rankGoalNotEnoughData;
            break;
          case RankGoalTrendStatus.trendingAway:
            headline = l10n.rankGoalTrendingAway;
            color = Theme.of(context).colorScheme.error;
            subline = l10n.rankGoalAvgRRPerGame(
              estimate.avgRRPerGame.toStringAsFixed(1),
              estimate.gamesConsidered,
            );
            break;
          case RankGoalTrendStatus.onTrack:
            headline = l10n.rankGoalEstimatedGames(estimate.estimatedGames!);
            subline = l10n.rankGoalAvgRRPerGame(
              estimate.avgRRPerGame.toStringAsFixed(1),
              estimate.gamesConsidered,
            );
            break;
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Icon(Icons.timeline, color: color),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.rankGoalTrendTitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade500,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        headline,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      if (subline != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subline,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildProgressMiniStat({
    required String label,
    required String value,
    required String subValue,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          subValue,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Future<void> _deleteArchivedEntry(int index) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteHistoryEntryTitle),
        content: Text(l10n.deleteHistoryEntryContent),
        actions: [
          TextButton(
            child: Text(l10n.cancel),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text(
              l10n.delete,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      final archiveListStr =
          prefs.getStringList(RankGoalPrefsKeys.archive) ?? [];
      if (index >= 0 && index < archiveListStr.length) {
        archiveListStr.removeAt(index);
        await prefs.setStringList(RankGoalPrefsKeys.archive, archiveListStr);
        await _loadGoal();
      }
    }
  }

  Widget _buildArchiveSection(ProfileData profileData) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          l10n.goalHistory,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _archivedGoals.length,
          itemBuilder: (context, index) {
            final item = _archivedGoals[index];
            final season = item['seasonName'] ?? l10n.unknownSeason;
            final targetId = item['targetTierId'] ?? 0;
            final finalId = item['finalTierId'] ?? 0;
            final achieved = item['achieved'] ?? false;

            final targetName =
                profileData.competitiveTiers[targetId]?['tierName'] ??
                l10n.unknownItem;
            final finalName =
                profileData.competitiveTiers[finalId]?['tierName'] ??
                l10n.unknownItem;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  achieved ? Icons.emoji_events : Icons.history,
                  color: achieved ? Colors.amber : Colors.grey,
                ),
                title: Text(season),
                subtitle: Text(
                  l10n.goalHistoryTargetFinished(targetName, finalName),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (achieved ? Colors.green : Colors.red)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        achieved ? l10n.achievedStatus : l10n.missedStatus,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: achieved ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _deleteArchivedEntry(index),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
