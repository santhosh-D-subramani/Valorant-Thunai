import 'dart:convert';

class FriendPresence {
  final String puuid;
  final String jid;
  final String show;
  final bool isOnline;
  final String? gameName;
  final String? tagline;
  final String? statusMessage;
  final String? sessionLoop;
  final String? queueId;
  final int? partySize;
  final int? maxPartySize;
  final String? partyId;
  final String? playerCardId;
  final int? accountLevel;
  final String? competitiveTier;
  final Map<String, dynamic>? rawStatusJson;
  final bool isValorant;
  final DateTime lastUpdated;
  final String? savedNote;

  FriendPresence({
    required this.puuid,
    required this.jid,
    required this.show,
    required this.isOnline,
    this.gameName,
    this.tagline,
    this.statusMessage,
    this.sessionLoop,
    this.queueId,
    this.partySize,
    this.maxPartySize,
    this.partyId,
    this.playerCardId,
    this.accountLevel,
    this.competitiveTier,
    this.rawStatusJson,
    this.isValorant = false,
    DateTime? lastUpdated,
    this.savedNote,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  factory FriendPresence.fromXmlPresence({
    required String fromJid,
    required String show,
    required String? statusBase64,
    bool isValorant = false,
  }) {
    final puuid = fromJid.split('@').first;
    final isOnline = show != 'offline';

    String? gameName;
    String? tagline;
    String? statusMessage;
    String? sessionLoop;
    String? queueId;
    int? partySize;
    int? maxPartySize;
    String? partyId;
    String? playerCardId;
    int? accountLevel;
    String? competitiveTier;
    Map<String, dynamic>? statusMap;

    if (statusBase64 != null && statusBase64.isNotEmpty) {
      try {
        final decodedXmlOrJson = utf8.decode(
          base64.decode(statusBase64.trim()),
        );
        if (decodedXmlOrJson.startsWith('{')) {
          statusMap = jsonDecode(decodedXmlOrJson);
        } else {
          final jsonStartIndex = decodedXmlOrJson.indexOf('{');
          final jsonEndIndex = decodedXmlOrJson.lastIndexOf('}');
          if (jsonStartIndex != -1 && jsonEndIndex > jsonStartIndex) {
            final jsonSub = decodedXmlOrJson.substring(
              jsonStartIndex,
              jsonEndIndex + 1,
            );
            statusMap = jsonDecode(jsonSub);
          }
        }

        if (statusMap != null) {
          gameName = statusMap['gameName'];
          tagline = statusMap['tagLine'] ?? statusMap['tagline'];
          statusMessage = statusMap['statusMsg'];
          sessionLoop = statusMap['sessionLoopState'];
          queueId = statusMap['queueId'];
          partySize = statusMap['partySize'] is int
              ? statusMap['partySize']
              : int.tryParse('${statusMap['partySize']}');
          maxPartySize = statusMap['maxPartySize'] is int
              ? statusMap['maxPartySize']
              : int.tryParse('${statusMap['maxPartySize']}');
          partyId = statusMap['partyId'];
          playerCardId = statusMap['playerCardId'];
          accountLevel = statusMap['accountLevel'] is int
              ? statusMap['accountLevel']
              : int.tryParse('${statusMap['accountLevel']}');
          competitiveTier = statusMap['competitiveTier']?.toString();
        }
      } catch (_) {}
    }

    return FriendPresence(
      puuid: puuid,
      jid: fromJid,
      show: show,
      isOnline: isOnline,
      gameName: (gameName != null && gameName.isNotEmpty)
          ? gameName
          : 'Player ${puuid.length >= 8 ? puuid.substring(0, 8) : puuid}',
      tagline: tagline ?? '',
      statusMessage: statusMessage ?? (isOnline ? 'Online' : 'Offline'),
      sessionLoop: sessionLoop,
      queueId: queueId,
      partySize: partySize,
      maxPartySize: maxPartySize,
      partyId: partyId,
      playerCardId: playerCardId,
      accountLevel: accountLevel,
      competitiveTier: competitiveTier,
      rawStatusJson: statusMap,
      isValorant: isValorant,
    );
  }

  String get formattedStatus {
    if (!isOnline) return 'Offline';
    if (isValorant) {
      if (sessionLoop == 'INGAME') {
        return 'Playing - Valorant';
      } else if (sessionLoop == 'PREGAME') {
        return 'Agent Select';
      } else if (sessionLoop == 'MENUS') {
        return 'In Lobby - Valorant';
      }
    }
    return (statusMessage != null &&
            statusMessage!.isNotEmpty &&
            statusMessage != 'Online')
        ? statusMessage!
        : 'Riot Client';
  }

  String get formattedSubStatus {
    final parts = <String>[];
    if (queueId != null && queueId!.isNotEmpty) {
      final capQueue = queueId![0].toUpperCase() + queueId!.substring(1);
      parts.add(capQueue);
    }
    if (partySize != null && maxPartySize != null && maxPartySize! > 0) {
      parts.add('Party: $partySize/$maxPartySize');
    }
    return parts.join(' • ');
  }

  FriendPresence copyWith({
    String? show,
    bool? isOnline,
    String? gameName,
    String? tagline,
    String? statusMessage,
    String? sessionLoop,
    String? queueId,
    int? partySize,
    int? maxPartySize,
    String? partyId,
    String? playerCardId,
    int? accountLevel,
    String? competitiveTier,
    Map<String, dynamic>? rawStatusJson,
    bool? isValorant,
    String? savedNote,
  }) {
    return FriendPresence(
      puuid: puuid,
      jid: jid,
      show: show ?? this.show,
      isOnline: isOnline ?? this.isOnline,
      gameName: gameName ?? this.gameName,
      tagline: tagline ?? this.tagline,
      statusMessage: statusMessage ?? this.statusMessage,
      sessionLoop: sessionLoop ?? this.sessionLoop,
      queueId: queueId ?? this.queueId,
      partySize: partySize ?? this.partySize,
      maxPartySize: maxPartySize ?? this.maxPartySize,
      partyId: partyId ?? this.partyId,
      playerCardId: playerCardId ?? this.playerCardId,
      accountLevel: accountLevel ?? this.accountLevel,
      competitiveTier: competitiveTier ?? this.competitiveTier,
      rawStatusJson: rawStatusJson ?? this.rawStatusJson,
      isValorant: isValorant ?? this.isValorant,
      lastUpdated: DateTime.now(),
      savedNote: savedNote ?? this.savedNote,
    );
  }
}

class ChatMessage {
  final String id;
  final String fromJid;
  final String toJid;
  final String fromPuuid;
  final String body;
  final DateTime timestamp;
  final bool isMe;

  ChatMessage({
    required this.id,
    required this.fromJid,
    required this.toJid,
    required this.fromPuuid,
    required this.body,
    required this.timestamp,
    required this.isMe,
  });
}
