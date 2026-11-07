import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/services/riot_local_service.dart';
import 'package:valorant_thunai/services/logger_service.dart';
import 'package:valorant_thunai/services/valorant_api.dart';
import 'package:valorant_thunai/services/friend_name_cache_service.dart';

import 'auth_provider.dart';

class Friend {
  final String puuid;
  final String name;
  final String tagline;
  final String note;
  final String group;
  final String displayGroup;
  final int? lastOnlineTs;
  final bool isOnline;
  final String? activePlatform;
  final String agentIconUrl;

  Friend({
    required this.puuid,
    required this.name,
    required this.tagline,
    required this.note,
    required this.group,
    required this.displayGroup,
    this.lastOnlineTs,
    required this.isOnline,
    this.activePlatform,
    required this.agentIconUrl,
  });
}

class FriendPartyMember {
  final String name;
  final String tagline;
  final String statusText;
  final String subStatusText;
  final String agentIconUrl;
  final String? rankIconUrl;
  final String? note;

  FriendPartyMember({
    required this.name,
    required this.tagline,
    required this.statusText,
    required this.subStatusText,
    required this.agentIconUrl,
    this.rankIconUrl,
    this.note,
  });
}

class FriendParty {
  final String title;
  final List<FriendPartyMember> members;
  final int totalSize;

  FriendParty({
    required this.title,
    required this.members,
    required this.totalSize,
  });
}

class FriendsData {
  final List<FriendParty> parties;
  final List<Friend> offlineFriends;
  final List<Friend> onlineFriends;

  FriendsData({
    required this.parties,
    required this.offlineFriends,
    required this.onlineFriends,
  });
}

final friendsProvider = FutureProvider<FriendsData>((ref) async {
  final localService = ref.read(riotLocalServiceProvider);

  try {
    final lockfile = await localService.getLockfile();
    if (lockfile != null) {
      final rawFriends = await localService.getFriends(lockfile);

      final List<Friend> online = [];
      final List<Friend> offline = [];

      for (var f in rawFriends) {
        final String puuid = f['puuid'] ?? '';
        final String gameName = f['game_name'] ?? f['name'] ?? 'Unknown';
        final String gameTag = f['game_tag'] ?? '';
        final String note = f['note'] ?? '';
        final String group = f['group'] ?? '';
        final String displayGroup = f['displayGroup'] ?? '';
        final String? activePlatform = f['activePlatform'];
        final int? lastOnlineTs = f['last_online_ts'];

        final bool isOnline = activePlatform != null;

        final List<String> agents = [
          'add64435-ae81-439b-1615-51d6506c47e6',
          'a3dead5e-4b47-497d-92ec-a0680f425b0e',
          'ade2b615-47db-330c-e346-ae877947466e',
          '117ed9e3-49f3-6512-3ccf-00ad78bb7d80',
        ];
        final agentId = agents[gameName.hashCode % agents.length];
        final agentIconUrl =
            'https://media.valorant-api.com/agents/$agentId/displayicon.png';

        final friend = Friend(
          puuid: puuid,
          name: gameName,
          tagline: gameTag,
          note: note,
          group: group,
          displayGroup: displayGroup,
          lastOnlineTs: lastOnlineTs,
          isOnline: isOnline,
          activePlatform: activePlatform,
          agentIconUrl: agentIconUrl,
        );

        if (isOnline) {
          online.add(friend);
        } else {
          offline.add(friend);
        }
      }

      final currentUser = ref.read(authProvider).user;
      final String myName = currentUser?.gameName ?? 'Player';
      final String myTag = currentUser?.tagline ?? '';

      final List<FriendParty> parties = [
        FriendParty(
          title: 'Your Party — 1/5',
          members: [
            FriendPartyMember(
              name: myName,
              tagline: myTag,
              statusText: 'Online',
              subStatusText: 'ValShop Mobile',
              agentIconUrl: 'https://media.valorant-api.com/agents/add64435-ae81-439b-1615-51d6506c47e6/displayicon.png',
            ),
          ],
          totalSize: 5,
        ),
      ];

      return FriendsData(
        parties: parties,
        offlineFriends: offline,
        onlineFriends: online,
      );
    }
  } catch (e) {
    LoggerService.log(
      'Failed to fetch local friends list: $e',
      tag: 'FriendsProvider',
    );
  }

  final authState = ref.read(authProvider);
  final currentUser = authState.user;
  List<FriendParty> remoteParties = [];

  if (currentUser != null &&
      currentUser.puuid.isNotEmpty &&
      !authState.hasSessionExpired) {
    final String token = currentUser.accessToken;
    final String ent = currentUser.entitlementsToken;

    if (token.isNotEmpty && ent.isNotEmpty) {
      try {
        final api = ref.read(valorantApiProvider);
        final partyJson = await api.fetchPlayerParty(
          currentUser.puuid,
          currentUser.region,
          token,
          ent,
        );

        if (partyJson != null && partyJson['Members'] != null) {
          final List<dynamic> membersJson = partyJson['Members'];
          final List<String> puuids = membersJson
              .map((m) => (m['Subject'] ?? m['puuid'] ?? '').toString())
              .where((p) => p.isNotEmpty)
              .toList();

          final Map<String, Map<String, String>> names = await api
              .fetchNamesByPuuids(puuids, currentUser.region, token, ent);

          final String myGameName = currentUser.gameName ?? 'Player';
          final String myTagline = currentUser.tagline ?? '';

          final List<FriendPartyMember> partyMembers = [];
          for (final m in membersJson) {
            final pPuuid = (m['Subject'] ?? m['puuid'] ?? '').toString();
            final nameData = names[pPuuid];
            final String name =
                nameData?['gameName'] ??
                (pPuuid == currentUser.puuid
                    ? myGameName
                    : 'Player ${pPuuid.length >= 4 ? pPuuid.substring(0, 4) : pPuuid}');
            final String tag =
                nameData?['tagline'] ??
                (pPuuid == currentUser.puuid ? myTagline : '');

            partyMembers.add(
              FriendPartyMember(
                name: name,
                tagline: tag,
                statusText: 'Online',
                subStatusText: pPuuid == currentUser.puuid
                    ? 'ValShop Mobile'
                    : 'Party Member',
                agentIconUrl: 'https://media.valorant-api.com/agents/add64435-ae81-439b-1615-51d6506c47e6/displayicon.png',
              ),
            );
          }

          if (partyMembers.isNotEmpty) {
            remoteParties.add(
              FriendParty(
                title: 'Your Party — ${partyMembers.length}/5',
                members: partyMembers,
                totalSize: 5,
              ),
            );
          }
        }
      } catch (e) {
        LoggerService.log(
          'Error fetching remote party: $e',
          tag: 'FriendsProvider',
        );
      }
    }
  }

  if (remoteParties.isEmpty && currentUser != null) {
    remoteParties.add(
      FriendParty(
        title: 'Your Party — 1/5',
        members: [
          FriendPartyMember(
            name: currentUser.gameName ?? 'Player',
            tagline: currentUser.tagline ?? '',
            statusText: 'Online',
            subStatusText: 'ValShop Mobile',
            agentIconUrl: 'https://media.valorant-api.com/agents/add64435-ae81-439b-1615-51d6506c47e6/displayicon.png',
          ),
        ],
        totalSize: 5,
      ),
    );
  }

  return FriendsData(
    parties: remoteParties,
    offlineFriends: [],
    onlineFriends: [],
  );
});

