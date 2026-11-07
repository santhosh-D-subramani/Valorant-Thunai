import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:valorant_thunai/models/xmpp_models.dart';

import 'logger_service.dart';

typedef OnPresenceCallback = void Function(FriendPresence presence);
typedef OnMessageCallback = void Function(ChatMessage message);
typedef OnConnectionStatusCallback = void Function(
  bool isConnected,
  String status,
);

class RiotXmppService {
  SecureSocket? _socket;
  StreamSubscription? _subscription;

  String? _puuid;
  String? _affinity;
  String? _connectedHost;
  String? _userJid;
  bool _isConnected = false;
  bool _isAuthenticated = false;

  final StringBuffer _buffer = StringBuffer();

  OnPresenceCallback? onPresenceUpdated;
  OnMessageCallback? onMessageReceived;
  OnConnectionStatusCallback? onConnectionStatusChanged;

  bool get isConnected => _isConnected;
  bool get isAuthenticated => _isAuthenticated;
  String? get puuid => _puuid;

  Future<bool> connect({
    required String accessToken,
    required String pasToken,
    required String affinity,
    required String puuid,
    String? customHost,
    int? customPort,
  }) async {
    disconnect();

    _puuid = puuid;
    _affinity = affinity.isEmpty ? 'ap' : affinity;

    try {
      final parts = pasToken.split('.');
      if (parts.length == 3) {
        final payloadStr = utf8.decode(
          base64Url.decode(base64Url.normalize(parts[1])),
        );
        final Map<String, dynamic> payload = jsonDecode(payloadStr);
        LoggerService.log('PAS Token Claims: $payload', tag: 'RiotXMPP');

        final pasAffinity =
            payload['affinity'] ??
            payload['pas']?['affinity'] ??
            payload['affinity_id'];
        if (pasAffinity != null && pasAffinity.toString().isNotEmpty) {
          _affinity = pasAffinity.toString();
        }
      }
    } catch (e) {
      LoggerService.log(
        'Could not extract affinity from PAS token: $e',
        tag: 'RiotXMPP',
      );
    }

    String mappedAffinity = (_affinity ?? 'ap').toLowerCase();
    if (mappedAffinity == 'asia' || mappedAffinity == 'as') {
      mappedAffinity = 'ap';
    } else if (mappedAffinity == 'korea' || mappedAffinity == 'ko') {
      mappedAffinity = 'kr';
    }
    _affinity = mappedAffinity;

    final candidateHosts = <String>[
      if (customHost != null && customHost.isNotEmpty) customHost,
      '$_affinity.chat.si.riotgames.com',
      if (_affinity == 'ap') ...[
        'asia.chat.si.riotgames.com',
        'ap1.chat.si.riotgames.com',
        'ap2.chat.si.riotgames.com',
        'asia1.chat.si.riotgames.com',
        'asia2.chat.si.riotgames.com',
        'jp1.chat.si.riotgames.com',
      ],
      if (_affinity == 'eu') ...[
        'euw1.chat.si.riotgames.com',
        'eun1.chat.si.riotgames.com',
        'eu1.chat.si.riotgames.com',
        'eu2.chat.si.riotgames.com',
      ],
      if (_affinity == 'na') ...[
        'na1.chat.si.riotgames.com',
        'na2.chat.si.riotgames.com',
        'la1.chat.si.riotgames.com',
        'la2.chat.si.riotgames.com',
      ],
      if (_affinity == 'kr') ...[
        'kr1.chat.si.riotgames.com',
        'kr2.chat.si.riotgames.com',
      ],
    ];

    const port = 5223;
    String? connectedHost;

    for (final host in candidateHosts) {
      _updateStatus(false, 'Connecting to $host:$port...');
      try {
        _socket = await SecureSocket.connect(
          host,
          port,
          onBadCertificate: (cert) => true,
          timeout: const Duration(seconds: 5),
        );
        connectedHost = host;
        _connectedHost = host;
        LoggerService.log(
          'Successfully connected to XMPP Host: $host',
          tag: 'RiotXMPP',
        );
        break;
      } catch (e) {
        LoggerService.log(
          'Failed connecting to host $host: $e',
          tag: 'RiotXMPP',
        );
      }
    }

    if (_socket == null || connectedHost == null) {
      _updateStatus(false, 'Failed to connect to all candidate XMPP hosts');
      return false;
    }

    try {
      _isConnected = true;
      _updateStatus(
        true,
        'Socket connected to $connectedHost. Authenticating...',
      );

      _subscription = _socket!.listen(
        _onDataReceived,
        onError: (e) {
          LoggerService.log('XMPP Socket error: $e', tag: 'RiotXMPP');
          disconnect();
        },
        onDone: () {
          LoggerService.log('XMPP Socket closed by server', tag: 'RiotXMPP');
          disconnect();
        },
      );

      final String streamDomain =
          (connectedHost.contains('chat.si.riotgames.com'))
          ? connectedHost.replaceAll('.chat.si.riotgames.com', '.pvp.net')
          : '$_affinity.pvp.net';

      _sendRaw(
        '<stream:stream to="$streamDomain" xmlns="jabber:client" xmlns:stream="http://etherx.jabber.org/streams" version="1.0">',
      );

      await Future.delayed(const Duration(milliseconds: 500));
      _sendRaw(
        '<auth mechanism="X-Riot-RSO-PAS" xmlns="urn:ietf:params:xml:ns:xmpp-sasl">'
        '<rso_token>$accessToken</rso_token>'
        '<pas_token>$pasToken</pas_token>'
        '</auth>',
      );

      await Future.delayed(const Duration(seconds: 2));

      if (_isAuthenticated) {
        _sendInitialPresence();
        _requestRoster();
      }

      return _isAuthenticated;
    } catch (e) {
      LoggerService.log('Failed to connect to XMPP: $e', tag: 'RiotXMPP');
      disconnect();
      return false;
    }
  }

