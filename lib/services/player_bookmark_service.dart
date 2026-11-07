import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BookmarkedPlayer {
  final String puuid;
  final String gameName;
  final String tagline;
  final String region;
  final String playerCardId;

  BookmarkedPlayer({
    required this.puuid,
    required this.gameName,
    required this.tagline,
    required this.region,
    this.playerCardId = '',
  });

  Map<String, dynamic> toJson() => {
    'puuid': puuid,
    'gameName': gameName,
    'tagline': tagline,
    'region': region,
    'playerCardId': playerCardId,
  };

  factory BookmarkedPlayer.fromJson(Map<String, dynamic> json) =>
      BookmarkedPlayer(
        puuid: json['puuid']?.toString() ?? '',
        gameName: json['gameName']?.toString() ?? '',
        tagline: json['tagline']?.toString() ?? '',
        region: json['region']?.toString() ?? 'na',
        playerCardId: json['playerCardId']?.toString() ?? '',
      );
}

class PlayerBookmarkService {
  static const String _prefsKey = 'bookmarked_players_v1';

  static Future<List<BookmarkedPlayer>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey) ?? '[]';
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((e) => BookmarkedPlayer.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> isBookmarked(String puuid) async {
    if (puuid.isEmpty) return false;
    final all = await getAll();
    return all.any((p) => p.puuid == puuid);
  }

  static Future<void> add(BookmarkedPlayer player) async {
    if (player.puuid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final all = await getAll();
    all.removeWhere((p) => p.puuid == player.puuid);
    all.insert(0, player);
    await prefs.setString(
      _prefsKey,
      jsonEncode(all.map((p) => p.toJson()).toList()),
    );
  }

  static Future<void> remove(String puuid) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await getAll();
    all.removeWhere((p) => p.puuid == puuid);
    await prefs.setString(
      _prefsKey,
      jsonEncode(all.map((p) => p.toJson()).toList()),
    );
  }

  static Future<bool> toggle(BookmarkedPlayer player) async {
    final bookmarked = await isBookmarked(player.puuid);
    if (bookmarked) {
      await remove(player.puuid);
      return false;
    } else {
      await add(player);
      return true;
    }
  }
}
