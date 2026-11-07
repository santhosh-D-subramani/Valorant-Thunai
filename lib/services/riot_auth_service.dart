import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import 'logger_service.dart';
import 'connectivity_service.dart';

final riotAuthServiceProvider = Provider<RiotAuthService>((ref) {
  return RiotAuthService();
});

class RiotUser {
  final String puuid;
  final String accessToken;
  final String entitlementsToken;
  final String idToken;
  final String shard;
  final String region;
  final String? cookies;
  final String? pasToken;
  final String? gameName;
  final String? tagline;
  final int? level;
  final String? playerCardId;
  final String? titleId;
  final int? vp;
  final int? radianite;
  final int? kingdomCredits;

  RiotUser({
    required this.puuid,
    required this.accessToken,
    required this.entitlementsToken,
    required this.idToken,
    required this.shard,
    required this.region,
    this.cookies,
    this.pasToken,
    this.gameName,
    this.tagline,
    this.level,
    this.playerCardId,
    this.titleId,
    this.vp,
    this.radianite,
    this.kingdomCredits,
  });

  Map<String, dynamic> toJson() => {
    'puuid': puuid,
    'accessToken': accessToken,
    'entitlementsToken': entitlementsToken,
    'idToken': idToken,
    'shard': shard,
    'region': region,
    'cookies': cookies,
    'pasToken': pasToken,
    'gameName': gameName,
    'tagline': tagline,
    'level': level,
    'playerCardId': playerCardId,
    'titleId': titleId,
    'vp': vp,
    'radianite': radianite,
    'kingdomCredits': kingdomCredits,
  };

  factory RiotUser.fromJson(Map<String, dynamic> map) => RiotUser(
    puuid: map['puuid'],
    accessToken: map['accessToken'],
    entitlementsToken: map['entitlementsToken'],
    idToken: map['idToken'],
    shard: map['shard'],
    region: map['region'],
    cookies: map['cookies'],
    pasToken: map['pasToken'],
    gameName: map['gameName'],
    tagline: map['tagline'],
    level: map['level'],
    playerCardId: map['playerCardId'],
    titleId: map['titleId'],
    vp: map['vp'],
    radianite: map['radianite'],
    kingdomCredits: map['kingdomCredits'],
  );

  DateTime? get tokenExpiration {
    try {
      final parts = accessToken.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
        );
        final exp = payload['exp'] as int?;
        if (exp != null) {
          return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        }
      }
    } catch (_) {}
    return null;
  }

  bool get isTokenExpiringSoon {
    final expiration = tokenExpiration;
    if (expiration == null) return true;

    return DateTime.now().isAfter(
      expiration.subtract(const Duration(minutes: 15)),
    );
  }
}

class RiotAuthService {
  static const String _entitlementsUrl =
      'https://entitlements.auth.riotgames.com/api/token/v1';
  static const String _riotGeoUrl =
      'https://riot-geo.pas.si.riotgames.com/pas/v1/product/valorant';
  static const String _pasTokenUrl =
      'https://riot-geo.pas.si.riotgames.com/pas/v1/service/chat';

  static final http.Client _client = http.Client();

  static Future<Map<String, dynamic>?> fetchChatConfig(
    String accessToken,
    String entitlementsToken,
  ) async {
    final bool online = await ConnectivityService.hasInternet();
    if (!online) {
      throw const io.SocketException('No internet connection');
    }

    try {
      final response = await _client.get(
        Uri.parse(
          'https://clientconfig.rpg.riotgames.com/api/v1/config/player?app=Riot%20Client',
        ),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'X-Riot-Entitlements-JWT': entitlementsToken,
          'User-Agent': 'RiotClient/93.0.1.1668.3491 rso-auth (Windows;10;;Professional;x64)',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        LoggerService.log(
          'Fetched Riot Client Config successfully',
          tag: 'RiotAuth',
        );
        return data;
      } else {
        LoggerService.log(
          'Client Config failed: ${response.statusCode} - ${response.body}',
          tag: 'RiotAuth',
        );
      }
    } catch (e) {
      LoggerService.log('Error fetching Client Config: $e', tag: 'RiotAuth');
    }
    return null;
  }

