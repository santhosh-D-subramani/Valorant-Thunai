import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'riot_auth_service.dart';

import 'package:valorant_thunai/providers/auth_provider.dart';

import 'logger_service.dart';
import 'connectivity_service.dart';

final valorantApiProvider = Provider<ValorantApi>((ref) {
  return ValorantApi(ref);
});

class ValorantApi {
  final Ref ref;
  ValorantApi(this.ref);

  static Future<void> _ensureOnline() async {
    final bool online = await ConnectivityService.hasInternet();
    if (!online) {
      throw const SocketException('No internet connection');
    }
  }

  static const String _clientPlatform =
      'ew0KCSJwbGF0Zm9ybVR5cGUiOiAiUEMiLA0KCSJwbGF0Zm9ybU9TIjogIldpbmRvd3MiLA0KCSJwbGF0Zm9ybU9TVmVyc2lvbiI6ICIxMC4wLjE5MDQyLjEuMjU2LjY0Yml0IiwNCgkicGxhdGZvcm1DaGlwc2V0IjogIlVua25vd24iDQp9';
  static const String _henrikApiKey = String.fromEnvironment(
    'HENRIK_API_KEY',
    defaultValue: '',
  );
  static String? customHenrikApiKey;
  static const String prefHenrikApiKey = 'custom_henrik_api_key';

  static String get henrikApiKey {
    if (customHenrikApiKey != null && customHenrikApiKey!.trim().isNotEmpty) {
      return customHenrikApiKey!.trim();
    }
    return _henrikApiKey;
  }

  static bool get hasHenrikApiKey => henrikApiKey.isNotEmpty;

  static Map<String, String> get _henrikHeaders {
    final key = henrikApiKey;
    return {if (key.isNotEmpty) 'Authorization': key};
  }

