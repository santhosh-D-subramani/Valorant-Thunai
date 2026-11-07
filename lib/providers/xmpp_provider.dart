import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_thunai/models/xmpp_models.dart';
import 'package:valorant_thunai/services/riot_auth_service.dart';
import 'package:valorant_thunai/services/riot_xmpp_service.dart';
import 'package:valorant_thunai/services/valorant_api.dart';
import 'package:valorant_thunai/services/logger_service.dart';

import 'auth_provider.dart';

class XmppState {
  final bool isConnected;
  final String status;
  final Map<String, FriendPresence> friendPresences;
  final Map<String, List<ChatMessage>> conversations;
  final String? connectedPuuid;
  final Map<String, int> lastSeenTimestamps;

  XmppState({
    required this.isConnected,
    required this.status,
    required this.friendPresences,
    required this.conversations,
    this.connectedPuuid,
    this.lastSeenTimestamps = const {},
  });

  factory XmppState.initial() => XmppState(
    isConnected: false,
    status: 'Disconnected',
    friendPresences: {},
    conversations: {},
  );

  XmppState copyWith({
    bool? isConnected,
    String? status,
    Map<String, FriendPresence>? friendPresences,
    Map<String, List<ChatMessage>>? conversations,
    String? connectedPuuid,
    Map<String, int>? lastSeenTimestamps,
  }) {
    return XmppState(
      isConnected: isConnected ?? this.isConnected,
      status: status ?? this.status,
      friendPresences: friendPresences ?? this.friendPresences,
      conversations: conversations ?? this.conversations,
      connectedPuuid: connectedPuuid ?? this.connectedPuuid,
      lastSeenTimestamps: lastSeenTimestamps ?? this.lastSeenTimestamps,
    );
  }
}

class XmppNotifier extends Notifier<XmppState> {
  static const String _lastSeenPrefsKey = 'xmpp_last_seen_v1';

  late final RiotXmppService _xmppService;
  late final RiotAuthService _authService;

  @override
  XmppState build() {
    _xmppService = ref.watch(xmppServiceProvider);
    _authService = ref.watch(riotAuthServiceProvider);

    _loadLastSeen();

    _xmppService.onConnectionStatusChanged = (connected, status) {
      state = state.copyWith(isConnected: connected, status: status);
    };

    _xmppService.onPresenceUpdated = (presence) {
      final updatedPresences = Map<String, FriendPresence>.from(
        state.friendPresences,
      );
      final existing = updatedPresences[presence.puuid];

      FriendPresence finalPresence = presence;
      if (existing != null &&
          existing.gameName != null &&
          !existing.gameName!.startsWith('Player ')) {
        finalPresence = presence.copyWith(
          gameName: existing.gameName,
          tagline: existing.tagline,
        );
      }
      if (finalPresence.savedNote == null && existing?.savedNote != null) {
        finalPresence = finalPresence.copyWith(savedNote: existing!.savedNote);
      }

      if ((existing?.isOnline ?? false) && !finalPresence.isOnline) {
        _recordLastSeen(presence.puuid);
      }

      updatedPresences[presence.puuid] = finalPresence;
      state = state.copyWith(friendPresences: updatedPresences);

      if (finalPresence.gameName == null ||
          finalPresence.gameName!.startsWith('Player ')) {
        _resolveFriendName(presence.puuid);
      }
    };

    _xmppService.onMessageReceived = (message) {
      final targetKey = message.isMe
          ? message.toJid.split('@').first
          : message.fromPuuid;

      final updatedConversations = Map<String, List<ChatMessage>>.from(
        state.conversations,
      );
      final currentList = updatedConversations[targetKey] ?? [];

      final isDuplicate = currentList.any(
        (m) =>
            m.isMe == message.isMe &&
            m.body == message.body &&
            m.timestamp.difference(message.timestamp).inSeconds.abs() < 3,
      );
      if (isDuplicate) return;

      updatedConversations[targetKey] = [...currentList, message];
      state = state.copyWith(conversations: updatedConversations);
    };

    ref.onDispose(() {
      _xmppService.disconnect();
    });

    return XmppState.initial();
  }