  void _onDataReceived(List<int> data) {
    final text = utf8.decode(data, allowMalformed: true);
    LoggerService.log('XMPP Recv: $text', tag: 'RiotXMPP');
    _buffer.write(text);
    _parseBuffer(text);
  }

  String get _streamDomain =>
      (_connectedHost?.contains('chat.si.riotgames.com') ?? false)
      ? _connectedHost!.replaceAll('.chat.si.riotgames.com', '.pvp.net')
      : '$_affinity.pvp.net';

  void _parseBuffer(String newChunk) {
    while (true) {
      final content = _buffer.toString();

      int firstIndex = -1;
      String matchedTag = '';

      final tags = [
        'presence',
        'message',
        'iq',
        'success',
        'failure',
        'stream:features',
        'stream:error',
      ];
      for (final tag in tags) {
        final idx = content.indexOf('<$tag');
        if (idx != -1 && (firstIndex == -1 || idx < firstIndex)) {
          final nextCharIdx = idx + tag.length + 1;
          if (nextCharIdx < content.length) {
            final nextChar = content[nextCharIdx];
            if (nextChar == ' ' ||
                nextChar == '>' ||
                (nextChar == '/' &&
                    nextCharIdx + 1 < content.length &&
                    content[nextCharIdx + 1] == '>')) {
              firstIndex = idx;
              matchedTag = tag;
            }
          }
        }
      }

      if (firstIndex == -1) {
        final lastBracket = content.lastIndexOf('<');
        if (lastBracket != -1 && lastBracket > content.length - 20) {
          final keep = content.substring(lastBracket);
          _buffer.clear();
          _buffer.write(keep);
        } else {
          _buffer.clear();
        }
        break;
      }

      final closeTag = '</$matchedTag>';
      final closeIndex = content.indexOf(closeTag, firstIndex);

      final firstGreater = content.indexOf('>', firstIndex);
      bool isSelfClosing = false;
      int stanzaEndIndex = -1;

      if (firstGreater != -1 && firstGreater > firstIndex) {
        if (content[firstGreater - 1] == '/') {
          isSelfClosing = true;
          stanzaEndIndex = firstGreater + 1;
        }
      }

      if (!isSelfClosing && closeIndex != -1) {
        stanzaEndIndex = closeIndex + closeTag.length;
      }

      if (stanzaEndIndex == -1) {
        if (firstIndex > 0) {
          final remaining = content.substring(firstIndex);
          _buffer.clear();
          _buffer.write(remaining);
        }
        break;
      }

      final stanza = content.substring(firstIndex, stanzaEndIndex);

      final remaining = content.substring(stanzaEndIndex);
      _buffer.clear();
      _buffer.write(remaining);

      try {
        _processSingleStanza(matchedTag, stanza);
      } catch (e) {
        LoggerService.log(
          'Error processing stanza: $e\nStanza: $stanza',
          tag: 'RiotXMPP',
        );
      }
    }
  }

