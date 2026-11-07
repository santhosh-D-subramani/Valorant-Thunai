class RankHistoryEntry {
  final DateTime timestamp;
  final int tier;
  final int rr;

  const RankHistoryEntry({
    required this.timestamp,
    required this.tier,
    required this.rr,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'tier': tier,
    'rr': rr,
  };

  factory RankHistoryEntry.fromJson(Map<String, dynamic> json) {
    return RankHistoryEntry(
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      tier: (json['tier'] as num?)?.toInt() ?? 0,
      rr: (json['rr'] as num?)?.toInt() ?? 0,
    );
  }
}
