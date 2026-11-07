import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/models/xmpp_models.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/providers/friends_provider.dart';
import 'package:valorant_thunai/providers/profile_provider.dart';
import 'package:valorant_thunai/providers/xmpp_provider.dart';
import 'package:valorant_thunai/services/friend_name_cache_service.dart';
import 'package:valorant_thunai/screens/social/social_chat_screen.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

const List<String> _fallbackAgentIds = [
  'add64435-ae81-439b-1615-51d6506c47e6',
  'a3dead5e-4b47-497d-92ec-a0680f425b0e',
  'ade2b615-47db-330c-e346-ae877947466e',
  '117ed9e3-49f3-6512-3ccf-00ad78bb7d80',
];

String _fallbackAgentIconFor(String? name) {
  final agentId =
      _fallbackAgentIds[(name ?? '').hashCode % _fallbackAgentIds.length];
  return 'https://media.valorant-api.com/agents/$agentId/displayicon.png';
}

const ColorFilter _greyscaleFilter = ColorFilter.matrix(<double>[
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);

String _formatLastSeen(BuildContext context, int? lastSeenMs) {
  final l10n = AppLocalizations.of(context)!;
  if (lastSeenMs == null) return l10n.offlineStatusText;
  final diff = DateTime.now().millisecondsSinceEpoch - lastSeenMs;
  if (diff < 0) return l10n.justNow;

  final minutes = (diff / 60000).floor();
  if (minutes < 1) return l10n.justNow;
  if (minutes < 60) return l10n.lastOnlineMinutesAgo(minutes);

  final hours = (minutes / 60).floor();
  final remainingMinutes = minutes % 60;

  if (hours < 24) {
    if (remainingMinutes == 0) {
      return l10n.lastOnlineHoursAgo(hours, hours == 1 ? 'hour' : 'hours');
    }
    return l10n.lastOnlineHoursMinutesAgo(
      hours,
      hours == 1 ? 'hour' : 'hours',
      remainingMinutes,
      remainingMinutes == 1 ? 'minute' : 'minutes',
    );
  }

  final days = (hours / 24).floor();
  final remainingHours = hours % 24;

  if (days == 1) {
    if (remainingHours == 0) return l10n.lastOnlineOneDayAgo;
    return l10n.lastOnlineDaysMinutesAgo(
      1,
      remainingMinutes,
      remainingMinutes == 1 ? 'minute' : 'minutes',
    );
  }

  if (remainingHours == 0) return l10n.lastOnlineDaysAgo(days);
  return l10n.lastOnlineDaysHoursAgo(
    days,
    remainingHours,
    remainingHours == 1 ? 'hour' : 'hours',
  );
}

class FriendsPage extends ConsumerStatefulWidget {
  const FriendsPage({super.key});

  @override
  ConsumerState<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends ConsumerState<FriendsPage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoConnectXmpp();
    });
  }

  Future<void> _autoConnectXmpp() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final xmppState = ref.read(xmppProvider);
    if (!xmppState.isConnected || xmppState.connectedPuuid != user.puuid) {
      await ref.read(xmppProvider.notifier).connect(user);
    }
    await ref.read(xmppProvider.notifier).resolveAllFriendNames();
    if (mounted) {
      ref.invalidate(friendsProvider);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddFriendDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final tagController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return Consumer(
          builder: (context, ref, child) {
            final addFriendState = ref.watch(addFriendProvider);

            ref.listen<AsyncValue<void>>(addFriendProvider, (prev, next) {
              if (next is AsyncData) {
                Navigator.of(context).pop();
                ref.invalidate(friendsProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.friendRequestSentSnackbar)),
                );
              } else if (next is AsyncError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.errorMessage(next.error.toString())),
                  ),
                );
              }
            });

            return Dialog(
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.addFriendDialogTitle,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.addFriendDialogDescription,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: nameController,
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: l10n.nameFieldHint,
                                hintStyle: GoogleFonts.inter(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? l10n.requiredValidator
                                  : null,
                            ),
                            Divider(
                              height: 1,
                              color: theme.colorScheme.outlineVariant,
                            ),
                            TextFormField(
                              controller: tagController,
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: l10n.tagFieldHint,
                                hintStyle: GoogleFonts.inter(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? l10n.requiredValidator
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: addFriendState.isLoading
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: Text(
                                l10n.cancel,
                                style: GoogleFonts.inter(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextButton(
                              onPressed: addFriendState.isLoading
                                  ? null
                                  : () {
                                      if (formKey.currentState!.validate()) {
                                        ref
                                            .read(addFriendProvider.notifier)
                                            .sendRequest(
                                              nameController.text.trim(),
                                              tagController.text.trim(),
                                            );
                                      }
                                    },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: addFriendState.isLoading
                                  ? SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: FunnyLoadingView(
                                        color: theme
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                    )
                                  : Text(
                                      l10n.sendRequestButton,
                                      style: GoogleFonts.inter(
                                        color: theme
                                            .colorScheme
                                            .onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openChat(FriendPresence friend) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SocialChatScreen(
          initialRecipientPuuid: friend.puuid,
          initialRecipientName: '${friend.gameName}#${friend.tagline}',
        ),
      ),
    );
  }

  Widget _buildFriendTile(
    BuildContext context,
    FriendPresence friend, {
    required bool isOffline,
    Map<int, dynamic> tiersData = const {},
    int? lastSeenMs,
    List<FriendNameChange> nameHistory = const [],
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    const zeroUuid = '00000000-0000-0000-0000-000000000000';
    final cardId = friend.playerCardId;
    final avatarUrl =
        (cardId != null && cardId.isNotEmpty && cardId != zeroUuid)
        ? 'https://media.valorant-api.com/playercards/$cardId/displayicon.png'
        : _fallbackAgentIconFor(friend.gameName);
    final tier = int.tryParse(friend.competitiveTier ?? '');
    final tierIcon = friend.isValorant && tier != null
        ? (tiersData[tier]?['largeIcon'] as String?)
        : null;

    final Color dotColor = isOffline
        ? theme.colorScheme.outline
        : friend.sessionLoop == 'INGAME'
        ? Colors.redAccent
        : Colors.greenAccent;
    final Color statusColor = isOffline
        ? theme.colorScheme.onSurfaceVariant
        : friend.sessionLoop == 'INGAME'
        ? Colors.redAccent
        : Colors.greenAccent;

    Widget avatar = ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatarUrl,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 52,
          height: 52,
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        errorWidget: (context, url, error) => Container(
          width: 52,
          height: 52,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(Icons.person, color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
    if (isOffline) {
      avatar = ColorFiltered(colorFilter: _greyscaleFilter, child: avatar);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openChat(friend),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                avatar,
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: friend.gameName,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if ((friend.tagline ?? '').isNotEmpty)
                          TextSpan(
                            text: '#${friend.tagline}',
                            style: GoogleFonts.inter(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOffline
                        ? _formatLastSeen(context, lastSeenMs)
                        : friend.formattedStatus,
                    style: GoogleFonts.inter(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isOffline && friend.formattedSubStatus.isNotEmpty)
                    Text(
                      friend.formattedSubStatus,
                      style: GoogleFonts.inter(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if ((friend.statusMessage ?? '').isNotEmpty &&
                      friend.statusMessage != 'Online' &&
                      friend.statusMessage != 'Offline') ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.format_quote_rounded,
                          size: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            friend.statusMessage!,
                            style: GoogleFonts.inter(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if ((friend.savedNote ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.sticky_note_2_outlined,
                          size: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            friend.savedNote!,
                            style: GoogleFonts.inter(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (nameHistory.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      l10n.formerlyKnownAs(
                        '${nameHistory.first.gameName}#${nameHistory.first.tagline}',
                      ),
                      style: GoogleFonts.inter(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (tierIcon != null) ...[
              CachedNetworkImage(
                imageUrl: tierIcon,
                width: 30,
                height: 30,
                fit: BoxFit.contain,
                errorWidget: (context, url, error) => const SizedBox(),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              isOffline ? Icons.chevron_right : Icons.chat_bubble_outline,
              color: isOffline
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.primary,
              size: isOffline ? 20 : 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<FriendPresence> friends,
    required bool isOffline,
    Map<int, dynamic> tiersData = const {},
    Map<String, int> lastSeenTimestamps = const {},
    Map<String, List<FriendNameChange>> nameHistory = const {},
  }) {
    if (friends.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 10.0),
            child: Text(
              title,
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < friends.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: theme.colorScheme.outlineVariant,
                    ),
                  _buildFriendTile(
                    context,
                    friends[i],
                    isOffline: isOffline,
                    tiersData: tiersData,
                    lastSeenMs: lastSeenTimestamps[friends[i].puuid],
                    nameHistory: nameHistory[friends[i].puuid] ?? const [],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final friendsAsync = ref.watch(friendsProvider);
    final xmppState = ref.watch(xmppProvider);
    final tiersData = ref.watch(competitiveTiersProvider).value ?? const {};
    final Map<String, List<FriendNameChange>> nameHistory =
        ref.watch(friendNameHistoryProvider).value ?? {};

    ref.listen<String?>(authProvider.select((s) => s.user?.puuid), (
      previous,
      next,
    ) {
      if (previous != null && next != null && previous != next) {
        _autoConnectXmpp();
      }
    });

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          l10n.friendsTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: l10n.addFriendDialogTitle,
            onPressed: () => _showAddFriendDialog(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: friendsAsync.when(
        loading: () => const Center(child: FunnyLoadingView(color: Colors.red)),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.errorLoadingFriends(err.toString())),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(friendsProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (data) {
          final Map<String, FriendPresence> merged = {};

          for (final f in data.offlineFriends) {
            merged[f.puuid] = FriendPresence(
              puuid: f.puuid,
              jid: '',
              show: 'offline',
              isOnline: false,
              gameName: f.name,
              tagline: f.tagline,
              statusMessage: f.note,
            );
          }
          for (final f in data.onlineFriends) {
            merged[f.puuid] = FriendPresence(
              puuid: f.puuid,
              jid: '',
              show: 'chat',
              isOnline: true,
              gameName: f.name,
              tagline: f.tagline,
              statusMessage: f.note,
            );
          }
          for (final fp in xmppState.friendPresences.values) {
            merged[fp.puuid] = fp;
          }

          int byName(FriendPresence a, FriendPresence b) => (a.gameName ?? '')
              .toLowerCase()
              .compareTo((b.gameName ?? '').toLowerCase());

          final onlineList = merged.values.where((fp) => fp.isOnline).toList()
            ..sort(byName);
          final offlineList = merged.values.where((fp) => !fp.isOnline).toList()
            ..sort(byName);

          bool matchesSearch(FriendPresence fp) {
            if (_searchQuery.isEmpty) return true;
            final fullName = '${fp.gameName}#${fp.tagline}'.toLowerCase();
            return fullName.contains(_searchQuery.toLowerCase());
          }

          final onlineValorant = onlineList
              .where((f) => f.isValorant && matchesSearch(f))
              .toList();
          final onlineRiotClient = onlineList
              .where((f) => !f.isValorant && matchesSearch(f))
              .toList();
          final filteredOffline = offlineList.where(matchesSearch).toList();

          final filteredParties = data.parties.where((p) {
            if (_searchQuery.isEmpty) return true;
            return p.members.any(
              (m) => '${m.name}#${m.tagline}'.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ),
            );
          }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              await _autoConnectXmpp();
              ref.invalidate(friendsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.inter(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.searchFriendsHint,
                      hintStyle: GoogleFonts.inter(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                ...filteredParties.map((party) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 8.0,
                            bottom: 10.0,
                          ),
                          child: Text(
                            party.title,
                            style: GoogleFonts.inter(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Card(
                          elevation: 0,
                          color: theme.colorScheme.surfaceContainerHigh,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final member in party.members) ...[
                                  Row(
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          ClipOval(
                                            child: CachedNetworkImage(
                                              imageUrl: member.agentIconUrl,
                                              width: 52,
                                              height: 52,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                                  Container(
                                                    width: 52,
                                                    height: 52,
                                                    color: theme
                                                        .colorScheme
                                                        .surfaceContainerHighest,
                                                  ),
                                              errorWidget:
                                                  (
                                                    context,
                                                    url,
                                                    error,
                                                  ) => Container(
                                                    width: 52,
                                                    height: 52,
                                                    color: theme
                                                        .colorScheme
                                                        .surfaceContainerHighest,
                                                    child: Icon(
                                                      Icons.person,
                                                      color: theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: -2,
                                            right: -2,
                                            child: Container(
                                              width: 16,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: theme
                                                    .colorScheme
                                                    .surfaceContainerHigh,
                                                shape: BoxShape.circle,
                                              ),
                                              padding: const EdgeInsets.all(
                                                2.0,
                                              ),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color:
                                                      member.statusText ==
                                                          'Online'
                                                      ? Colors.greenAccent
                                                      : Colors.redAccent,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: member.name,
                                                    style: GoogleFonts.inter(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color: theme
                                                          .colorScheme
                                                          .onSurface,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: '#${member.tagline}',
                                                    style: GoogleFonts.inter(
                                                      color: theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              [
                                                member.statusText,
                                                if (member
                                                    .subStatusText
                                                    .isNotEmpty)
                                                  member.subStatusText,
                                              ].join(' • '),
                                              style: GoogleFonts.inter(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if ((member.note ?? '').isNotEmpty)
                                              Text(
                                                member.note!,
                                                style: GoogleFonts.inter(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                  fontSize: 12,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (member.rankIconUrl != null)
                                        CachedNetworkImage(
                                          imageUrl: member.rankIconUrl!,
                                          width: 30,
                                          height: 30,
                                          fit: BoxFit.contain,
                                          errorWidget: (context, url, error) =>
                                              const SizedBox(),
                                        ),
                                    ],
                                  ),
                                  if (member != party.members.last)
                                    const Divider(height: 20),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                _buildSection(
                  context,
                  title: l10n.inValorantHeader(onlineValorant.length),
                  friends: onlineValorant,
                  isOffline: false,
                  tiersData: tiersData,
                  nameHistory: nameHistory,
                ),
                _buildSection(
                  context,
                  title: l10n.riotClientHeader(onlineRiotClient.length),
                  friends: onlineRiotClient,
                  isOffline: false,
                  nameHistory: nameHistory,
                ),
                _buildSection(
                  context,
                  title: l10n.offlineFriendsHeader(filteredOffline.length),
                  friends: filteredOffline,
                  isOffline: true,
                  lastSeenTimestamps: xmppState.lastSeenTimestamps,
                  nameHistory: nameHistory,
                ),

                if (filteredParties.isEmpty &&
                    onlineValorant.isEmpty &&
                    onlineRiotClient.isEmpty &&
                    filteredOffline.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: Text(
                        l10n.noFriendsFound,
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