  void _processSingleStanza(String tag, String stanza) {
    LoggerService.log('Processing Stanza ($tag): $stanza', tag: 'RiotXMPP');
    if (tag == 'success') {
      if (!_isAuthenticated) {
        _isAuthenticated = true;
        _updateStatus(true, 'Authenticated via X-Riot-RSO-PAS');
        LoggerService.log('XMPP SASL Auth Success!', tag: 'RiotXMPP');

        final String hostDomain = _streamDomain;
        _sendRaw(
          '<?xml version="1.0"?><stream:stream to="$hostDomain" version="1.0" xmlns:stream="http://etherx.jabber.org/streams">',
        );

        Future.delayed(const Duration(milliseconds: 300), () {
          _sendRaw(
            '<iq type="set" id="bind_1"><bind xmlns="urn:ietf:params:xml:ns:xmpp-bind"><resource>val-shop-$_puuid</resource></bind></iq>',
          );
          _sendRaw(
            '<iq type="set" id="session_1"><session xmlns="urn:ietf:params:xml:ns:xmpp-session"/></iq>',
          );
          _sendInitialPresence();
          _requestRoster();
        });
      }
    } else if (tag == 'iq') {
      _processIqStanza(stanza);
    } else if (tag == 'presence') {
      _processPresenceStanza(stanza);
    } else if (tag == 'message') {
      _processMessageStanza(stanza);
    }
  }

  void _processIqStanza(String stanza) {
    if (stanza.contains('<jid>')) {
      final jidMatch = RegExp(r'<jid>(.*?)</jid>').firstMatch(stanza);
      if (jidMatch != null) {
        _userJid = jidMatch.group(1);
        LoggerService.log('Bound JID: $_userJid', tag: 'RiotXMPP');
      }
    }

    if (stanza.contains('jabber:iq:riotgames:roster') ||
        stanza.contains('jabber:iq:roster')) {
      final itemTagRegex = RegExp(r'<item\s+([^>]+?)/?>');
      final matches = itemTagRegex.allMatches(stanza);
      int parsedCount = 0;
      for (final match in matches) {
        final itemBody = match.group(1) ?? '';

        final jidMatch =
            RegExp(r'jid="([^"]+)"').firstMatch(itemBody) ??
            RegExp(r"jid='([^']+)'").firstMatch(itemBody);
        final jid = jidMatch?.group(1) ?? '';

        final nameMatch =
            RegExp(r'name="([^"]+)"').firstMatch(itemBody) ??
            RegExp(r"name='([^']+)'").firstMatch(itemBody);
        final name = nameMatch?.group(1) ?? '';

        final noteMatch =
            RegExp(r'note="([^"]*)"').firstMatch(itemBody) ??
            RegExp(r"note='([^']*)'").firstMatch(itemBody);
        final note = _unescapeXml(noteMatch?.group(1) ?? '');

        final puuid = jid.split('@').first;
        if (puuid.isNotEmpty && puuid != _puuid) {
          final presence = FriendPresence(
            puuid: puuid,
            jid: jid,
            gameName: name.isNotEmpty
                ? name.split('#').first
                : 'Player ${puuid.length >= 8 ? puuid.substring(0, 8) : puuid}',
            tagline: name.contains('#') ? name.split('#').last : '',
            show: 'offline',
            statusMessage: 'Offline',
            isOnline: false,
            savedNote: note.isNotEmpty ? note : null,
          );
          onPresenceUpdated?.call(presence);
          parsedCount++;
        }
      }
      LoggerService.log(
        'Roster IQ parsed: $parsedCount friend(s) seeded as offline (live presence pushes will flip online ones)',
        tag: 'RiotXMPP',
      );
    }
  }

  String _unescapeXml(String value) {
    return value
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&');
  }

  void _processPresenceStanza(String stanza) {
    final fromMatch =
        RegExp(r'from="([^"]+)"').firstMatch(stanza) ??
        RegExp(r"from='([^']+)'").firstMatch(stanza);
    if (fromMatch == null) return;
    final fromJid = fromMatch.group(1) ?? '';
    final senderPuuid = fromJid.split('@').first;
    if (senderPuuid == _puuid) return;

    String show = 'chat';
    if (stanza.contains('<show>away</show>')) {
      show = 'away';
    } else if (stanza.contains('<show>dnd</show>')) {
      show = 'dnd';
    } else if (stanza.contains('type="unavailable"') ||
        stanza.contains("type='unavailable'")) {
      show = 'offline';
    }

    String? statusBase64;

    final valorantMatch = RegExp(
      r'<valorant>(.*?)</valorant>',
      dotAll: true,
    ).firstMatch(stanza);

    if (valorantMatch != null) {
      final valorantBody = valorantMatch.group(1) ?? '';
      final pMatch = RegExp(
        r'<p>(.*?)</p>',
        dotAll: true,
      ).firstMatch(valorantBody);
      if (pMatch != null) {
        statusBase64 = pMatch.group(1);
      }
    }

    if (statusBase64 == null || statusBase64.isEmpty) {
      final statusMatch = RegExp(
        r'<status>(.*?)</status>',
        dotAll: true,
      ).firstMatch(stanza);
      if (statusMatch != null) {
        statusBase64 = statusMatch.group(1);
      }
    }

    final bool isValorant = valorantMatch != null;
    final presence = FriendPresence.fromXmlPresence(
      fromJid: fromJid,
      show: show,
      statusBase64: statusBase64,
      isValorant: isValorant,
    );

    onPresenceUpdated?.call(presence);
  }

