import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'logger_service.dart';

class ShopHistoryEntry {
  final DateTime date;
  final List<String> skinIds;

  const ShopHistoryEntry({required this.date, required this.skinIds});
}

class ShopHistoryService {
  static const int _maxEntries = 90;

  static String _prefsKey(String puuid) => 'shop_history_v1_$puuid';

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<void> recordToday(
    String puuid,
    List<String> skinIds, {
    int? remainingSeconds,
  }) async {
    if (puuid.isEmpty || skinIds.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _prefsKey(puuid);
      final raw = prefs.getString(key);
      List<dynamic> list = [];
      if (raw != null && raw.isNotEmpty) {
        try {
          list = jsonDecode(raw) as List<dynamic>;
        } catch (_) {
          list = [];
        }
      }

      final rotationKey = _dateKey(_rotationDate(remainingSeconds));

      if (list.isNotEmpty && list.first is Map) {
        final head = list.first as Map;
        final previous = List<String>.from(head['skinIds'] ?? const []);

        if (_sameSkinSet(previous, skinIds)) return;

        if (head['date'] == rotationKey) {
          list[0] = {'date': rotationKey, 'skinIds': skinIds};
          await prefs.setString(key, jsonEncode(list));
          return;
        }
      }

      list.insert(0, {'date': rotationKey, 'skinIds': skinIds});
      if (list.length > _maxEntries) {
        list = list.sublist(0, _maxEntries);
      }
      await prefs.setString(key, jsonEncode(list));
    } catch (e) {
      LoggerService.log(
        'Failed to record shop history: $e',
        tag: 'ShopHistory',
      );
    }
  }

  static DateTime _rotationDate(int? remainingSeconds) {
    final now = DateTime.now();
    if (remainingSeconds == null || remainingSeconds <= 0) return now;
    final rotationEnd = now.add(Duration(seconds: remainingSeconds));
    return rotationEnd.subtract(const Duration(days: 1));
  }

  static bool _sameSkinSet(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final setA = a.toSet();
    return setA.length == b.toSet().length && setA.containsAll(b);
  }

  static Future<List<ShopHistoryEntry>> getHistory(String puuid) async {
    if (puuid.isEmpty) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey(puuid));
      if (raw == null || raw.isEmpty) return [];
      final List decoded = jsonDecode(raw);
      final entries = decoded
          .whereType<Map>()
          .map((e) {
            final dateStr = e['date'] as String?;
            final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
            if (date == null) return null;
            return ShopHistoryEntry(
              date: date,
              skinIds: List<String>.from(e['skinIds'] ?? const []),
            );
          })
          .whereType<ShopHistoryEntry>()
          .toList();

      return _collapseDuplicateRotations(entries);
    } catch (e) {
      LoggerService.log('Failed to read shop history: $e', tag: 'ShopHistory');
      return [];
    }
  }

  static List<ShopHistoryEntry> _collapseDuplicateRotations(
    List<ShopHistoryEntry> entries,
  ) {
    if (entries.length < 2) return entries;
    final result = <ShopHistoryEntry>[];
    for (final entry in entries) {
      final previous = result.isNotEmpty ? result.last : null;
      if (previous != null && _sameSkinSet(previous.skinIds, entry.skinIds)) {
        if (entry.date.isBefore(previous.date)) {
          result[result.length - 1] = entry;
        }
        continue;
      }
      result.add(entry);
    }
    return result;
  }

  static Future<void> clear(String puuid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey(puuid));
  }

  static int appearanceCount(List<ShopHistoryEntry> entries, String skinId) {
    var count = 0;
    for (final entry in entries) {
      if (entry.skinIds.contains(skinId)) count++;
    }
    return count;
  }

  static Map<String, int> appearanceCounts(List<ShopHistoryEntry> entries) {
    final Map<String, int> counts = {};
    for (final entry in entries) {
      for (final skinId in entry.skinIds) {
        counts[skinId] = (counts[skinId] ?? 0) + 1;
      }
    }
    return counts;
  }

  static DateTime? lastSeenDate(List<ShopHistoryEntry> entries, String skinId) {
    DateTime? latest;
    for (final entry in entries) {
      if (!entry.skinIds.contains(skinId)) continue;
      if (latest == null || entry.date.isAfter(latest)) {
        latest = entry.date;
      }
    }
    return latest;
  }

  static Map<String, DateTime> lastSeenDates(List<ShopHistoryEntry> entries) {
    final Map<String, DateTime> dates = {};
    for (final entry in entries) {
      for (final skinId in entry.skinIds) {
        final existing = dates[skinId];
        if (existing == null || entry.date.isAfter(existing)) {
          dates[skinId] = entry.date;
        }
      }
    }
    return dates;
  }

  static int? daysSinceLastSeen(
    List<ShopHistoryEntry> entries,
    String skinId, {
    DateTime? now,
  }) {
    final last = lastSeenDate(entries, skinId);
    if (last == null) return null;
    final today = now ?? DateTime.now();
    final a = DateTime(today.year, today.month, today.day);
    final b = DateTime(last.year, last.month, last.day);
    return a.difference(b).inDays;
  }
}