  static Future<void> loadCustomApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    customHenrikApiKey = prefs.getString(prefHenrikApiKey);
  }

  static Future<void> setCustomApiKey(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == null || key.trim().isEmpty) {
      customHenrikApiKey = null;
      await prefs.remove(prefHenrikApiKey);
    } else {
      customHenrikApiKey = key.trim();
      await prefs.setString(prefHenrikApiKey, customHenrikApiKey!);
    }
  }

  static Future<({bool success, String message})> testHenrikApiKey(
    String key,
  ) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      return (success: false, message: 'API key cannot be empty');
    }
    try {
      final res = await http
          .get(
            Uri.parse('https://api.henrikdev.xyz/valorant/v1/website/en-us'),
            headers: {'Authorization': trimmed},
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        return (success: true, message: 'Valid HenrikDev API Key!');
      } else if (res.statusCode == 401) {
        return (
          success: false,
          message: '401 Unauthorized: Invalid or expired API Key',
        );
      } else if (res.statusCode == 429) {
        return (
          success: false,
          message: '429 Rate Limited: Key quota exceeded',
        );
      } else {
        return (
          success: false,
          message: 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
        );
      }
    } catch (e) {
      return (success: false, message: 'Connection error: $e');
    }
  }

  static String? _cachedClientVersion;

  void _handleUnauthorized() {
    ref.read(authProvider.notifier).setSessionExpired(true);
  }

  static Future<Map<String, dynamic>> getBundleByUuid(String uuid) async {
    await _ensureOnline();
    final res = await http.get(
      Uri.parse('https://valorant-api.com/v1/bundles/$uuid'),
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      return json['data'];
    } else {
      throw Exception('Failed to load bundle');
    }
  }

  static Future<List<dynamic>> getBundles() async {
    await _ensureOnline();
    final res = await http.get(
      Uri.parse('https://valorant-api.com/v1/bundles'),
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      return json['data'];
    } else {
      throw Exception('Failed to load bundles');
    }
  }

  Future<String> _getClientVersion() async {
    if (_cachedClientVersion != null) {
      return _cachedClientVersion!;
    }
    try {
      final response = await http.get(
        Uri.parse('https://valorant-api.com/v1/version'),
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final String version = jsonResponse['data']['riotClientVersion'];
        _cachedClientVersion = version;
        LoggerService.log(
          'Fetched client version from API: $version',
          tag: 'ValorantApi',
        );
        return version;
      }
    } catch (e) {
      LoggerService.log(
        'Failed to get remote client version, using fallback: $e',
        tag: 'ValorantApi',
      );
    }
    return 'release-13.00-shipping-28-4928912';
  }

  Future<RiotUser> enrichUserWithInfo(RiotUser user) async {
    LoggerService.log(
      'Enriching user info for: ${user.puuid}',
      tag: 'ValorantApi',
    );
    try {
      final String clientVersion = await _getClientVersion();

      String? gameName;
      String? tagline;
      int? level;
      String? playerCardId;
      String? titleId;
      String? region;

      try {
        final henrikData = await _fetchHenrikAccount(user.puuid);
        if (henrikData != null) {
          gameName = henrikData['name'];
          tagline = henrikData['tag'];
          level = henrikData['account_level'];
          region = henrikData['region'] ?? user.region;
          if (henrikData['card'] != null) {
            playerCardId = henrikData['card']['id'];
          }
          LoggerService.log(
            'Fetched account data from HenrikDev',
            tag: 'ValorantApi',
          );
        }
      } catch (e) {
        LoggerService.log('HenrikDev fetch failed: $e', tag: 'ValorantApi');
      }

      try {
        final headers = {
          'X-Riot-Entitlements-JWT': user.entitlementsToken,
          'Authorization': 'Bearer ${user.accessToken}',
          'X-Riot-ClientPlatform': _clientPlatform,
          'X-Riot-ClientVersion': clientVersion,
        };
        final loadoutUri = Uri.parse(
          'https://pd.${user.shard}.a.pvp.net/personalization/v2/players/${user.puuid}/playerloadout',
        );
        final loadoutRes = await http.get(loadoutUri, headers: headers);
        if (loadoutRes.statusCode == 200) {
          final json = jsonDecode(loadoutRes.body);
          if (json['Identity'] != null) {
            titleId ??= json['Identity']['PlayerTitleID'];
            playerCardId ??= json['Identity']['PlayerCardID'];
          }
        }
      } catch (_) {}

      if (gameName == null || tagline == null) {
        try {
          final userInfoUri = Uri.parse('https://auth.riotgames.com/userinfo');
          final userInfoRes = await http.get(
            userInfoUri,
            headers: {'Authorization': 'Bearer ${user.accessToken}'},
          );
          if (userInfoRes.statusCode == 200) {
            final infoJson = jsonDecode(userInfoRes.body);
            if (infoJson['acct'] != null) {
              gameName ??= infoJson['acct']['game_name'];
              tagline ??= infoJson['acct']['tag_line'];
            }
          }
        } catch (_) {}
      }

      if (gameName == null || tagline == null) {
        try {
          final names = await fetchNamesByPuuids(
            [user.puuid],
            user.shard,
            user.accessToken,
            user.entitlementsToken,
          );
          if (names.containsKey(user.puuid)) {
            gameName ??= names[user.puuid]!['gameName'];
            tagline ??= names[user.puuid]!['tagline'];
          }
        } catch (_) {}
      }

      if (level == null) {
        try {
          final xpData = await getAccountXp(
            shard: user.shard,
            puuid: user.puuid,
            accessToken: user.accessToken,
            entitlementsToken: user.entitlementsToken,
          );
          final progress = xpData['Progress'];
          if (progress is Map && progress['Level'] != null) {
            level = (progress['Level'] as num).toInt();
          }
        } catch (_) {}
      }

      int? vp;
      int? radianite;
      int? kingdomCredits;
      try {
        final wallet = await fetchWallet(
          shard: user.shard,
          puuid: user.puuid,
          accessToken: user.accessToken,
          entitlementsToken: user.entitlementsToken,
        );
        vp = wallet['85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741'];
        radianite = wallet['e59aa87c-4cbf-517a-5983-6e81511be9b7'];
        kingdomCredits = wallet['85ca954a-41f2-ce94-9b45-8ca3dd39a00d'];
      } catch (e) {
        LoggerService.log('Wallet fetch failed: $e', tag: 'ValorantApi');
      }

      gameName ??= user.gameName;
      tagline ??= user.tagline;
      level ??= user.level;
      playerCardId ??= user.playerCardId;
      titleId ??= user.titleId;

      LoggerService.log(
        'User Enriched: Name: $gameName#$tagline, Level: $level, Card: $playerCardId, Title: $titleId, VP: $vp, Rad: $radianite, KC: $kingdomCredits',
        tag: 'ValorantApi',
      );

      return RiotUser(
        puuid: user.puuid,
        accessToken: user.accessToken,
        entitlementsToken: user.entitlementsToken,
        idToken: user.idToken,
        shard: user.shard,
        region: region ?? user.region,
        cookies: user.cookies,
        gameName: gameName,
        tagline: tagline,
        level: level,
        playerCardId: playerCardId,
        titleId: titleId,
        vp: vp,
        radianite: radianite,
        kingdomCredits: kingdomCredits,
      );
    } catch (e) {
      LoggerService.log('Error in enrichUserWithInfo: $e', tag: 'ValorantApi');
      return user;
    }
  }

  Future<Map<String, dynamic>> getStorefrontWithCache({
    required String shard,
    required String puuid,
    required String accessToken,
    required String entitlementsToken,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'shop_cache_$puuid';
    final expiryKey = 'shop_expiry_$puuid';

    String currentAccessToken = accessToken;
    String currentEntitlementsToken = entitlementsToken;

    try {
      await ref.read(authProvider.notifier).checkAndRefreshSession();
      final user = ref.read(authProvider).user;
      if (user != null) {
        currentAccessToken = user.accessToken;
        currentEntitlementsToken = user.entitlementsToken;
      }
    } catch (e) {
      LoggerService.log(
        'Background token refresh failed: $e',
        tag: 'ValorantApi',
      );
    }

    try {
      final data = await getStorefront(
        shard: shard,
        puuid: puuid,
        accessToken: currentAccessToken,
        entitlementsToken: currentEntitlementsToken,
      );

      _cacheStorefront(data, cacheKey, expiryKey);
      return data;
    } catch (e) {
      if (ref.read(authProvider).hasSessionExpired) {
        rethrow;
      }
      if (e.toString().contains('401') ||
          e.toString().contains('400') ||
          e.toString().contains('expired') ||
          e.toString().contains('Unauthorized')) {
        LoggerService.log(
          '401 caught in getStorefrontWithCache, attempting force refresh...',
          tag: 'ValorantApi',
        );

        await ref
            .read(authProvider.notifier)
            .checkAndRefreshSession(force: true);
        final user = ref.read(authProvider).user;

        if (user != null) {
          LoggerService.log(
            'Topken refreshed, retrying storefront fetch...',
            tag: 'ValorantApi',
          );
          try {
            final data = await getStorefront(
              shard: user.shard,
              puuid: user.puuid,
              accessToken: user.accessToken,
              entitlementsToken: user.entitlementsToken,
            );
            _cacheStorefront(data, cacheKey, expiryKey);
            return data;
          } catch (e2) {
            LoggerService.log('Retry failed: $e2', tag: 'ValorantApi');
            _handleUnauthorized();
            rethrow;
          }
        }
      }
      LoggerService.log('Failed to fetch shop: $e', tag: 'ValorantApi');
      if (e.toString().contains('401')) _handleUnauthorized();
      rethrow;
    }
  }

  Future<void> _cacheStorefront(
    Map<String, dynamic> data,
    String key,
    String expiryKey,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skinsPanel = data['SkinsPanelLayout'];
      if (skinsPanel != null) {
        final remainingSeconds =
            skinsPanel['SingleItemOffersRemainingDurationInSeconds'] as int? ??
            0;
        if (remainingSeconds > 0) {
          final expiryTimestamp =
              DateTime.now().millisecondsSinceEpoch + (remainingSeconds * 1000);
          await prefs.setString(key, jsonEncode(data));
          await prefs.setInt(expiryKey, expiryTimestamp);
        }
      }
    } catch (e) {
      LoggerService.log('Failed to cache shop: $e', tag: 'ValorantApi');
    }
  }

  Future<void> clearShopCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
      (k) => k.startsWith('shop_cache_') || k.startsWith('shop_expiry_'),
    );
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  Future<Map<String, dynamic>> getStorefront({
    required String shard,
    required String puuid,
    required String accessToken,
    required String entitlementsToken,
  }) async {
    await _ensureOnline();
    final String clientVersion = await _getClientVersion();
    LoggerService.log(
      'Fetching Shop for User: $puuid ($shard)',
      tag: 'ValorantApi',
    );

    Future<Map<String, dynamic>> fetchWithVersion(
      String version, {
      String? host,
    }) async {
      final String activeHost = host ?? 'pd.$shard.a.pvp.net';
      final Uri url = Uri.parse(
        'https://$activeHost/store/$version/storefront/$puuid',
      );

      final Map<String, String> headers = {
        'X-Riot-Entitlements-JWT': entitlementsToken,
        'Authorization': 'Bearer $accessToken',
        'X-Riot-ClientPlatform': _clientPlatform,
        'X-Riot-ClientVersion': clientVersion,
        'Content-Type': 'application/json',
        'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
      };

      final response = version == 'v3'
          ? await http.post(url, headers: headers, body: '{}')
          : await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Your Riot session has expired. Please login again.');
      } else if (response.statusCode == 404) {
        if (version == 'v2') return fetchWithVersion('v1', host: host);
        if (version == 'v1') return fetchWithVersion('v3', host: host);
        if (version == 'v3' && host == null) {
          final String glzRegion = _getGlzRegion(shard);
          return fetchWithVersion(
            'v2',
            host: 'glz-$glzRegion-1.$shard.a.pvp.net',
          );
        }
      }
      throw Exception(
        'Failed to load storefront ($version): ${response.statusCode}',
      );
    }

    return fetchWithVersion('v2');
  }

  Future<Map<String, int>> fetchWallet({
    required String shard,
    required String puuid,
    required String accessToken,
    required String entitlementsToken,
  }) async {
    final String clientVersion = await _getClientVersion();
    final Uri url = Uri.parse(
      'https://pd.$shard.a.pvp.net/store/v1/wallet/$puuid',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
    };

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final balances = data['Balances'] as Map<String, dynamic>;
      return balances.map((key, value) => MapEntry(key, value as int));
    } else if (response.statusCode == 401) {
      throw Exception('Riot session expired while fetching wallet.');
    } else {
      throw Exception('Failed to load wallet: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> _fetchHenrikAccount(String puuid) async {
    try {
      final uri = Uri.parse(
        'https://api.henrikdev.xyz/valorant/v1/by-puuid/account/$puuid',
      );
      final response = await http.get(uri, headers: _henrikHeaders);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 200 || json['status'] == 1) {
          return json['data'];
        }
      }
      LoggerService.log(
        'Henrik API returned status ${response.statusCode}: ${response.body}',
        tag: 'ValorantApi',
      );
    } catch (e) {
      LoggerService.log(
        'Error fetching from Henrik API: $e',
        tag: 'ValorantApi',
      );
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchHenrikAccount(String puuid) async {
    return _fetchHenrikAccount(puuid);
  }

  Future<Map<String, dynamic>?> fetchHenrikAccountByNameAndTag(
    String name,
    String tag,
  ) async {
    try {
      final uri = Uri.parse(
        'https://api.henrikdev.xyz/valorant/v1/account/'
        '${Uri.encodeComponent(name)}/${Uri.encodeComponent(tag)}',
      );
      final response = await http.get(uri, headers: _henrikHeaders);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 200 ||
            json['status'] == 1 ||
            json['data'] != null) {
          return json['data'];
        }
      }
      LoggerService.log(
        'Henrik API (by name) returned status ${response.statusCode}: ${response.body}',
        tag: 'ValorantApi',
      );
    } catch (e) {
      LoggerService.log(
        'Error fetching from Henrik API by name: $e',
        tag: 'ValorantApi',
      );
    }
    return null;
  }

  static Future<List<dynamic>?> fetchHenrikMatches(
    String region,
    String puuid, {
    int size = 5,
  }) async {
    try {
      final uri = Uri.parse(
        'https://api.henrikdev.xyz/valorant/v3/by-puuid/matches/$region/$puuid?size=$size',
      );
      final response = await http.get(uri, headers: _henrikHeaders);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 200 || json['status'] == 1) {
          return json['data'] as List<dynamic>;
        }
      }
      LoggerService.log(
        'Henrik matches API returned status ${response.statusCode}: ${response.body}',
        tag: 'ValorantApi',
      );
    } catch (e) {
      LoggerService.log(
        'Error fetching matches from Henrik API: $e',
        tag: 'ValorantApi',
      );
    }
    return null;
  }

  Future<Map<String, dynamic>?> getMatchHistory({
    required String shard,
    required String puuid,
    required String accessToken,
    required String entitlementsToken,
    int startIndex = 0,
    int endIndex = 20,
    String? queue,
  }) async {
    final String clientVersion = await _getClientVersion();

    final queryParams = [
      'startIndex=$startIndex',
      'endIndex=$endIndex',
      if (queue != null && queue.isNotEmpty) 'queue=$queue',
    ].join('&');

    final Uri url = Uri.parse(
      'https://pd.$shard.a.pvp.net/match-history/v1/history/$puuid?$queryParams',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'Content-Type': 'application/json',
      'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
    };

    final response = await _getWithRetry(
      url,
      headers: headers,
      requestName: 'getMatchHistory',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getMatchDetails({
    required String shard,
    required String matchId,
    required String accessToken,
    required String entitlementsToken,
  }) async {
    final String clientVersion = await _getClientVersion();
    final Uri url = Uri.parse(
      'https://pd.$shard.a.pvp.net/match-details/v1/matches/$matchId',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'Content-Type': 'application/json',
      'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
    };

    final response = await _getWithRetry(
      url,
      headers: headers,
      requestName: 'getMatchDetails',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  String _normalizeShard(String shard) {
    String validShard = shard.toLowerCase().trim();
    if (validShard == 'as' || validShard == 'asia') validShard = 'ap';
    if (validShard == 'ko') validShard = 'kr';
    if (validShard == 'latam' || validShard == 'br') validShard = 'na';
    if (validShard.isEmpty) validShard = 'ap';
    return validShard;
  }

  Future<http.Response> _getWithRetry(
    Uri url, {
    required Map<String, String> headers,
    int maxRetries = 3,
    String requestName = 'API Request',
  }) async {
    await _ensureOnline();
    int attempts = 0;
    while (attempts < maxRetries) {
      attempts++;
      try {
        final response = await http.get(url, headers: headers);
        if (response.statusCode != 500) {
          return response;
        }
        LoggerService.log(
          '$requestName failed with 500 on attempt $attempts. Retrying...',
          tag: 'ValorantApi',
        );
      } catch (e) {
        LoggerService.log(
          '$requestName failed with error: $e on attempt $attempts. Retrying...',
          tag: 'ValorantApi',
        );
        if (attempts >= maxRetries) {
          rethrow;
        }
      }
      if (attempts < maxRetries) {
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
    return http.get(url, headers: headers);
  }

  Future<Map<String, dynamic>> getAccountXp({
    required String shard,
    required String puuid,
    required String accessToken,
    required String entitlementsToken,
  }) async {
    final String clientVersion = await _getClientVersion();
    final String validShard = _normalizeShard(shard);
    final Uri url = Uri.parse(
      'https://pd.$validShard.a.pvp.net/account-xp/v1/players/$puuid',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'Content-Type': 'application/json',
      'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
    };

    LoggerService.log(
      'Fetching Account XP for PUUID: $puuid on shard: $validShard (URL: $url)',
      tag: 'ValorantApi',
    );

    final response = await _getWithRetry(
      url,
      headers: headers,
      requestName: 'getAccountXp',
    );

    LoggerService.log(
      'getAccountXp response status: ${response.statusCode}',
      tag: 'ValorantApi',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      LoggerService.log(
        'getAccountXp response error: status=${response.statusCode}, body=${response.body}',
        tag: 'ValorantApi',
      );
      throw Exception('Failed to load account XP: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getContracts({
    required String shard,
    required String puuid,
    required String accessToken,
    required String entitlementsToken,
  }) async {
    final String clientVersion = await _getClientVersion();
    final String validShard = _normalizeShard(shard);
    final Uri url = Uri.parse(
      'https://pd.$validShard.a.pvp.net/contracts/v1/contracts/$puuid',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'Content-Type': 'application/json',
      'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
    };

    LoggerService.log(
      'Fetching Contracts for PUUID: $puuid on shard: $validShard (URL: $url)',
      tag: 'ValorantApi',
    );

    final response = await _getWithRetry(
      url,
      headers: headers,
      requestName: 'getContracts',
    );

    LoggerService.log(
      'getContracts response status: ${response.statusCode}',
      tag: 'ValorantApi',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      LoggerService.log(
        'getContracts response error: status=${response.statusCode}, body=${response.body}',
        tag: 'ValorantApi',
      );
      throw Exception('Failed to load contracts: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getPenalties({
    required String shard,
    required String puuid,
    required String accessToken,
    required String entitlementsToken,
  }) async {
    final String clientVersion = await _getClientVersion();
    final String validShard = _normalizeShard(shard);
    final Uri url = Uri.parse(
      'https://pd.$validShard.a.pvp.net/restrictions/v3/penalties',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'Content-Type': 'application/json',
      'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
    };

    LoggerService.log(
      'Fetching penalties on shard: $validShard (URL: $url)',
      tag: 'ValorantApi',
    );

    final response = await _getWithRetry(
      url,
      headers: headers,
      requestName: 'getPenalties',
    );

    LoggerService.log(
      'getPenalties response status: ${response.statusCode}',
      tag: 'ValorantApi',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      LoggerService.log(
        'getPenalties response error: status=${response.statusCode}, body=${response.body}',
        tag: 'ValorantApi',
      );
      throw Exception('Failed to load penalties: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getMMR({
    required String shard,
    required String puuid,
    required String accessToken,
    required String entitlementsToken,
  }) async {
    final String clientVersion = await _getClientVersion();
    final Uri url = Uri.parse(
      'https://pd.$shard.a.pvp.net/mmr/v1/players/$puuid',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
    };

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      return {};
    } else {
      throw Exception('Failed to load MMR: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> getCompetitiveUpdates({
    required String shard,
    required String puuid,
    required String accessToken,
    required String entitlementsToken,
    int startIndex = 0,
    int endIndex = 20,
    String? queue,
  }) async {
    int safeEndIndex = endIndex;
    if (safeEndIndex - startIndex > 15) {
      safeEndIndex = startIndex + 15;
    }
    final String clientVersion = await _getClientVersion();
    final Uri url =
        Uri.parse(
          'https://pd.$shard.a.pvp.net/mmr/v1/players/$puuid/competitiveupdates',
        ).replace(
          queryParameters: {
            'startIndex': '$startIndex',
            'endIndex': '$safeEndIndex',
            if (queue != null && queue.isNotEmpty) 'queue': queue,
          },
        );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
    };

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return (decoded['Matches'] ?? decoded['matches'] ?? []) as List<dynamic>;
    } else if (response.statusCode == 404) {
      return [];
    } else {
      LoggerService.log(
        'getCompetitiveUpdates failed: status=${response.statusCode} url=$url body=${response.body}',
        tag: 'ValorantApi',
      );
      throw Exception(
        'Failed to load competitive updates: ${response.statusCode}',
      );
    }
  }

  Future<Map<String, dynamic>> getLeaderboard({
    required String shard,
    required String accessToken,
    required String entitlementsToken,
    required String seasonId,
    int size = 100,
    int startIndex = 0,
    String? query,
  }) async {
    final String clientVersion = await _getClientVersion();
    final Uri url =
        Uri.parse(
          'https://pd.$shard.a.pvp.net/mmr/v1/leaderboards/affinity/$shard/queue/competitive/season/$seasonId',
        ).replace(
          queryParameters: {
            'size': '$size',
            'startIndex': '$startIndex',
            if (query != null && query.isNotEmpty) 'query': query,
          },
        );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
    };

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      return {};
    } else {
      throw Exception('Failed to load leaderboard: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>?> getHenrikMMR(
    String region,
    String puuid,
  ) async {
    try {
      final uri = Uri.parse(
        'https://api.henrikdev.xyz/valorant/v2/by-puuid/mmr/$region/$puuid',
      );
      final response = await http.get(uri, headers: _henrikHeaders);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 200 || json['status'] == 1) {
          return json['data'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<dynamic>?> getHenrikMMRHistory(
    String region,
    String puuid,
  ) async {
    try {
      final uri = Uri.parse(
        'https://api.henrikdev.xyz/valorant/v1/by-puuid/mmr-history/$region/$puuid',
      );
      final response = await http.get(uri, headers: _henrikHeaders);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 200 || json['status'] == 1) {
          return json['data'] as List<dynamic>?;
        }
      }
      LoggerService.log(
        'Henrik MMR history API returned status ${response.statusCode}: ${response.body}',
        tag: 'ValorantApi',
      );
    } catch (e) {
      LoggerService.log(
        'Error fetching MMR history from Henrik API: $e',
        tag: 'ValorantApi',
      );
    }
    return null;
  }

  String _getGlzRegion(String region) {
    final r = region.toLowerCase();
    if (r == 'ap' || r == 'as') return 'ap';
    if (r == 'kr' || r == 'ko') return 'kr';
    return r;
  }

  Future<String?> getCurrentPartyId(
    String puuid,
    String accessToken,
    String entitlementsToken,
    String region,
    String shard,
  ) async {
    try {
      final String clientVersion = await _getClientVersion();
      final String glzRegion = _getGlzRegion(region);
      final Uri url = Uri.parse(
        'https://glz-$glzRegion-1.$shard.a.pvp.net/parties/v1/players/$puuid',
      );

      final Map<String, String> headers = {
        'X-Riot-Entitlements-JWT': entitlementsToken,
        'Authorization': 'Bearer $accessToken',
        'X-Riot-ClientPlatform': _clientPlatform,
        'X-Riot-ClientVersion': clientVersion,
        'Content-Type': 'application/json',
        'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
      };

      final response = await http.get(url, headers: headers);

      LoggerService.log(
        'GET CurrentPartyId -> $url [${response.statusCode}] body: ${response.body}',
        tag: 'PartyAPI',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['CurrentPartyID'];
      } else {
        LoggerService.log(
          'Failed to load Party ID: ${response.statusCode} (body: ${response.body})',
          tag: 'ValorantApi',
        );
        return null;
      }
    } catch (e) {
      LoggerService.log('Error getting party ID: $e', tag: 'ValorantApi');
      return null;
    }
  }

  Future<Map<String, dynamic>> getPartyDetails(
    String partyId,
    String accessToken,
    String entitlementsToken,
    String region,
    String shard,
  ) async {
    final String clientVersion = await _getClientVersion();
    final String glzRegion = _getGlzRegion(region);
    final Uri url = Uri.parse(
      'https://glz-$glzRegion-1.$shard.a.pvp.net/parties/v1/parties/$partyId',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'Content-Type': 'application/json',
      'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
    };

    final response = await http.get(url, headers: headers);

    LoggerService.log(
      'GET PartyDetails -> $url [${response.statusCode}] body: ${response.body}',
      tag: 'PartyAPI',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load Party Details: ${response.statusCode}');
    }
  }

  Future<void> setReady(
    String partyId,
    String puuid,
    bool ready,
    String accessToken,
    String entitlementsToken,
    String region,
    String shard,
  ) async {
    final String clientVersion = await _getClientVersion();
    final String glzRegion = _getGlzRegion(region);
    final Uri url = Uri.parse(
      'https://glz-$glzRegion-1.$shard.a.pvp.net/parties/v1/parties/$partyId/members/$puuid/setReady',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'Content-Type': 'application/json',
      'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
    };

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({'ready': ready}),
    );

    LoggerService.log(
      'POST SetReady($ready) -> $url [${response.statusCode}] body: ${response.body}',
      tag: 'PartyAPI',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to set ready status: ${response.statusCode} (body: ${response.body})',
      );
    }
  }

  Future<void> changeQueue(
    String partyId,
    String queueId,
    String accessToken,
    String entitlementsToken,
    String region,
    String shard,
  ) async {
    final String clientVersion = await _getClientVersion();
    final String glzRegion = _getGlzRegion(region);
    final Uri url = Uri.parse(
      'https://glz-$glzRegion-1.$shard.a.pvp.net/parties/v1/parties/$partyId/queue',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'Content-Type': 'application/json',
      'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
    };

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({'queueId': queueId}),
    );

    LoggerService.log(
      'POST ChangeQueue($queueId) -> $url [${response.statusCode}] body: ${response.body}',
      tag: 'PartyAPI',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to change queue: ${response.statusCode} (body: ${response.body})',
      );
    }
  }

  Future<void> enterMatchmaking(
    String partyId,
    String accessToken,
    String entitlementsToken,
    String region,
    String shard,
  ) async {
    final String clientVersion = await _getClientVersion();
    final String glzRegion = _getGlzRegion(region);
    final Uri url = Uri.parse(
      'https://glz-$glzRegion-1.$shard.a.pvp.net/parties/v1/parties/$partyId/matchmaking/join',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'Content-Type': 'application/json',
      'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
    };

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({}),
    );

    LoggerService.log(
      'POST EnterMatchmaking -> $url [${response.statusCode}] body: ${response.body}',
      tag: 'PartyAPI',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to enter matchmaking: ${response.statusCode} (body: ${response.body})',
      );
    }
  }

  Future<void> leaveMatchmaking(
    String partyId,
    String accessToken,
    String entitlementsToken,
    String region,
    String shard,
  ) async {
    final String clientVersion = await _getClientVersion();
    final String glzRegion = _getGlzRegion(region);
    final Uri url = Uri.parse(
      'https://glz-$glzRegion-1.$shard.a.pvp.net/parties/v1/parties/$partyId/matchmaking/leave',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'Content-Type': 'application/json',
      'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
    };

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({}),
    );

    LoggerService.log(
      'POST LeaveMatchmaking -> $url [${response.statusCode}] body: ${response.body}',
      tag: 'PartyAPI',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to leave matchmaking: ${response.statusCode} (body: ${response.body})',
      );
    }
  }

  Future<List<dynamic>> getPlayersNames(
    List<String> puuids,
    String accessToken,
    String entitlementsToken,
    String shard,
  ) async {
    final String clientVersion = await _getClientVersion();
    final Uri url = Uri.parse(
      'https://pd.$shard.a.pvp.net/name-service/v2/players',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'Content-Type': 'application/json',
    };

    final response = await http.put(
      url,
      headers: headers,
      body: jsonEncode(puuids),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load Players Names: ${response.statusCode}');
    }
  }

  static Future<List<dynamic>> getCompetitiveTiers() async {
    final res = await http.get(
      Uri.parse('https://valorant-api.com/v1/competitivetiers'),
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      return json['data'];
    } else {
      throw Exception('Failed to load competitive tiers');
    }
  }

  static Future<List<dynamic>> getSeasons() async {
    final res = await http.get(
      Uri.parse('https://valorant-api.com/v1/seasons'),
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      return json['data'];
    } else {
      throw Exception('Failed to load seasons');
    }
  }

  static Future<List<dynamic>> getTitles() async {
    final res = await http.get(
      Uri.parse('https://valorant-api.com/v1/playertitles'),
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      return json['data'];
    } else {
      throw Exception('Failed to load titles');
    }
  }

  static String? _discoveredLoadoutShard;

  Future<Map<String, dynamic>> getPlayerLoadout(
    String puuid,
    String shard,
    String accessToken,
    String entitlementsToken,
  ) async {
    final String clientVersion = await _getClientVersion();

    String validShard = _discoveredLoadoutShard ?? shard.toLowerCase().trim();
    if (validShard == 'as' || validShard == 'asia') validShard = 'ap';
    if (validShard == 'ko') validShard = 'kr';
    if (validShard == 'latam' || validShard == 'br') validShard = 'na';
    if (validShard.isEmpty) validShard = 'ap';

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken.trim(),
      'Authorization': 'Bearer ${accessToken.trim()}',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
    };

    Future<http.Response> requestShard(String targetShard, String version) {
      final targetUrl = Uri.parse(
        'https://pd.$targetShard.a.pvp.net/personalization/$version/players/${puuid.trim()}/playerloadout',
      );
      LoggerService.log(
        'GET PlayerLoadout ($version) -> $targetUrl [PUUID=${puuid.trim()}, Shard=$targetShard]',
        tag: 'ValorantApi',
      );
      return http.get(targetUrl, headers: headers);
    }

    final candidateShards = [
      validShard,
      ...['ap', 'eu', 'kr', 'na', 'pbe'].where((s) => s != validShard),
    ];

    for (final version in ['v3', 'v2']) {
      for (final targetShard in candidateShards) {
        try {
          final response = await requestShard(targetShard, version);
          LoggerService.log(
            'GET PlayerLoadout Response ($targetShard, $version): status=${response.statusCode}, body=${response.body}',
            tag: 'ValorantApi',
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final guns = data['Guns'] as List<dynamic>?;
            if (guns != null && guns.isNotEmpty) {
              _discoveredLoadoutShard = targetShard;
              LoggerService.log(
                'Active populated loadout discovered ($version) on shard: $targetShard (Guns: ${guns.length}, geo: $validShard)',
                tag: 'ValorantApi',
              );
              return data;
            }
          }
        } catch (e) {
          LoggerService.log(
            'Error requesting loadout ($version) on $targetShard: $e',
            tag: 'ValorantApi',
          );
        }
      }
    }

    throw Exception(
      'Failed to load player loadout across all shards and API versions',
    );
  }

  Future<void> updatePlayerLoadout(
    String puuid,
    String shard,
    String accessToken,
    String entitlementsToken,
    Map<String, dynamic> loadout,
  ) async {
    final String clientVersion = await _getClientVersion();

    String validShard = _discoveredLoadoutShard ?? shard.toLowerCase().trim();
    if (validShard == 'as' || validShard == 'asia') validShard = 'ap';
    if (validShard == 'ko') validShard = 'kr';
    if (validShard == 'latam' || validShard == 'br') validShard = 'na';
    if (validShard.isEmpty) validShard = 'ap';

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken.trim(),
      'Authorization': 'Bearer ${accessToken.trim()}',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'Content-Type': 'application/json',
    };

    Future<http.Response> putShard(String targetShard, String version) {
      final targetUrl = Uri.parse(
        'https://pd.$targetShard.a.pvp.net/personalization/$version/players/${puuid.trim()}/playerloadout',
      );
      LoggerService.log(
        'PUT PlayerLoadout ($version) -> $targetUrl [PUUID=${puuid.trim()}, Shard=$targetShard]',
        tag: 'ValorantApi',
      );
      return http.put(targetUrl, headers: headers, body: jsonEncode(loadout));
    }

    for (final version in ['v3', 'v2']) {
      final response = await putShard(validShard, version);
      if (response.statusCode == 200) {
        return;
      }
    }

    throw Exception('Failed to update player loadout');
  }

  Future<List<dynamic>> getEntitlements(
    String puuid,
    String shard,
    String accessToken,
    String entitlementsToken,
    String itemTypeId,
  ) async {
    final String clientVersion = await _getClientVersion();
    final Uri url = Uri.parse(
      'https://pd.$shard.a.pvp.net/store/v1/entitlements/$puuid/$itemTypeId',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
    };

    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['Entitlements'] ?? [];
    } else {
      throw Exception('Failed to load entitlements: ${response.statusCode}');
    }
  }

  static const String _friendNameCacheKey = 'friend_name_cache_v1';
  static const Duration _friendNameCacheTtl = Duration(days: 1);

  Future<void> clearFriendNameCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_friendNameCacheKey);
  }

  Future<Map<String, Map<String, String>>> fetchNamesByPuuids(
    List<String> puuids,
    String shard,
    String accessToken,
    String entitlementsToken,
  ) async {
    if (puuids.isEmpty) return {};

    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> cache = {};
    try {
      final raw = prefs.getString(_friendNameCacheKey);
      if (raw != null && raw.isNotEmpty) {
        cache = jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (e) {
      LoggerService.log(
        'Failed to read friend name cache: $e',
        tag: 'ValorantApi',
      );
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final Map<String, Map<String, String>> result = {};
    final List<String> needsFetch = [];

    for (final puuid in puuids) {
      final entry = cache[puuid];
      if (entry is Map) {
        final cachedAt = entry['cachedAt'] as int? ?? 0;
        final gameName = entry['gameName'] as String? ?? '';
        if (gameName.isNotEmpty &&
            nowMs - cachedAt < _friendNameCacheTtl.inMilliseconds) {
          result[puuid] = {
            'gameName': gameName,
            'tagline': entry['tagline'] as String? ?? '',
          };
          continue;
        }
      }
      needsFetch.add(puuid);
    }

    if (needsFetch.isEmpty) {
      return result;
    }

    final fresh = await _fetchNamesByPuuidsUncached(
      needsFetch,
      shard,
      accessToken,
      entitlementsToken,
    );

    fresh.forEach((puuid, info) {
      result[puuid] = info;
      cache[puuid] = {
        'gameName': info['gameName'],
        'tagline': info['tagline'],
        'cachedAt': nowMs,
      };
    });

    try {
      await prefs.setString(_friendNameCacheKey, jsonEncode(cache));
    } catch (e) {
      LoggerService.log(
        'Failed to persist friend name cache: $e',
        tag: 'ValorantApi',
      );
    }

    return result;
  }

  Future<Map<String, Map<String, String>>> _fetchNamesByPuuidsUncached(
    List<String> puuids,
    String shard,
    String accessToken,
    String entitlementsToken,
  ) async {
    if (puuids.isEmpty) return {};
    String validShard = shard.toLowerCase();
    if (validShard == 'asia') validShard = 'ap';
    if (validShard == 'latam' || validShard == 'br') validShard = 'na';

    final Map<String, Map<String, String>> result = {};

    try {
      final String clientVersion = await _getClientVersion();
      final Uri url = Uri.parse(
        'https://pd.$validShard.a.pvp.net/name-service/v2/players',
      );
      final Map<String, String> headers = {
        'X-Riot-Entitlements-JWT': entitlementsToken,
        'Authorization': 'Bearer $accessToken',
        'X-Riot-ClientPlatform': _clientPlatform,
        'X-Riot-ClientVersion': clientVersion,
        'Content-Type': 'application/json',
      };
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(puuids),
      );
      LoggerService.log(
        'Name-service response code: ${response.statusCode} for url $url',
        tag: 'ValorantApi',
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        for (final item in data) {
          final puuid = item['Subject'] ?? item['puuid'] ?? '';
          final name = item['GameName'] ?? item['game_name'] ?? '';
          final tagline = item['TagLine'] ?? item['tag_line'] ?? '';
          if (puuid.isNotEmpty && name.isNotEmpty) {
            result[puuid] = {'gameName': name, 'tagline': tagline};
          }
        }
      }
    } catch (e) {
      LoggerService.log(
        'Failed to resolve names via Riot API: $e',
        tag: 'ValorantApi',
      );
    }

    for (final puuid in puuids) {
      if (!result.containsKey(puuid) || result[puuid]!['gameName']!.isEmpty) {
        try {
          final hUrl = Uri.parse(
            'https://api.henrikdev.xyz/valorant/v1/by-puuid/account/$puuid',
          );
          final hRes = await http.get(hUrl, headers: _henrikHeaders);
          if (hRes.statusCode == 200) {
            final hJson = jsonDecode(hRes.body);
            final data = hJson['data'];
            if (data != null) {
              final name = data['name'] ?? '';
              final tag = data['tag'] ?? '';
              if (name.toString().isNotEmpty) {
                result[puuid] = {
                  'gameName': name.toString(),
                  'tagline': tag.toString(),
                };
              }
            }
          }
        } catch (_) {}
      }
    }

    return result;
  }

  Future<Map<String, dynamic>?> fetchPlayerParty(
    String puuid,
    String shard,
    String accessToken,
    String entitlementsToken,
  ) async {
    String validShard = shard.toLowerCase();
    if (validShard == 'asia') validShard = 'ap';
    if (validShard == 'latam' || validShard == 'br') validShard = 'na';

    try {
      final String clientVersion = await _getClientVersion();
      final Map<String, String> headers = {
        'X-Riot-Entitlements-JWT': entitlementsToken,
        'Authorization': 'Bearer $accessToken',
        'X-Riot-ClientPlatform': _clientPlatform,
        'X-Riot-ClientVersion': clientVersion,
      };

      final Uri playerPartyUrl = Uri.parse(
        'https://parties.$validShard.a.pvp.net/parties/v1/players/$puuid',
      );
      final playerPartyRes = await http.get(playerPartyUrl, headers: headers);
      if (playerPartyRes.statusCode != 200) {
        LoggerService.log(
          'Fetch player party error: ${playerPartyRes.statusCode}',
          tag: 'ValorantApi',
        );
        return null;
      }

      final playerPartyJson = jsonDecode(playerPartyRes.body);
      final partyId = playerPartyJson['CurrentPartyID'];
      if (partyId == null || partyId.isEmpty) return null;

      final Uri partyDetailsUrl = Uri.parse(
        'https://parties.$validShard.a.pvp.net/parties/v1/parties/$partyId',
      );
      final partyRes = await http.get(partyDetailsUrl, headers: headers);
      if (partyRes.statusCode == 200) {
        return jsonDecode(partyRes.body);
      }
    } catch (e) {
      LoggerService.log('Error fetching party details: $e', tag: 'ValorantApi');
    }
    return null;
  }

  Future<void> setAccessibility(
    String partyId,
    String accessibility,
    String accessToken,
    String entitlementsToken,
    String region,
    String shard,
  ) async {
    final String clientVersion = await _getClientVersion();
    final String glzRegion = _getGlzRegion(region);
    final Uri url = Uri.parse(
      'https://glz-$glzRegion-1.$shard.a.pvp.net/parties/v1/parties/$partyId/accessibility',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'Content-Type': 'application/json',
      'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
    };

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({'accessibility': accessibility}),
    );

    LoggerService.log(
      'POST SetAccessibility($accessibility) -> $url [${response.statusCode}] body: ${response.body}',
      tag: 'PartyAPI',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to set accessibility: ${response.statusCode} (body: ${response.body})',
      );
    }
  }

  Future<Map<String, dynamic>> makeCode(
    String partyId,
    String accessToken,
    String entitlementsToken,
    String region,
    String shard,
  ) async {
    final String clientVersion = await _getClientVersion();
    final String glzRegion = _getGlzRegion(region);
    final Uri url = Uri.parse(
      'https://glz-$glzRegion-1.$shard.a.pvp.net/parties/v1/parties/$partyId/invitecode',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'Content-Type': 'application/json',
      'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
    };

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({}),
    );

    LoggerService.log(
      'POST MakeCode -> $url [${response.statusCode}] body: ${response.body}',
      tag: 'PartyAPI',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to make code: ${response.statusCode} (body: ${response.body})',
      );
    }
    return jsonDecode(response.body);
  }

  Future<void> revokeCode(
    String partyId,
    String accessToken,
    String entitlementsToken,
    String region,
    String shard,
  ) async {
    final String clientVersion = await _getClientVersion();
    final String glzRegion = _getGlzRegion(region);
    final Uri url = Uri.parse(
      'https://glz-$glzRegion-1.$shard.a.pvp.net/parties/v1/parties/$partyId/invitecode',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
    };

    final response = await http.delete(url, headers: headers);

    LoggerService.log(
      'DELETE RevokeCode -> $url [${response.statusCode}] body: ${response.body}',
      tag: 'PartyAPI',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to revoke code: ${response.statusCode} (body: ${response.body})',
      );
    }
  }

  Future<void> setPreferredGamePods(
    String partyId,
    List<String> preferredGamePods,
    String accessToken,
    String entitlementsToken,
    String region,
    String shard,
  ) async {
    final String clientVersion = await _getClientVersion();
    final String glzRegion = _getGlzRegion(region);
    final Uri url = Uri.parse(
      'https://glz-$glzRegion-1.$shard.a.pvp.net/parties/v1/parties/$partyId/preferredgamepods',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'Content-Type': 'application/json',
      'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
    };

    final requestBody = jsonEncode({'GamePodIDs': preferredGamePods});
    LoggerService.log(
      'POST SetPreferredGamePods -> $url request: $requestBody',
      tag: 'PartyAPI',
    );

    final response = await http.post(url, headers: headers, body: requestBody);

    LoggerService.log(
      'POST SetPreferredGamePods -> $url [${response.statusCode}] body: ${response.body}',
      tag: 'PartyAPI',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to set preferred game pods: ${response.statusCode} (body: ${response.body})',
      );
    }
  }

  Future<Map<String, dynamic>> inviteToPartyByName(
    String partyId,
    String name,
    String tag,
    String accessToken,
    String entitlementsToken,
    String region,
    String shard,
  ) async {
    final String clientVersion = await _getClientVersion();
    final String glzRegion = _getGlzRegion(region);
    final Uri url = Uri.parse(
      'https://glz-$glzRegion-1.$shard.a.pvp.net/parties/v1/parties/$partyId/invites/name/$name/tag/$tag',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'Content-Type': 'application/json',
      'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
    };

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({}),
    );

    LoggerService.log(
      'POST InviteToPartyByName($name#$tag) -> $url [${response.statusCode}] body: ${response.body}',
      tag: 'PartyAPI',
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
        'Failed to invite player: ${response.statusCode} (body: ${response.body})',
      );
    }
    return response.body.isNotEmpty ? jsonDecode(response.body) : {};
  }

  Future<Map<String, dynamic>> getCustomGameConfigs(
    String accessToken,
    String entitlementsToken,
    String region,
    String shard,
  ) async {
    final String clientVersion = await _getClientVersion();
    final String glzRegion = _getGlzRegion(region);
    final Uri url = Uri.parse(
      'https://glz-$glzRegion-1.$shard.a.pvp.net/parties/v1/parties/customgameconfigs',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
    };

    final response = await http.get(url, headers: headers);

    LoggerService.log(
      'GET CustomGameConfigs -> $url [${response.statusCode}] body: ${response.body}',
      tag: 'PartyAPI',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load custom game configs: ${response.statusCode} (body: ${response.body})',
      );
    }
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getGameModes() async {
    final res = await http.get(
      Uri.parse('https://valorant-api.com/v1/gamemodes'),
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      return json['data'] as List<dynamic>? ?? [];
    } else {
      throw Exception('Failed to load game modes: ${res.statusCode}');
    }
  }

  static List<dynamic>? _cachedAgents;
  static List<dynamic>? _cachedMaps;

  static Future<List<dynamic>> getAgents() async {
    if (_cachedAgents != null && _cachedAgents!.isNotEmpty) {
      return _cachedAgents!;
    }
    try {
      final res = await http
          .get(
            Uri.parse(
              'https://valorant-api.com/v1/agents?isPlayableCharacter=true',
            ),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        _cachedAgents = json['data'] as List<dynamic>? ?? [];
        return _cachedAgents!;
      }
    } catch (e) {
      LoggerService.log(
        'Failed to fetch static agents: $e',
        tag: 'ValorantApi',
      );
    }
    return _cachedAgents ?? [];
  }

  static Future<List<dynamic>> getMaps() async {
    if (_cachedMaps != null && _cachedMaps!.isNotEmpty) {
      return _cachedMaps!;
    }
    try {
      final res = await http
          .get(Uri.parse('https://valorant-api.com/v1/maps'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        _cachedMaps = json['data'] as List<dynamic>? ?? [];
        return _cachedMaps!;
      }
    } catch (e) {
      LoggerService.log('Failed to fetch static maps: $e', tag: 'ValorantApi');
    }
    return _cachedMaps ?? [];
  }

  Future<Map<String, dynamic>?> getPregamePlayer(
    String puuid,
    String accessToken,
    String entitlementsToken,
    String region,
    String shard,
  ) async {
    final String clientVersion = await _getClientVersion();
    final String glzRegion = _getGlzRegion(region);
    final Uri url = Uri.parse(
      'https://glz-$glzRegion-1.$shard.a.pvp.net/pregame/v1/players/$puuid',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'Content-Type': 'application/json',
      'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
    };

    final response = await http
        .get(url, headers: headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception(
        'Pregame player request failed with status: ${response.statusCode}',
      );
    }
  }

  Future<Map<String, dynamic>?> getPregameMatch(
    String matchId,
    String accessToken,
    String entitlementsToken,
    String region,
    String shard,
  ) async {
    final String clientVersion = await _getClientVersion();
    final String glzRegion = _getGlzRegion(region);
    final Uri url = Uri.parse(
      'https://glz-$glzRegion-1.$shard.a.pvp.net/pregame/v1/matches/$matchId',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'Content-Type': 'application/json',
      'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
    };

    final response = await http
        .get(url, headers: headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception(
        'Pregame match request failed with status: ${response.statusCode}',
      );
    }
  }

  Future<Map<String, dynamic>?> getCurrentGamePlayer(
    String puuid,
    String accessToken,
    String entitlementsToken,
    String region,
    String shard,
  ) async {
    final String clientVersion = await _getClientVersion();
    final String glzRegion = _getGlzRegion(region);
    final Uri url = Uri.parse(
      'https://glz-$glzRegion-1.$shard.a.pvp.net/core-game/v1/players/$puuid',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'Content-Type': 'application/json',
      'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
    };

    final response = await http
        .get(url, headers: headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception(
        'Core-game player request failed with status: ${response.statusCode}',
      );
    }
  }

  Future<Map<String, dynamic>?> getCurrentGameMatch(
    String matchId,
    String accessToken,
    String entitlementsToken,
    String region,
    String shard,
  ) async {
    final String clientVersion = await _getClientVersion();
    final String glzRegion = _getGlzRegion(region);
    final Uri url = Uri.parse(
      'https://glz-$glzRegion-1.$shard.a.pvp.net/core-game/v1/matches/$matchId',
    );

    final Map<String, String> headers = {
      'X-Riot-Entitlements-JWT': entitlementsToken,
      'Authorization': 'Bearer $accessToken',
      'X-Riot-ClientPlatform': _clientPlatform,
      'X-Riot-ClientVersion': clientVersion,
      'Content-Type': 'application/json',
      'User-Agent': 'ShooterGame/13 Windows/10.0.22621.1.256.64bit',
    };

    final response = await http
        .get(url, headers: headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception(
        'Core-game match request failed with status: ${response.statusCode}',
      );
    }
  }
}

extension StringExtension on String {
  String take(int n) => length <= n ? this : substring(0, n);
}
