import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:valorant_thunai/models/xmpp_models.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/providers/xmpp_provider.dart';
import 'package:valorant_thunai/providers/rank_goal_provider.dart';
import 'package:valorant_thunai/screens/profile/rank_goal_screen.dart';
import 'package:valorant_thunai/screens/profile/widgets/rank_goal_summary_card.dart';
import 'package:valorant_thunai/screens/profile/contracts_screen.dart';
import 'package:valorant_thunai/screens/profile/leaderboard_screen.dart';
import 'package:valorant_thunai/screens/social/friends_screen.dart';
import 'package:valorant_thunai/theme/app_theme.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class HubPage extends ConsumerWidget {
  const HubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.tabHub)),
        body: Center(child: Text(l10n.notLoggedIn)),
      );
    }

    Widget tile({
      required IconData icon,
      required Color iconColor,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: AppRadius.brM,
            ),
            child: Icon(icon, color: iconColor),
          ),
          title: Text(title, style: theme.textTheme.titleMedium),
          subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabHub)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            if (ref.watch(rankGoalProvider).value != null)
              const RankGoalSummaryCard()
            else
              tile(
                icon: Icons.trending_up,
                iconColor: Colors.blueAccent,
                title: l10n.rankGoalsTileTitle,
                subtitle: l10n.rankGoalsTileSubtitle,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RankGoalScreen(),
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
            tile(
              icon: Icons.assignment,
              iconColor: Colors.orangeAccent,
              title: l10n.contractsMissionsTitle,
              subtitle: l10n.contractsTileSubtitle,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ContractsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            const _FriendsInGameDigestCard(),
            const SizedBox(height: 12),
            tile(
              icon: Icons.people_alt,
              iconColor: Colors.greenAccent,
              title: l10n.friendsTitle,
              subtitle: l10n.friendsOptionSubtitle,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FriendsPage()),
                );
              },
            ),
            const SizedBox(height: 12),
            tile(
              icon: Icons.leaderboard,
              iconColor: Colors.purpleAccent,
              title: l10n.leaderboardTileTitle,
              subtitle: l10n.leaderboardTileSubtitle,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LeaderboardScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendsInGameDigestCard extends ConsumerWidget {
  const _FriendsInGameDigestCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final xmppState = ref.watch(xmppProvider);

    final inGameFriends =
        xmppState.friendPresences.values
            .where(
              (fp) =>
                  fp.isOnline &&
                  fp.isValorant &&
                  (fp.sessionLoop == 'INGAME' || fp.sessionLoop == 'PREGAME'),
            )
            .toList()
          ..sort(
            (a, b) => (a.gameName ?? '').toLowerCase().compareTo(
              (b.gameName ?? '').toLowerCase(),
            ),
          );

    if (inGameFriends.isEmpty) {
      return const SizedBox.shrink();
    }

    const maxShown = 3;
    final shown = inGameFriends.take(maxShown).toList();
    final overflow = inGameFriends.length - shown.length;

    String friendLabel(FriendPresence fp) {
      final name = (fp.gameName == null || fp.gameName!.isEmpty)
          ? fp.puuid
          : fp.gameName!;
      return fp.sessionLoop == 'PREGAME' ? '$name (Agent Select)' : name;
    }

    return Card(
      child: InkWell(
        borderRadius: AppRadius.brXl,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FriendsPage()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sports_esports,
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.friendsInGameDigestTitle,
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.friendsInGameDigestCount(inGameFriends.length),
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      overflow > 0
                          ? '${shown.map(friendLabel).join(', ')}, ${l10n.friendsInGameDigestMore(overflow)}'
                          : shown.map(friendLabel).join(', '),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