  void _processMessageStanza(String stanza) {
    final fromMatch =
        RegExp(r'from="([^"]+)"').firstMatch(stanza) ??
        RegExp(r"from='([^']+)'").firstMatch(stanza);
    if (fromMatch == null) return;
    final fromJid = fromMatch.group(1) ?? '';
    final senderPuuid = fromJid.split('@').first;

    final bodyMatch = RegExp(
      r'<body>(.*?)</body>',
      dotAll: true,
    ).firstMatch(stanza);

    if (bodyMatch != null) {
      final text = bodyMatch.group(1) ?? '';

      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fromJid: fromJid,
        toJid: _userJid ?? '',
        fromPuuid: senderPuuid,
        body: text,
        timestamp: DateTime.now(),
        isMe: false,
      );

      onMessageReceived?.call(message);
    }
  }

  void _sendInitialPresence() {
    final statusPayload = {
      'isIdle': false,
      'statusMsg': 'ValShop Mobile',
      'sessionLoopState': 'MENUS',
    };
    final encodedStatus = base64.encode(utf8.encode(jsonEncode(statusPayload)));

    final xml =
        '<presence>'
        '<show>chat</show>'
        '<status>$encodedStatus</status>'
        '</presence>';
    _sendRaw(xml);
  }

  void _requestRoster() {
    _sendRaw(
      '<iq type="get" id="2"><query xmlns="jabber:iq:riotgames:roster" last_state="true" /></iq>',
    );
  }

  void sendChatMessage(String recipientPuuid, String messageText) {
    if (!_isConnected || _socket == null) {
      LoggerService.log(
        'Cannot send message: socket not connected',
        tag: 'RiotXMPP',
      );
      return;
    }

    final domain =
        (_connectedHost != null &&
            _connectedHost!.contains('chat.si.riotgames.com'))
        ? _connectedHost!.replaceAll('.chat.si.riotgames.com', '.pvp.net')
        : '$_affinity.pvp.net';
    final targetJid = recipientPuuid.contains('@')
        ? recipientPuuid
        : '$recipientPuuid@$domain';

    final xml =
        '<message to="$targetJid" type="chat">'
        '<body>${_escapeXml(messageText)}</body>'
        '</message>';

    _sendRaw(xml);

    final sentMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fromJid: _userJid ?? '',
      toJid: targetJid,
      fromPuuid: recipientPuuid,
      body: messageText,
      timestamp: DateTime.now(),
      isMe: true,
    );

    onMessageReceived?.call(sentMessage);
  }

  void sendPresenceStatus({required String show, String? statusMsg}) {
    if (!_isConnected) return;
    final statusPayload = {
      'isIdle': show == 'away',
      'statusMsg': statusMsg ?? 'ValShop Mobile',
      'sessionLoopState': 'MENUS',
    };
    final encodedStatus = base64.encode(utf8.encode(jsonEncode(statusPayload)));

    final xml =
        '<presence>'
        '<show>$show</show>'
        '<status>$encodedStatus</status>'
        '</presence>';
    _sendRaw(xml);
  }

  void _sendRaw(String xml) {
    try {
      _socket?.write(xml);
      LoggerService.log('XMPP Sent: $xml', tag: 'RiotXMPP');
    } catch (e) {
      LoggerService.log('Error writing to XMPP socket: $e', tag: 'RiotXMPP');
    }
  }

  String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  void _updateStatus(bool connected, String status) {
    _isConnected = connected;
    onConnectionStatusChanged?.call(connected, status);
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
    _isConnected = false;
    _isAuthenticated = false;
    _buffer.clear();
    _updateStatus(false, 'Disconnected');
  }
}
