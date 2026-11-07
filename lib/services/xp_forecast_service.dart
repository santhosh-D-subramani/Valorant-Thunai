import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_thunai/services/logger_service.dart';

class XpSnapshot {
  final DateTime timestamp;
  final int totalXpEarned;

  XpSnapshot({required this.timestamp, required this.totalXpEarned});

  Map<String, dynamic> toJson() => {
    't': timestamp.toIso8601String(),
    'xp': totalXpEarned,
  };

  factory XpSnapshot.fromJson(Map<String, dynamic> json) => XpSnapshot(
    timestamp: DateTime.parse(json['t'] as String),
    totalXpEarned: json['xp'] as int,
  );
}

class BattlepassForecast {
  final double? xpPerDay;
  final int? estimatedDaysRemaining;
  final DateTime? estimatedFinishDate;

  const BattlepassForecast({
    this.xpPerDay,
    this.estimatedDaysRemaining,
    this.estimatedFinishDate,
  });

  bool get hasEstimate => xpPerDay != null && xpPerDay! > 0;
}

class XpForecastService {
  static const _maxSnapshots = 30;
  static const _snapshotWindow = Duration(days: 14);
  static const _minSnapshotGap = Duration(hours: 3);
  static const _minSpanForEstimate = Duration(hours: 6);

  static String _keyFor(String contractId) => 'bp_xp_history_$contractId';

  static Future<List<XpSnapshot>> _load(String contractId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyFor(contractId));
      if (raw == null) return [];
      final List decoded = jsonDecode(raw);
      return decoded
          .map((e) => XpSnapshot.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      LoggerService.log('XpForecastService load error: $e', tag: 'XpForecast');
      return [];
    }
  }

  static Future<void> _save(String contractId, List<XpSnapshot> snaps) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyFor(contractId),
        jsonEncode(snaps.map((s) => s.toJson()).toList()),
      );
    } catch (e) {
      LoggerService.log('XpForecastService save error: $e', tag: 'XpForecast');
    }
  }

  static Future<List<XpSnapshot>> recordSnapshot(
    String contractId,
    int totalXpEarned,
  ) async {
    final now = DateTime.now();
    var snaps = await _load(contractId);

    if (snaps.isNotEmpty && totalXpEarned < snaps.last.totalXpEarned) {
      snaps = [];
    }

    final last = snaps.isEmpty ? null : snaps.last;
    final isNewValue = last == null || last.totalXpEarned != totalXpEarned;
    final longEnoughSinceLast =
        last == null || now.difference(last.timestamp) >= _minSnapshotGap;

    if (isNewValue && longEnoughSinceLast) {
      snaps.add(XpSnapshot(timestamp: now, totalXpEarned: totalXpEarned));
    }

    final cutoff = now.subtract(_snapshotWindow);
    snaps = snaps.where((s) => s.timestamp.isAfter(cutoff)).toList();
    if (snaps.length > _maxSnapshots) {
      snaps = snaps.sublist(snaps.length - _maxSnapshots);
    }

    await _save(contractId, snaps);
    return snaps;
  }

  static Future<BattlepassForecast> computeForecast(
    String contractId, {
    required int remainingXp,
  }) async {
    final snaps = await _load(contractId);
    if (snaps.length < 2 || remainingXp <= 0) {
      return const BattlepassForecast();
    }

    final oldest = snaps.first;
    final newest = snaps.last;
    final span = newest.timestamp.difference(oldest.timestamp);
    if (span < _minSpanForEstimate) {
      return const BattlepassForecast();
    }

    final xpDelta = newest.totalXpEarned - oldest.totalXpEarned;
    if (xpDelta <= 0) {
      return const BattlepassForecast();
    }

    final xpPerDay = xpDelta / (span.inMinutes / (24 * 60));
    if (xpPerDay <= 0) {
      return const BattlepassForecast();
    }

    final daysRemaining = (remainingXp / xpPerDay).ceil();
    final finishDate = DateTime.now().add(Duration(days: daysRemaining));

    return BattlepassForecast(
      xpPerDay: xpPerDay,
      estimatedDaysRemaining: daysRemaining,
      estimatedFinishDate: finishDate,
    );
  }
}