  Future<bool> connect(RiotUser user) async {
    if (state.connectedPuuid != null && state.connectedPuuid != user.puuid) {
      state = state.copyWith(
        friendPresences: {},
        conversations: {},
        isConnected: false,
      );
    }

    String? pasToken = user.pasToken;
    if (pasToken == null || pasToken.isEmpty) {
      pasToken = await _authService.fetchPasToken(user.accessToken);
    }

    if (pasToken == null) {
      LoggerService.log(
        'Cannot connect XMPP: Failed to retrieve PAS Token',
        tag: 'XmppNotifier',
      );
      state = state.copyWith(status: 'Failed to retrieve PAS Token');
      return false;
    }

    String? customHost;
    int? customPort;
    try {
      final config = await RiotAuthService.fetchChatConfig(
        user.accessToken,
        user.entitlementsToken,
      );
      if (config != null) {
        final affinities = config['chat.affinities'] as Map<String, dynamic>?;
        customHost =
            affinities?[user.region] ??
            affinities?['asia'] ??
            affinities?['ap'] ??
            config['chat.host'];
        customPort = config['chat.port'] as int?;
        LoggerService.log(
          'Fetched Chat Host from Config: $customHost:$customPort',
          tag: 'XmppNotifier',
        );
      }
    } catch (e) {
      LoggerService.log(
        'Error fetching Client Config for XMPP: $e',
        tag: 'XmppNotifier',
      );
    }

    final success = await _xmppService.connect(
      accessToken: user.accessToken,
      pasToken: pasToken,
      affinity: user.region,
      puuid: user.puuid,
      customHost: customHost,
      customPort: customPort,
    );

    if (success) {
      state = state.copyWith(connectedPuuid: user.puuid);
    }

    return success;
  }

  void sendMessage(String recipientPuuid, String text) {
    _xmppService.sendChatMessage(recipientPuuid, text);
  }

  void setPresenceStatus(String show, {String? statusMsg}) {
    _xmppService.sendPresenceStatus(show: show, statusMsg: statusMsg);
  }

  void disconnect() {
    _xmppService.disconnect();
  }

  Future<void> _loadLastSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_lastSeenPrefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final loaded = decoded.map((k, v) => MapEntry(k, v as int));
      if (loaded.isNotEmpty) {
        state = state.copyWith(lastSeenTimestamps: loaded);
      }
    } catch (e) {
      LoggerService.log(
        'Failed to load last-seen cache: $e',
        tag: 'XmppNotifier',
      );
    }
  }

  Future<void> _recordLastSeen(String puuid) async {
    final updated = Map<String, int>.from(state.lastSeenTimestamps);
    updated[puuid] = DateTime.now().millisecondsSinceEpoch;
    state = state.copyWith(lastSeenTimestamps: updated);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSeenPrefsKey, jsonEncode(updated));
    } catch (e) {
      LoggerService.log(
        'Failed to persist last-seen cache: $e',
        tag: 'XmppNotifier',
      );
    }
  }

  Future<void> resolveAllFriendNames() async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null || authState.hasSessionExpired) return;
    final puuidsToResolve = state.friendPresences.values
        .where((f) => f.gameName == null || f.gameName!.startsWith('Player '))
        .map((f) => f.puuid)
        .toList();
    if (puuidsToResolve.isEmpty) return;

    try {
      final api = ref.read(valorantApiProvider);
      final names = await api.fetchNamesByPuuids(
        puuidsToResolve,
        user.region,
        user.accessToken,
        user.entitlementsToken,
      );
      if (names.isNotEmpty) {
        final updated = Map<String, FriendPresence>.from(state.friendPresences);
        names.forEach((puuid, info) {
          final gName = info['gameName'] ?? '';
          final tLine = info['tagline'] ?? '';
          final current = updated[puuid];
          if (current != null && gName.isNotEmpty) {
            updated[puuid] = current.copyWith(gameName: gName, tagline: tLine);
          }
        });
        state = state.copyWith(friendPresences: updated);
      }
    } catch (e) {
      LoggerService.log(
        'Failed to resolve all friend names: $e',
        tag: 'XmppNotifier',
      );
    }
  }

  Future<void> _resolveFriendName(String puuid) async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null || authState.hasSessionExpired) return;
    try {
      final api = ref.read(valorantApiProvider);
      final names = await api.fetchNamesByPuuids(
        [puuid],
        user.region,
        user.accessToken,
        user.entitlementsToken,
      );
      if (names.containsKey(puuid)) {
        final info = names[puuid]!;
        final gName = info['gameName'] ?? '';
        final tLine = info['tagline'] ?? '';
        if (gName.isNotEmpty) {
          final updated = Map<String, FriendPresence>.from(
            state.friendPresences,
          );
          final current = updated[puuid];
          if (current != null) {
            updated[puuid] = current.copyWith(gameName: gName, tagline: tLine);
            state = state.copyWith(friendPresences: updated);
          }
        }
      }
    } catch (e) {
      LoggerService.log(
        'Failed to resolve friend name for $puuid: $e',
        tag: 'XmppNotifier',
      );
    }
  }
}

final xmppServiceProvider = Provider<RiotXmppService>((ref) {
  final service = RiotXmppService();
  ref.onDispose(() => service.disconnect());
  return service;
});

final xmppProvider = NotifierProvider<XmppNotifier, XmppState>(
  XmppNotifier.new,
);
