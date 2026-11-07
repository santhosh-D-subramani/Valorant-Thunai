import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:valorant_thunai/providers/display_settings_provider.dart';
import 'package:valorant_thunai/providers/skin_provider.dart';
import 'package:valorant_thunai/services/shop_history_service.dart';
import 'package:valorant_thunai/screens/media/skin_details_screen.dart';
import 'package:valorant_thunai/utils/format_utils.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class ShopHistoryScreen extends ConsumerWidget {
  final String puuid;

  static const int _staleThresholdDays = 14;

  const ShopHistoryScreen({super.key, required this.puuid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final skinsMetadata = ref.watch(skinsMetadataProvider).value ?? const {};
    final displaySettings = ref.watch(displaySettingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.shopHistoryTitle)),
      body: FutureBuilder<List<ShopHistoryEntry>>(
        future: ShopHistoryService.getHistory(puuid),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  l10n.shopHistoryEmptyState,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }

          final seenCount = ShopHistoryService.appearanceCounts(entries);
          final lastSeen = ShopHistoryService.lastSeenDates(entries);

          final todaySkinIds =
              entries.isNotEmpty && _isToday(entries.first.date)
              ? entries.first.skinIds.toSet()
              : const <String>{};
          final staleEntries = lastSeen.entries.where((e) {
            if (todaySkinIds.contains(e.key)) return false;
            final days = _daysBetween(e.value, DateTime.now());
            return days >= _staleThresholdDays;
          }).toList()..sort((a, b) => a.value.compareTo(b.value));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length + (staleEntries.isEmpty ? 0 : 1),
            itemBuilder: (context, index) {
              if (staleEntries.isNotEmpty && index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 2),
                        child: Text(
                          l10n.shopHistoryNotSeenRecentlyHeader,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          l10n.shopHistoryNotSeenRecentlySubtitle,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 130,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: staleEntries.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, i) {
                            final skinId = staleEntries[i].key;
                            final meta = skinsMetadata[skinId];
                            final days = _daysBetween(
                              staleEntries[i].value,
                              DateTime.now(),
                            );
                            return _SkinHistoryCard(
                              name: meta?.displayName ?? 'Valorant Weapon',
                              iconUrl: meta?.displayIcon ?? '',
                              badgeText: l10n.shopHistoryLastSeenDaysAgo(days),
                              onTap: meta == null
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              SkinDetailsScreen(skin: meta),
                                        ),
                                      );
                                    },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }

              final entry = entries[index - (staleEntries.isEmpty ? 0 : 1)];
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        _formatDate(entry.date, displaySettings),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 130,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: entry.skinIds.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final skinId = entry.skinIds[i];
                          final meta = skinsMetadata[skinId];
                          final count = seenCount[skinId] ?? 1;
                          return _SkinHistoryCard(
                            name: meta?.displayName ?? 'Valorant Weapon',
                            iconUrl: meta?.displayIcon ?? '',
                            badgeText: count > 1
                                ? l10n.shopHistorySeenCount(count)
                                : null,
                            onTap: meta == null
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            SkinDetailsScreen(skin: meta),
                                      ),
                                    );
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
        },
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  int _daysBetween(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  String _formatDate(DateTime date, DisplaySettings displaySettings) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return FormatUtils.formatDate(date, displaySettings);
  }
}

class _SkinHistoryCard extends StatelessWidget {
  final String name;
  final String iconUrl;
  final String? badgeText;
  final VoidCallback? onTap;

  const _SkinHistoryCard({
    required this.name,
    required this.iconUrl,
    this.badgeText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Expanded(
              child: iconUrl.isEmpty
                  ? Icon(
                      Icons.shield_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  : CachedNetworkImage(
                      imageUrl: iconUrl,
                      fit: BoxFit.contain,
                      errorWidget: (context, url, error) => Icon(
                        Icons.shield_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (badgeText != null) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText!,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
