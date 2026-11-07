import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:valorant_thunai/models/rank_history_entry.dart';
import 'package:valorant_thunai/providers/display_settings_provider.dart';
import 'package:valorant_thunai/services/rank_history_service.dart';
import 'package:valorant_thunai/services/logger_service.dart';
import 'package:valorant_thunai/services/valorant_api.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/utils/format_utils.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

final rankHistoryProvider = FutureProvider.family<List<RankHistoryEntry>, String>((
  ref,
  puuid,
) async {
  final user = ref.watch(authProvider).user;
  if (user != null && user.puuid == puuid) {
    try {
      final api = ref.watch(valorantApiProvider);
      final matches = await api.getCompetitiveUpdates(
        shard: user.shard,
        puuid: puuid,
        accessToken: user.accessToken,
        entitlementsToken: user.entitlementsToken,
        startIndex: 0,
        endIndex: 15,
      );

      if (matches.isNotEmpty) {
        final entries = matches
            .whereType<Map>()
            .map((m) {
              final startMs = (m['MatchStartTime'] as num?)?.toInt();
              return RankHistoryEntry(
                timestamp: startMs != null
                    ? DateTime.fromMillisecondsSinceEpoch(startMs)
                    : DateTime.now(),
                tier: (m['TierAfterUpdate'] as num?)?.toInt() ?? 0,
                rr: (m['RankedRatingAfterUpdate'] as num?)?.toInt() ?? 0,
              );
            })
            .toList()
            .reversed
            .toList();

        if (entries.isNotEmpty) return entries;
      }
    } catch (e) {
      LoggerService.log(
        'Official competitive updates unavailable, falling back to local rank history: $e',
        tag: 'RankHistory',
      );
    }
  }

  return RankHistoryService.getHistory(puuid);
});

class RankHistoryCard extends ConsumerWidget {
  final String puuid;
  final int maxEntries;

  const RankHistoryCard({super.key, required this.puuid, this.maxEntries = 30});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final displaySettings = ref.watch(displaySettingsProvider);
    final historyAsync = ref.watch(rankHistoryProvider(puuid));

    return historyAsync.when(
      data: (history) {
        if (history.length < 2) {
          return const SizedBox.shrink();
        }

        final entries = history.length > maxEntries
            ? history.sublist(history.length - maxEntries)
            : history;

        final spots = <FlSpot>[
          for (var i = 0; i < entries.length; i++)
            FlSpot(i.toDouble(), entries[i].rr.toDouble()),
        ];

        final minY = entries.map((e) => e.rr).reduce((a, b) => a < b ? a : b);
        final maxY = entries.map((e) => e.rr).reduce((a, b) => a > b ? a : b);
        final padding = ((maxY - minY) * 0.15).clamp(5, 100).toDouble();

        final color = Theme.of(context).colorScheme.primary;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.show_chart, color: color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.rankHistoryTitle,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 160,
                  child: LineChart(
                    LineChartData(
                      minY: (minY - padding).clamp(0, double.infinity),
                      maxY: maxY + padding,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: ((maxY - minY + padding * 2) / 4)
                            .clamp(1, 1000),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            getTitlesWidget: (value, meta) => Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final entry = entries[spot.x.toInt()];
                              return LineTooltipItem(
                                '${FormatUtils.formatNumber(entry.rr, displaySettings)} RR',
                                const TextStyle(color: Colors.white),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: color,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: color.withValues(alpha: 0.15),
                          ),
                        ),
                      ],
                    ),
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
}
