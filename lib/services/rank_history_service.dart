import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_thunai/models/rank_history_entry.dart';
import 'package:valorant_thunai/services/logger_service.dart';

class RankHistoryService {
  RankHistoryService._();

  static const int _maxEntries = 200;
  static const Duration _minGapBetweenEntries = Duration(hours: 1);

  static String _prefsKey(String puuid) => 'val_shop_rank_history_v1_$puuid';

  static Future<void> recordRank({
    required String puuid,
    required int tier,
    required int rr,
  }) async {
    if (puuid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _prefsKey(puuid);
      final entries = await _load(prefs, key);

      if (entries.isNotEmpty) {
        final last = entries.last;
        final sameRank = last.tier == tier && last.rr == rr;
        final tooSoon =
            DateTime.now().difference(last.timestamp) < _minGapBetweenEntries;
        if (sameRank && tooSoon) {
          return;
        }
      }

      entries.add(
        RankHistoryEntry(timestamp: DateTime.now(), tier: tier, rr: rr),
      );

      final trimmed = entries.length > _maxEntries
          ? entries.sublist(entries.length - _maxEntries)
          : entries;

      await prefs.setString(
        key,
        jsonEncode(trimmed.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      LoggerService.log('Error recording rank history: $e', tag: 'RankHistory');
    }
  }

  static Future<List<RankHistoryEntry>> getHistory(String puuid) async {
    if (puuid.isEmpty) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      return await _load(prefs, _prefsKey(puuid));
    } catch (e) {
      LoggerService.log('Error loading rank history: $e', tag: 'RankHistory');
      return [];
    }
  }

  static Future<List<RankHistoryEntry>> _load(
    SharedPreferences prefs,
    String key,
  ) async {
    final jsonStr = prefs.getString(key);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List decoded = jsonDecode(jsonStr);
      return decoded
          .map(
            (item) =>
                RankHistoryEntry.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (e) {
      LoggerService.log('Error parsing rank history: $e', tag: 'RankHistory');
      return [];
    }
  }
}
