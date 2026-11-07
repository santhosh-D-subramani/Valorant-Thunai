import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';
import 'package:valorant_thunai/providers/collection_value_provider.dart';
import 'package:valorant_thunai/providers/display_settings_provider.dart';
import 'package:valorant_thunai/utils/format_utils.dart';

class CollectionValueScreen extends ConsumerWidget {
  const CollectionValueScreen({super.key});

  Color _parseRiotColor(String hexStr) {
    var hex = hexStr.replaceAll('#', '').trim();
    if (hex.length == 8) {
      final r = hex.substring(0, 2);
      final g = hex.substring(2, 4);
      final b = hex.substring(4, 6);
      final a = hex.substring(6, 8);
      hex = '$a$r$g$b';
    } else if (hex.length == 6) {
      hex = 'FF$hex';
    } else {
      return Colors.grey;
    }
    try {
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  String _tierFallbackLabel(AppLocalizations l10n, String tierUuid) {
    return switch (tierUuid) {
      '12683d76-48d7-84a3-4e09-6985794f0445' => l10n.collectionValueTierSelect,
      '0cebb8be-46d7-c12a-d306-e9907bfc5a25' => l10n.collectionValueTierDeluxe,
      '60bca009-4182-7998-dee7-b8a2558dc369' => l10n.collectionValueTierPremium,
      '411e4a55-4e59-7757-41f0-86a53f101bb5' => l10n.collectionValueTierUltra,
      'e046854e-406c-37f4-6607-19a9ba8426fc' =>
        l10n.collectionValueTierExclusive,
      _ => tierUuid,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final collectionAsync = ref.watch(collectionValueProvider);
    final displaySettings = ref.watch(displaySettingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.collectionValueScreenTitle)),
      body: collectionAsync.when(
        loading: () => const Center(child: FunnyLoadingView()),
        error: (error, stack) => _buildErrorState(context, ref, l10n, error),
        data: (collection) {
          if (collection.totalSkinsOwned == 0) {
            return _buildEmptyState(context, l10n);
          }
          return _buildContent(context, l10n, collection, displaySettings);
        },
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    WidgetRef ref,
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
              l10n.collectionValueErrorMessage(error.toString()),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(collectionValueProvider),
              child: Text(l10n.collectionValueRetry),
            ),
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
              Icons.inventory_2_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.collectionValueEmptyTitle,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.collectionValueEmptyMessage,
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

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    CollectionValue collection,
    DisplaySettings displaySettings,
  ) {
    final theme = Theme.of(context);
    final maxTierValue = collection.breakdown.fold<int>(
      0,
      (max, row) => row.totalValueVp > max ? row.totalValueVp : max,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  l10n.collectionValueTotalLabel,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      FormatUtils.formatNumber(
                        collection.totalValueVp,
                        displaySettings,
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'VP',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFF4655),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.collectionValueSkinsOwnedLabel(
                    collection.totalSkinsOwned,
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.collectionValueBreakdownTitle,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...collection.breakdown.map((row) {
          final color = _parseRiotColor(row.color);
          final progress = maxTierValue == 0
              ? 0.0
              : row.totalValueVp / maxTierValue;
          final tierName = row.tierName.isNotEmpty
              ? row.tierName
              : _tierFallbackLabel(l10n, row.tierUuid);

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tierName,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          l10n.collectionValueCountAndValue(
                            row.ownedCount,
                            row.unitPriceVp,
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${FormatUtils.formatNumber(row.totalValueVp, displaySettings)} VP',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Text(
          l10n.collectionValueDisclaimer,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
