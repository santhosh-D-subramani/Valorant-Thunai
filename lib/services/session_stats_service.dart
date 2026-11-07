class SessionStatsService {
  SessionStatsService._();

  static final DateTime appStart = DateTime.now();

  static bool isDuringSession(int gameStartEpochSeconds) {
    if (gameStartEpochSeconds <= 0) return false;
    final started = DateTime.fromMillisecondsSinceEpoch(
      gameStartEpochSeconds * 1000,
    );
    return !started.isBefore(appStart);
  }
}