  Future<String?> fetchPasToken(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse(_pasTokenUrl),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (response.statusCode == 200) {
        String pasToken = response.body.trim();
        if (pasToken.startsWith('"') && pasToken.endsWith('"')) {
          try {
            pasToken = jsonDecode(pasToken) as String;
          } catch (_) {
            pasToken = pasToken.substring(1, pasToken.length - 1);
          }
        }
        LoggerService.log('PAS Token obtained for XMPP', tag: 'RiotAuth');
        return pasToken;
      } else {
        LoggerService.log(
          'Failed to get PAS token: ${response.statusCode} - ${response.body}',
          tag: 'RiotAuth',
        );
      }
    } catch (e) {
      LoggerService.log('Error fetching PAS token: $e', tag: 'RiotAuth');
    }
    return null;
  }

  Future<RiotUser> fetchTokens(
    String accessToken,
    String idToken, {
    String? cookies,
    int? correlationId,
  }) async {
    final int cid = correlationId ?? 0;
    LoggerService.log(
      '[AuthRefresh #$cid] fetchTokens started, inputs: accessTokenExists=${accessToken.isNotEmpty}, idTokenExists=${idToken.isNotEmpty}, cookiesCount=${cookies != null ? 1 : 0}',
      tag: 'RiotAuth',
    );

    final bool online = await ConnectivityService.hasInternet();
    if (!online) {
      LoggerService.log(
        '[AuthRefresh #$cid] fetchTokens failed: No internet',
        tag: 'RiotAuth',
      );
      throw const io.SocketException('No internet connection');
    }

    final response3 = await http.post(
      Uri.parse(_entitlementsUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response3.statusCode != 200) {
      LoggerService.log(
        '[AuthRefresh #$cid] Failed to get entitlements: ${response3.statusCode} Body: ${response3.body}',
        tag: 'RiotAuth',
      );
      throw Exception('Failed to get entitlements: ${response3.statusCode}');
    }
    final entitlementsToken = jsonDecode(response3.body)['entitlements_token'];
    LoggerService.log(
      '[AuthRefresh #$cid] entitlements obtained, length=${entitlementsToken.toString().length}',
      tag: 'RiotAuth',
    );

    final response4 = await http.put(
      Uri.parse(_riotGeoUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({"id_token": idToken}),
    );

    if (response4.statusCode != 200) {
      LoggerService.log(
        '[AuthRefresh #$cid] Failed to get region: ${response4.statusCode} Body: ${response4.body}',
        tag: 'RiotAuth',
      );
      throw Exception('Failed to get region: ${response4.statusCode}');
    }
    final geoBody = jsonDecode(response4.body);
    final String region = geoBody['affinities']['live'];
    LoggerService.log(
      '[AuthRefresh #$cid] Region detected: $region',
      tag: 'RiotAuth',
    );

    final pasToken = await fetchPasToken(accessToken);
    LoggerService.log(
      '[AuthRefresh #$cid] PAS token obtained: ${pasToken != null}',
      tag: 'RiotAuth',
    );

    String shard = region;
    if (region == 'as') {
      shard = 'ap';
    } else if (region == 'ko') {
      shard = 'kr';
    } else if (region == 'latam' || region == 'br') {
      shard = 'na';
    }

    LoggerService.log(
      '[AuthRefresh #$cid] Determined Shard: $shard',
      tag: 'RiotAuth',
    );

    String puuid = '';
    try {
      final parts = accessToken.split('.');
      if (parts.length == 3) {
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final String decoded = utf8.decode(base64Url.decode(normalized));
        final Map<String, dynamic> jwt = jsonDecode(decoded);
        puuid = jwt['sub'] ?? '';
      }
    } catch (e) {
      LoggerService.log(
        '[AuthRefresh #$cid] Error decoding JWT: $e',
        tag: 'RiotAuth',
      );
    }

    LoggerService.log(
      '[AuthRefresh #$cid] RiotUser constructed: puuidLength=${puuid.length}, shard=$shard, region=$region',
      tag: 'RiotAuth',
    );

    return RiotUser(
      puuid: puuid,
      accessToken: accessToken,
      entitlementsToken: entitlementsToken,
      idToken: idToken,
      shard: shard,
      region: region,
      cookies: cookies,
      pasToken: pasToken,
    );
  }

  static String serializeCookies(List<WebViewCookie> cookies) {
    final list = cookies
        .map(
          (c) => {
            'name': c.name,
            'value': c.value,
            'domain': c.domain,
            'path': c.path,
          },
        )
        .toList();
    return jsonEncode(list);
  }

  Future<RiotUser> silentRefresh(RiotUser user, {int? correlationId}) async {
    final int cid = correlationId ?? 0;
    final platform = io.Platform.isIOS ? 'iOS' : 'Android';
    LoggerService.log(
      '[AuthRefresh #$cid] silentRefresh started: platform=$platform',
      tag: 'RiotAuth',
    );

    final bool online = await ConnectivityService.hasInternet();
    if (!online) {
      LoggerService.log(
        '[AuthRefresh #$cid] silentRefresh failed: No internet',
        tag: 'RiotAuth',
      );
      throw const io.SocketException('No internet connection');
    }

    if (user.cookies == null) {
      LoggerService.log(
        '[AuthRefresh #$cid] silentRefresh failed: No cookies stored',
        tag: 'RiotAuth',
      );
      throw Exception('Refresh impossible: No cookies stored.');
    }

    LoggerService.log(
      'Attempting silent refresh (API) for ${user.gameName}...',
      tag: 'RiotAuth',
    );

    try {
      Map<String, Map<String, dynamic>> cookieMap = {};
      List<String> cookieParts = [];

      try {
        final List<dynamic> oldCookies = jsonDecode(user.cookies!);
        for (var item in oldCookies) {
          if (item is Map<String, dynamic>) {
            final name = item['name'] as String;
            final value = item['value']?.toString() ?? '';
            cookieMap[name] = item;
            cookieParts.add('$name=$value');
          }
        }
      } catch (e) {
        LoggerService.log(
          'Silent refresh cookies parsing as JSON failed, fallback to old format: $e',
          tag: 'RiotAuth',
        );
        final savedCookies = user.cookies!.split(';');
        for (var c in savedCookies) {
          if (c.trim().isEmpty) continue;
          final parts = c.trim().split('=');
          if (parts.length >= 2) {
            final name = parts[0].trim();
            final value = parts.sublist(1).join('=').trim();
            cookieMap[name] = {'name': name, 'value': value};
            cookieParts.add('$name=$value');
          }
        }
      }

      final cookieHeaderString = cookieParts.join('; ');

      final client = io.HttpClient();

      final urlStr =
          'https://auth.riotgames.com/authorize?redirect_uri=https%3A%2F%2Fplayvalorant.com%2Fopt_in&client_id=play-valorant-web-prod&response_type=token%20id_token&nonce=1&scope=account%20openid';
      final request = await client.getUrl(Uri.parse(urlStr));
      request.followRedirects = false;

      request.headers.set(
        'User-Agent',
        'RiotGamesApi/24.3.0.3124 rso-auth (Windows;10;;Home, x64) riot_client/0',
      );
      request.headers.set('Cache-Control', 'no-cache');

      if (cookieHeaderString.isNotEmpty) {
        request.headers.set('Cookie', cookieHeaderString);
      }

      LoggerService.log(
        '[AuthRefresh #$cid] REQUEST: method=GET, url=$urlStr, followRedirects=false',
        tag: 'RiotAuth',
      );
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final bodyLength = responseBody.length;

      LoggerService.log(
        'Silent refresh API status: ${response.statusCode}',
        tag: 'RiotAuth',
      );

      final contentType = response.headers.value('content-type') ?? 'N/A';
      final setCookies = response.headers['set-cookie'];
      final setCookieCount = setCookies?.length ?? 0;

      List<String> setCookieNames = [];
      List<String> setCookieDomains = [];
      List<String> setCookiePaths = [];
      List<String> setCookieExpiries = [];

      if (setCookies != null) {
        for (var setCookie in setCookies) {
          final parts = setCookie.split(';');
          if (parts.isNotEmpty) {
            final nameValue = parts[0].split('=');
            if (nameValue.length >= 2) {
              final name = nameValue[0].trim();
              setCookieNames.add(name);

              String domain = 'N/A';
              String path = 'N/A';
              String expires = 'N/A';

              for (int i = 1; i < parts.length; i++) {
                final attr = parts[i].trim();
                if (attr.toLowerCase().startsWith('domain=')) {
                  domain = attr.substring(7);
                } else if (attr.toLowerCase().startsWith('path=')) {
                  path = attr.substring(5);
                } else if (attr.toLowerCase().startsWith('expires=')) {
                  expires = attr.substring(8);
                }
              }
              setCookieDomains.add('$name:$domain');
              setCookiePaths.add('$name:$path');
              setCookieExpiries.add('$name:$expires');
            }
          }
        }
      }

      LoggerService.log(
        '[AuthRefresh #$cid] RESPONSE: status=${response.statusCode}, Content-Type=$contentType, bodyLength=$bodyLength, Set-Cookie-Count=$setCookieCount',
        tag: 'RiotAuth',
      );

      if (response.statusCode != 301 &&
          response.statusCode != 302 &&
          response.statusCode != 303 &&
          response.statusCode != 307) {
        LoggerService.log(
          '[AuthRefresh #$cid] Silent refresh failed: Expected redirect but got ${response.statusCode}',
          tag: 'RiotAuth',
        );
        throw Exception(
          'Silent refresh failed. Expected redirect but got ${response.statusCode} - body: $responseBody',
        );
      }

      final location = response.headers.value('location');
      if (location == null) {
        LoggerService.log(
          '[AuthRefresh #$cid] Silent refresh failed: No location header in redirect',
          tag: 'RiotAuth',
        );
        throw Exception(
          'Silent refresh failed. No location header in redirect.',
        );
      }

      if (location.startsWith('https://authenticate.riotgames.com/login')) {
        LoggerService.log(
          '[AuthRefresh #$cid] 303 processing: login redirect detected',
          tag: 'RiotAuth',
        );
        throw Exception('Session expired (login redirect).');
      }

      LoggerService.log(
        '[AuthRefresh #$cid] 303 processing: token extraction attempted',
        tag: 'RiotAuth',
      );
      final uri = Uri.parse(location.replaceFirst('#', '?'));
      final accessToken = uri.queryParameters['access_token'];
      final idToken = uri.queryParameters['id_token'];

      LoggerService.log(
        '[AuthRefresh #$cid] 303 processing: access_token found=${accessToken != null}, id_token found=${idToken != null}',
        tag: 'RiotAuth',
      );

      if (accessToken == null || idToken == null) {
        throw Exception(
          'Failed to extract tokens from silent refresh redirect URL: $location',
        );
      }

      if (setCookies != null) {
        LoggerService.log(
          '[AuthRefresh #$cid] 303 processing: Set-Cookie headers found, merging...',
          tag: 'RiotAuth',
        );
        for (var setCookie in setCookies) {
          final parts = setCookie.split(';');
          if (parts.isNotEmpty) {
            final nameValue = parts[0].split('=');
            if (nameValue.length >= 2) {
              final name = nameValue[0].trim();
              final value = nameValue.sublist(1).join('=').trim();

              Map<String, dynamic> newCookie = {'name': name, 'value': value};

              for (int i = 1; i < parts.length; i++) {
                final attr = parts[i].trim();
                if (attr.toLowerCase().startsWith('domain=')) {
                  newCookie['domain'] = attr.substring(7);
                } else if (attr.toLowerCase().startsWith('path=')) {
                  newCookie['path'] = attr.substring(5);
                } else if (attr.toLowerCase() == 'secure') {
                  newCookie['isSecure'] = true;
                } else if (attr.toLowerCase() == 'httponly') {
                  newCookie['isHttpOnly'] = true;
                } else if (attr.toLowerCase().startsWith('samesite=')) {
                  newCookie['sameSite'] = attr.substring(9);
                }
              }
              cookieMap[name] = newCookie;
            }
          }
        }
        LoggerService.log(
          '[AuthRefresh #$cid] 303 processing: cookies merged',
          tag: 'RiotAuth',
        );
      }

      final updatedCookiesJson = jsonEncode(cookieMap.values.toList());

      LoggerService.log(
        '[AuthRefresh #$cid] 303 processing: fetchTokens started',
        tag: 'RiotAuth',
      );
      try {
        final resUser = await fetchTokens(
          accessToken,
          idToken,
          cookies: updatedCookiesJson,
          correlationId: cid,
        );
        LoggerService.log(
          '[AuthRefresh #$cid] 303 processing: fetchTokens succeeded',
          tag: 'RiotAuth',
        );
        return resUser;
      } catch (e) {
        LoggerService.log(
          '[AuthRefresh #$cid] 303 processing: fetchTokens failed: $e',
          tag: 'RiotAuth',
        );
        rethrow;
      }
    } catch (e) {
      LoggerService.log('Silent refresh failed: $e', tag: 'RiotAuth');
      rethrow;
    }
  }
}
