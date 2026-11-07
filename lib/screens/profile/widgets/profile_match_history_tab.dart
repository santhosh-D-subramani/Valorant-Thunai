import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/providers/display_settings_provider.dart';
import 'package:valorant_thunai/screens/matches/match_detail_screen.dart';
import 'package:valorant_thunai/services/valorant_api.dart';
import 'package:valorant_thunai/utils/format_utils.dart';

class ProfileMatchHistoryTab extends ConsumerStatefulWidget {
  final String puuid;
  final String region;
  final String accountId;

  const ProfileMatchHistoryTab({
    super.key,
    required this.puuid,
    required this.region,
    required this.accountId,
  });

  @override
  ConsumerState<ProfileMatchHistoryTab> createState() =>
      _ProfileMatchHistoryTabState();
}

class _ProfileMatchHistoryTabState
    extends ConsumerState<ProfileMatchHistoryTab> {
  final List<dynamic> _matches = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  int _startIndex = 0;
  final int _pageSize = 15;
  bool _hasMore = true;

  String _selectedQueue = 'all';
  String _selectedSort = 'desc';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData(clear: true);
      }
    });
  }

  Future<void> _loadData({bool clear = false}) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (clear) {
      setState(() {
        _startIndex = 0;
        _matches.clear();
        _hasMore = true;
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final authState = ref.read(authProvider);
      final user = authState.user;
      if (user == null) {
        throw Exception(l10n.sessionExpiredOrNotLoggedIn);
      }

      final api = ref.read(valorantApiProvider);
      final historyData = await api.getMatchHistory(
        shard: user.shard,
        puuid: widget.puuid,
        accessToken: user.accessToken,
        entitlementsToken: user.entitlementsToken,
        startIndex: _startIndex,
        endIndex: _startIndex + _pageSize,
        queue: _selectedQueue == 'all' ? null : _selectedQueue,
      );

      if (historyData != null) {
        final List historyList = historyData['History'] ?? [];
        final int total = historyData['Total'] ?? 0;

        if (mounted) {
          setState(() {
            _matches.addAll(historyList);
            _startIndex += historyList.length;
            if (historyList.length < _pageSize || _startIndex >= total) {
              _hasMore = false;
            }
            _isLoading = false;
            _isLoadingMore = false;
          });
        }
      } else {
        throw Exception(l10n.failedToLoadMatchHistory);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst("Exception: ", "");
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _applyLocalSorting() {
    if (_selectedSort == 'desc') {
      _matches.sort((a, b) {
        final int timeA = a['GameStartTime'] ?? 0;
        final int timeB = b['GameStartTime'] ?? 0;
        return timeB.compareTo(timeA);
      });
    } else {
      _matches.sort((a, b) {
        final int timeA = a['GameStartTime'] ?? 0;
        final int timeB = b['GameStartTime'] ?? 0;
        return timeA.compareTo(timeB);
      });
    }
  }

  String _getFriendlyQueueName(String? queueId, AppLocalizations l10n) {
    if (queueId == null || queueId.isEmpty) return l10n.queueCustomUnknown;
    final lower = queueId.toLowerCase();
    switch (lower) {
      case 'competitive':
        return l10n.queueCompetitive;
      case 'unrated':
        return l10n.queueUnrated;
      case 'swiftplay':
        return l10n.queueSwiftplay;
      case 'spikerush':
        return l10n.queueSpikeRush;
      case 'deathmatch':
        return l10n.queueDeathmatch;
      case 'ggteam':
        return l10n.queueEscalation;
      case 'onefa':
        return l10n.queueReplication;
      case 'snowballfight':
        return l10n.queueSnowballFight;
      case 'hurm':
        return l10n.queueTeamDeathmatch;
      case 'fortcollins':
        return l10n.queueRetake;
      default:
        return queueId.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final displaySettings = ref.watch(displaySettingsProvider);

    final queues = [
      {'value': 'all', 'label': l10n.allQueuesFilter},
      {'value': 'competitive', 'label': l10n.queueCompetitive},
      {'value': 'unrated', 'label': l10n.queueUnrated},
      {'value': 'swiftplay', 'label': l10n.queueSwiftplay},
      {'value': 'spikerush', 'label': l10n.queueSpikeRush},
      {'value': 'deathmatch', 'label': l10n.queueDeathmatch},
    ];

    _applyLocalSorting();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.matchHistoryTitle,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              color: const Color(0xFFFF4655),
              onPressed: () => _loadData(clear: true),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedQueue,
                      isExpanded: true,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      items: queues.map((q) {
                        return DropdownMenuItem<String>(
                          value: q['value'],
                          child: Text(q['label']!),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null && val != _selectedQueue) {
                          setState(() {
                            _selectedQueue = val;
                          });
                          _loadData(clear: true);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 24,
                  width: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSort,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'desc',
                        child: Text(l10n.sortNewest),
                      ),
                      DropdownMenuItem(
                        value: 'asc',
                        child: Text(l10n.sortOldest),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null && val != _selectedSort) {
                        setState(() {
                          _selectedSort = val;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: FunnyLoadingView(),
            ),
          )
        else if (_error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text(
                    l10n.genericError(_error!),
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _loadData(clear: true),
                    child: Text(l10n.tryAgainButton),
                  ),
                ],
              ),
            ),
          )
        else if (_matches.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Text(l10n.noMatchesFoundForFilter),
            ),
          )
        else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _matches.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final match = _matches[index];
              final matchId = match['MatchID'] ?? '';
              final queueId = match['QueueID'] ?? '';
              final startTime = match['GameStartTime'] ?? 0;

              final matchDate = startTime > 0
                  ? DateTime.fromMillisecondsSinceEpoch(startTime)
                  : DateTime.now();

              final dateLabel =
                  FormatUtils.formatDateTime(matchDate, displaySettings);

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MatchDetailPage(
                          matchId: matchId,
                          playerPuuid: widget.puuid,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                theme.colorScheme.surface,
                                theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                              ]
                            : [
                                Colors.white,
                                theme.colorScheme.primaryContainer.withValues(
                                  alpha: 0.1,
                                ),
                              ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.sports_esports,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getFriendlyQueueName(queueId, l10n),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateLabel,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          if (_hasMore)
            Center(
              child: _isLoadingMore
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () => _loadData(clear: false),
                      icon: const Icon(Icons.expand_more),
                      label: Text(l10n.loadMoreButton),
                    ),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  l10n.noMoreMatchesToLoad,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