final friendNameHistoryProvider =
    FutureProvider<Map<String, List<FriendNameChange>>>((ref) async {
      final data = await ref.watch(friendsProvider.future);
      final Map<String, List<FriendNameChange>> result = {};

      final allFriends = [...data.onlineFriends, ...data.offlineFriends];
      for (final f in allFriends) {
        if (f.puuid.isEmpty || f.name.isEmpty) continue;
        try {
          final history = await FriendNameCacheService.resolve(
            f.puuid,
            f.name,
            f.tagline,
          );
          if (history.isNotEmpty) {
            result[f.puuid] = history;
          }
        } catch (e) {
          LoggerService.log(
            'Failed to resolve name history for ${f.puuid}: $e',
            tag: 'FriendNameHistory',
          );
        }
      }

      return result;
    });

final addFriendProvider = NotifierProvider<AddFriendNotifier, AsyncValue<void>>(
  AddFriendNotifier.new,
);

class AddFriendNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> sendRequest(String name, String tag) async {
    state = const AsyncValue.loading();
    try {
      final localService = ref.read(riotLocalServiceProvider);
      final lockfile = await localService.getLockfile();

      if (lockfile == null) {
        LoggerService.log(
          'Simulating friend request to $name#$tag (lockfile not found/non-Windows).',
          tag: 'AddFriendNotifier',
        );
        await Future.delayed(const Duration(seconds: 1));
        state = const AsyncValue.data(null);
        return;
      }

      await localService.addFriend(lockfile, name, tag);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      LoggerService.log(
        'Error sending friend request: $e',
        tag: 'AddFriendNotifier',
      );
      state = AsyncValue.error(e, stack);
    }
  }
}
