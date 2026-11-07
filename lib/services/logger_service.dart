import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoggerService {
  static final List<String> _logs = [];
  static const int _maxLogs = 500;

  static bool bypassCensoring = false;

  static bool get isCensoringActive => !bypassCensoring;

  static void initFromPrefs(SharedPreferences prefs) {
    final devUnlocked = prefs.getBool('developer_unlocked') ?? false;
    final bypassLogs = prefs.getBool('bypass_log_censoring') ?? false;
    bypassCensoring = devUnlocked && bypassLogs;
  }

  static String censor(String input) {
    if (input.isEmpty) return input;
    String censored = input;

    censored = censored.replaceAllMapped(
      RegExp(r'HDEV-[0-9a-zA-Z\-]+'),
      (match) => 'HDEV-***[REDACTED]***',
    );

    censored = censored.replaceAllMapped(
      RegExp(r'(Bearer\s+)[^\s,;}]+', caseSensitive: false),
      (match) => '${match.group(1)}[TOKEN_REDACTED]',
    );

    censored = censored.replaceAllMapped(
      RegExp(r'eyJ[a-zA-Z0-9_\-]{10,}\.[a-zA-Z0-9_\-]{10,}\.?[a-zA-Z0-9_\-]*'),
      (match) => 'eyJ***[JWT_REDACTED]***',
    );

    censored = censored.replaceAllMapped(
      RegExp(
        r'((?:access_token|id_token|pas_token|entitlements_jwt|entitlements_token|token|refresh_token)=)([^&\s]+)',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[REDACTED]',
    );

    censored = censored.replaceAllMapped(
      RegExp(r'(https?://[^\s]+/opt_in#)([^\s]+)'),
      (match) => '${match.group(1)}[REDACTED]',
    );

    censored = censored.replaceAllMapped(
      RegExp(
        r'((?:X-Riot-Entitlements-JWT|Riot-Entitlements-JWT|Authorization)[\s:=]+)([^\s,;]+)',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[REDACTED]',
    );

    censored = censored.replaceAllMapped(
      RegExp(
        r'((?:ssid|auth_token|tdid|clid|csid|sub)=)([^;\s&]+)',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[REDACTED]',
    );

    censored = censored.replaceAllMapped(
      RegExp(
        r'''((?:password|client_secret|api_key|apikey|secret)[\s:=]+["']?)([^"'\s,;]+)(["']?)''',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[REDACTED]${match.group(3)}',
    );

    censored = censored.replaceAllMapped(
      RegExp(
        r'((?:PUUID|puuid|User|user|Player|player|Account|account|Subject|subject|for)[\s:=]+)([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[PUUID_REDACTED]',
    );

    censored = censored.replaceAllMapped(
      RegExp(
        r'((?:/players/|/contracts/|/history/|/wallets/|/users/|/names/|/name-service/v2/players/))([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[PUUID_REDACTED]',
    );

    censored = censored.replaceAllMapped(
      RegExp(
        r'''((?:["'](?:puuid|subject|Subject|player_id)["']\s*[:=]\s*["']))([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})(["'])''',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[PUUID_REDACTED]${match.group(3)}',
    );

    censored = censored.replaceAllMapped(
      RegExp(
        r'((?:Name:\s*|player\s+name:\s*))([^\s,\n\r]+#[^\s,\n\r]+)',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[PLAYER_REDACTED]',
    );

    return censored;
  }

  static void log(String message, {String? tag}) {
    final timestamp = DateTime.now().toString().split('.').first;
    final rawLogEntry = '[$timestamp]${tag != null ? ' [$tag]' : ''} $message';

    _logs.add(rawLogEntry);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }

    if (kDebugMode) {
      if (isCensoringActive) {
        debugPrint(censor(rawLogEntry));
      } else {
        debugPrint(rawLogEntry);
      }
    }
  }

  static List<String> getLogs({bool? censored}) {
    final shouldCensor = censored ?? isCensoringActive;
    if (shouldCensor) {
      return _logs.map(censor).toList();
    }
    return List<String>.from(_logs);
  }

  static String getFullLogs({bool? censored}) {
    return getLogs(censored: censored).join('\n');
  }

  static void clearLogs() {
    _logs.clear();
  }

  static List<String> get logs => getLogs();
}
