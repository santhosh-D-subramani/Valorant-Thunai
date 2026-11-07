import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class FriendNameChange {
  final String gameName;
  final String tagline;
  final int timestamp;

  FriendNameChange({
    required this.gameName,
    required this.tagline,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'gameName': gameName,
    'tagline': tagline,
    'timestamp': timestamp,
  };

  factory FriendNameChange.fromJson(Map<String, dynamic> json) =>
      FriendNameChange(
        gameName: json['gameName']?.toString() ?? '',
        tagline: json['tagline']?.toString() ?? '',
        timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      );
}

class FriendNameCacheService {
  static const String _prefsKey = 'friend_name_cache_v1';
  static const int maxHistoryPerFriend = 5;

  static Future<Map<String, dynamic>> _readRaw(SharedPreferences prefs) async {
    final raw = prefs.getString(_prefsKey) ?? '{}';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeRaw(
    SharedPreferences prefs,
    Map<String, dynamic> raw,
  ) async {
    await prefs.setString(_prefsKey, jsonEncode(raw));
  }

  static Future<List<FriendNameChange>> resolve(
    String puuid,
    String gameName,
    String tagline,
  ) async {
    if (puuid.isEmpty || gameName.isEmpty) {
      return getHistory(puuid);
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = await _readRaw(prefs);
    final existing = raw[puuid] as Map<String, dynamic>?;

    if (existing == null) {
      raw[puuid] = {
        'gameName': gameName,
        'tagline': tagline,
        'history': <dynamic>[],
      };
      await _writeRaw(prefs, raw);
      return [];
    }

    final oldName = existing['gameName']?.toString() ?? '';
    final oldTag = existing['tagline']?.toString() ?? '';
    List<dynamic> historyJson = List<dynamic>.from(
      existing['history'] as List? ?? [],
    );

    final nameChanged =
        oldName.isNotEmpty && (oldName != gameName || oldTag != tagline);

    if (nameChanged) {
      historyJson.insert(0, {
        'gameName': oldName,
        'tagline': oldTag,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      if (historyJson.length > maxHistoryPerFriend) {
        historyJson = historyJson.sublist(0, maxHistoryPerFriend);
      }
    }

    if (nameChanged || oldName.isEmpty) {
      raw[puuid] = {
        'gameName': gameName,
        'tagline': tagline,
        'history': historyJson,
      };
      await _writeRaw(prefs, raw);
    }

    return historyJson
        .map((e) => FriendNameChange.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<List<FriendNameChange>> getHistory(String puuid) async {
    if (puuid.isEmpty) return [];
    final prefs = await SharedPreferences.getInstance();
    final raw = await _readRaw(prefs);
    final existing = raw[puuid] as Map<String, dynamic>?;
    if (existing == null) return [];
    final historyJson = List<dynamic>.from(existing['history'] as List? ?? []);
    return historyJson
        .map((e) => FriendNameChange.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
