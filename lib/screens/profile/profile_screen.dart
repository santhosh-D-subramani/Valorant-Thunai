import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/providers/display_settings_provider.dart';
import 'package:valorant_thunai/providers/profile_provider.dart';
import 'package:valorant_thunai/services/riot_auth_service.dart';
import 'package:valorant_thunai/screens/profile/player_search_screen.dart';
import 'package:valorant_thunai/screens/loadout/loadout_main_screen.dart';
import 'package:valorant_thunai/screens/profile/collection_value_screen.dart';
// import 'package:valorant_thunai/screens/profile/career_stats_screen.dart';
import 'package:valorant_thunai/screens/profile/widgets/profile_match_history_tab.dart';
import 'package:valorant_thunai/screens/profile/widgets/rank_history_card.dart';
import 'package:valorant_thunai/screens/profile/widgets/account_xp_card.dart';
import 'package:valorant_thunai/theme/app_theme.dart';
import 'package:valorant_thunai/utils/cache_managers.dart';
import 'package:valorant_thunai/utils/format_utils.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

typedef ProfileScreen = ProfilePage;

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final profileDataAsync = ref.watch(profileProvider);
    final displaySettings = ref.watch(displaySettingsProvider);

    if (user == null) {
      return Center(child: Text(l10n.notLoggedIn));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabProfile),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.searchPlayersTitle,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PlayerSearchPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              profileDataAsync.when(
                data: (profileData) {
                  if (profileData == null) {
                    return Center(child: Text(l10n.profileDataNotAvailable));
                  }
                  final banWidget = _buildBanWarningCard(
                    profileData,
                    Theme.of(context).brightness == Brightness.dark,
                    displaySettings,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProfileCard(user, profileData),
                      const SizedBox(height: 12),
                      AccountXpCard(summary: profileData.xpSummary),
                      const SizedBox(height: 12),
                      RankHistoryCard(puuid: user.puuid),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.my_location, color: Colors.red),
                        label: Text(
                          l10n.manageLoadoutButton,
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoadoutMainScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.tealAccent.withValues(alpha: 0.15),
                              borderRadius: AppRadius.brM,
                            ),
                            child: const Icon(
                              Icons.diamond_outlined,
                              color: Colors.tealAccent,
                            ),
                          ),
                          title: Text(
                            l10n.collectionValueTileTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            l10n.collectionValueTileSubtitle,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const CollectionValueScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      /*
                      const SizedBox(height: 12),
                      Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.tealAccent.withValues(alpha: 0.15),
                              borderRadius: AppRadius.brM,
                            ),
                            child: const Icon(
                              Icons.bar_chart,
                              color: Colors.tealAccent,
                            ),
                          ),
                          title: Text(
                            l10n.careerStatsTileTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            l10n.careerStatsTileSubtitle,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CareerStatsScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      */
                      if (banWidget != null) ...[
                        const SizedBox(height: 20),
                        banWidget,
                      ],
                      const SizedBox(height: 20),
                      ProfileMatchHistoryTab(
                        puuid: user.puuid,
                        region: user.region,
                        accountId: user.gameName ?? '',
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: FunnyLoadingView()),
                error: (error, stack) => Center(child: Text("Error: $error")),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(RiotUser user, ProfileData profileData) {
    final l10n = AppLocalizations.of(context)!;
    final title =
        profileData.liveTitleId != null &&
            profileData.titles.containsKey(profileData.liveTitleId)
        ? profileData.titles[profileData.liveTitleId!]['titleText']
        : 'Title';

    final level =
        user.level ?? profileData.accountXp['Progress']?['Level'] ?? 0;

    final currentTierId = profileData.currentTier;
    final currentRR = profileData.currentRR;

    final currentTierData = profileData.competitiveTiers[currentTierId];
    final currentTierIcon = currentTierData?['largeIcon'];
    final currentTierName = currentTierData?['tierName'] ?? l10n.unranked;

    int peakTierId = 0;
    String peakSeason = 'ACT 1';
    if (profileData.henrikMmr != null) {
      final highestRank = profileData.henrikMmr!['highest_rank'];
      peakTierId = highestRank?['tier'] ?? 0;
      final seasonName = highestRank?['season']?.toString().toUpperCase();
      if (seasonName != null) {
        if (seasonName.startsWith('E') && seasonName.contains('A')) {
          final parts = seasonName.split('A');
          peakSeason = '${parts[0]} // ACT ${parts[1]}';
        } else {
          peakSeason = seasonName;
        }
      }
    }

    final peakTierData = profileData.competitiveTiers[peakTierId];
    final peakTierIcon = peakTierData?['largeIcon'];
    final peakTierName = peakTierData?['tierName'] ?? l10n.unranked;

    final rawCardId = user.playerCardId;
    final validCardId =
        (rawCardId != null &&
            rawCardId.isNotEmpty &&
            rawCardId != '00000000-0000-0000-0000-000000000000')
        ? rawCardId
        : '9fb3f4ab-4c11-1a3b-955e-5e9ad13289f3';

    final bannerUrl =
        'https://media.valorant-api.com/playercards/$validCardId/wideart.png';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      children: [
                        TextSpan(text: user.gameName ?? l10n.unknownItem),
                        TextSpan(
                          text: '#${user.tagline ?? '0000'}',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.7),
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  title.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Image.network(
                bannerUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: Icon(Icons.image, size: 50, color: Colors.grey),
                ),
              ),
              Positioned(
                bottom: -15,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer
                            .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary
                              .withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        l10n.playerLv(level),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildStatColumn(
                  topLabel: l10n.currentRankUpper,
                  iconWidget: currentTierIcon != null
                      ? CachedNetworkImage(
                          imageUrl: currentTierIcon,
                          width: 80,
                          height: 80,
                          cacheManager:
                              CustomCacheManagers.tierImageCacheManager,
                          errorWidget: (context, url, error) => const Icon(
                            Icons.security,
                            size: 80,
                            color: Colors.grey,
                          ),
                        )
                      : const Icon(
                          Icons.security,
                          size: 80,
                          color: Colors.grey,
                        ),
                  rankName: currentTierName,
                  bottomLabel: l10n.rrSuffix(currentRR),
                ),

                _buildStatColumn(
                  topLabel: peakSeason,
                  iconWidget: peakTierIcon != null
                      ? CachedNetworkImage(
                          imageUrl: peakTierIcon,
                          width: 80,
                          height: 80,
                          cacheManager:
                              CustomCacheManagers.tierImageCacheManager,
                          errorWidget: (context, url, error) => const Icon(
                            Icons.emoji_events,
                            size: 80,
                            color: Colors.grey,
                          ),
                        )
                      : const Icon(
                          Icons.emoji_events,
                          size: 80,
                          color: Colors.grey,
                        ),
                  rankName: peakTierName,
                  bottomLabel: l10n.lifetimePeak,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn({
    required String topLabel,
    required Widget iconWidget,
    required String rankName,
    required String bottomLabel,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            topLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          iconWidget,
          const SizedBox(height: 12),
          Text(
            rankName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFFB54545),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            bottomLabel,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget? _buildBanWarningCard(
    ProfileData profileData,
    bool isDark,
    DisplaySettings displaySettings,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final penaltiesMap = profileData.penalties;
    if (penaltiesMap == null || penaltiesMap['Penalties'] == null) {
      return null;
    }

    final List rawPenalties = penaltiesMap['Penalties'];
    if (rawPenalties.isEmpty) {
      return null;
    }

    final activeBans = <Widget>[];

    for (final item in rawPenalties) {
      if (item is! Map) continue;

      final expiryStr =
          item['Expiry'] ??
          item['expiry'] ??
          item['ExpiryTime'] ??
          item['expiryTime'] ??
          item['ExpirationTime'] ??
          item['expirationTime'];
      if (expiryStr == null) continue;

      final expiry = DateTime.tryParse(expiryStr.toString());
      if (expiry == null) continue;

      if (expiry.isBefore(DateTime.now())) continue;

      final durationVal =
          item['Duration'] ??
          item['duration'] ??
          item['DurationDecay'] ??
          item['durationDecay'] ??
          0;
      final int durationSeconds = int.tryParse(durationVal.toString()) ?? 0;

      final start = durationSeconds > 0
          ? expiry.subtract(Duration(seconds: durationSeconds))
          : null;

      final type =
          item['PenaltyType'] ??
          item['penaltyType'] ??
          item['Type'] ??
          item['type'] ??
          'Restriction';

      final String prettyType;
      if (type.toString().toUpperCase().contains('COMPETITIVE')) {
        prettyType = l10n.competitiveQueueBan;
      } else if (type.toString().toUpperCase().contains('QUEUE')) {
        prettyType = l10n.matchmakingQueueBan;
      } else if (type.toString().toUpperCase().contains('CHAT') ||
          type.toString().toUpperCase().contains('COMM')) {
        prettyType = l10n.communicationRestriction;
      } else {
        prettyType = l10n.accountRestriction(type.toString());
      }

      final remaining = expiry.difference(DateTime.now());
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes % 60;
      final String remainingText = hours > 0
          ? l10n.hoursAndMinutes(hours, minutes)
          : l10n.minutesOnly(minutes);

      activeBans.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFF4655).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFF4655), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.gavel, color: Color(0xFFFF4655), size: 24),
                  const SizedBox(width: 12),
                  Text(
                    prettyType,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF4655),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (start != null) ...[
                Text(
                  l10n.startedPrefix(
                    FormatUtils.formatDateTime(start, displaySettings),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                l10n.expiresPrefix(
                  FormatUtils.formatDateTime(expiry, displaySettings),
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.remainingTimePrefix(remainingText),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF4655),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (activeBans.isEmpty) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: activeBans,
    );
  }
}
