import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'logger_service.dart';

final remoteConfigServiceProvider = ChangeNotifierProvider<RemoteConfigService>(
  (ref) {
    return RemoteConfigService.instance;
  },
);

class RemoteConfigService extends ChangeNotifier {
  static final RemoteConfigService instance = RemoteConfigService._internal();

  RemoteConfigService._internal();

  factory RemoteConfigService() => instance;

  static const String defaultUrl =
      'https://raw.githubusercontent.com/santhosh-D-subramani/Valorant-Thunai/refs/heads/main/config/remote_config.json';

  static const String prefUrlKey = 'github_remote_config_url';
  static const String prefCacheKey = 'github_remote_config_cache';
  static const String prefLastFetchKey = 'github_remote_config_last_fetch';
  static const String prefUserEditsKey = 'github_remote_config_user_edits';
  static const String prefBypassKey = 'bypass_remote_config';

  static const Duration cacheValidityDuration = Duration(days: 1);

  static bool bypassRemoteConfig = false;

  static const Map<String, dynamic> defaultConfigs = {
    'app_notifications': '[]',
    'latest_version': '1.0.0',
    'is_force_update': false,
    'message': 'New updates available!',
    'enable_update_check': true,
  };

  String _configUrl = defaultUrl;
  Map<String, dynamic> _cachedRemoteData = {};
  Map<String, dynamic> _userEdits = {};
  int _lastFetchTime = 0;

  bool _hasStalePendingUpdate = false;
  Map<String, dynamic>? _pendingStaleData;

  String get configUrl => _configUrl;
  int get lastFetchTime => _lastFetchTime;
  DateTime? get lastFetchDate => _lastFetchTime > 0
      ? DateTime.fromMillisecondsSinceEpoch(_lastFetchTime)
      : null;
  bool get hasStalePendingUpdate => _hasStalePendingUpdate;

  bool get isCacheStale {
    if (_lastFetchTime == 0) return true;
    final ageMillis = DateTime.now().millisecondsSinceEpoch - _lastFetchTime;
    return ageMillis > cacheValidityDuration.inMilliseconds;
  }

  Map<String, dynamic> get userEdits => Map.unmodifiable(_userEdits);
  Map<String, dynamic> get cachedRemoteData =>
      Map.unmodifiable(_cachedRemoteData);

  bool hasUserEdit(String key) => _userEdits.containsKey(key);
  bool get hasAnyUserEdits => _userEdits.isNotEmpty;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bypassRemoteConfig = prefs.getBool(prefBypassKey) ?? false;
      _configUrl = prefs.getString(prefUrlKey) ?? defaultUrl;
      _lastFetchTime = prefs.getInt(prefLastFetchKey) ?? 0;

      final rawCached = prefs.getString(prefCacheKey);
      if (rawCached != null && rawCached.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawCached);
          if (decoded is Map<String, dynamic>) {
            _cachedRemoteData = decoded;
          }
        } catch (e) {
          LoggerService.log(
            'Failed to decode cached remote config: $e',
            tag: 'RemoteConfig',
          );
        }
      }

      final rawEdits = prefs.getString(prefUserEditsKey);
      if (rawEdits != null && rawEdits.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawEdits);
          if (decoded is Map<String, dynamic>) {
            _userEdits = decoded;
          }
        } catch (e) {
          LoggerService.log(
            'Failed to decode user edits: $e',
            tag: 'RemoteConfig',
          );
        }
      }

      if (_cachedRemoteData.isEmpty) {
        _cachedRemoteData = Map<String, dynamic>.from(defaultConfigs);
      }

      if (isCacheStale) {
        await _fetchInBackground(silent: true);
      }
      notifyListeners();
    } catch (e) {
      LoggerService.log(
        'RemoteConfigService initialize error: $e',
        tag: 'RemoteConfig',
      );
    }
  }

  Future<void> setConfigUrl(String url) async {
    _configUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefUrlKey, _configUrl);
    notifyListeners();
  }

  Future<void> resetUrlToDefault() async {
    await setConfigUrl(defaultUrl);
  }

  Future<
    ({bool success, String message, int keyCount, Map<String, dynamic>? data})
  >
  testUrl(String testUrl) async {
    try {
      final uri = Uri.tryParse(testUrl.trim());
      if (uri == null || !uri.hasScheme) {
        return (
          success: false,
          message: 'Invalid URL format',
          keyCount: 0,
          data: null,
        );
      }

      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return (
          success: false,
          message: 'HTTP ${response.statusCode}: Failed to fetch URL',
          keyCount: 0,
          data: null,
        );
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return (
          success: false,
          message: 'Response is not a valid JSON Object map',
          keyCount: 0,
          data: null,
        );
      }

      return (
        success: true,
        message: 'Successfully loaded JSON with ${decoded.length} keys',
        keyCount: decoded.length,
        data: decoded,
      );
    } catch (e) {
      return (
        success: false,
        message: 'Network error: $e',
        keyCount: 0,
        data: null,
      );
    }
  }

  Future<bool> _fetchInBackground({bool silent = true}) async {
    final result = await testUrl(_configUrl);
    if (!result.success || result.data == null) {
      if (result.message.contains('404')) {
        LoggerService.log(
          'Remote config URL returned 404 (repo not yet published to GitHub). Using local default config.',
          tag: 'RemoteConfig',
        );
      } else {
        LoggerService.log(
          'Background fetch failed: ${result.message}',
          tag: 'RemoteConfig',
        );
      }
      return false;
    }

    final newData = result.data!;
    final prefs = await SharedPreferences.getInstance();

    if (_userEdits.isNotEmpty) {
      _pendingStaleData = newData;
      _hasStalePendingUpdate = true;
      LoggerService.log(
        'New remote data fetched but user has custom edits. Holding pending update.',
        tag: 'RemoteConfig',
      );
      if (!silent) notifyListeners();
      return true;
    }

    _cachedRemoteData = newData;
    _lastFetchTime = DateTime.now().millisecondsSinceEpoch;
    _hasStalePendingUpdate = false;
    _pendingStaleData = null;

    await prefs.setString(prefCacheKey, jsonEncode(_cachedRemoteData));
    await prefs.setInt(prefLastFetchKey, _lastFetchTime);
    if (!silent) notifyListeners();
    return true;
  }

  Future<bool> refreshManually(BuildContext context) async {
    if (hasAnyUserEdits) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Refresh Remote Config'),
          content: const Text(
            'Refreshing from the GitHub URL will overwrite all your custom edited values with the URL data.\n\nDo you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Overwrite & Refresh'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return false;
      }
    }

    final result = await testUrl(_configUrl);
    if (!result.success || result.data == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh: ${result.message}')),
        );
      }
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    _cachedRemoteData = result.data!;
    _lastFetchTime = DateTime.now().millisecondsSinceEpoch;
    _userEdits.clear();
    _hasStalePendingUpdate = false;
    _pendingStaleData = null;

    await prefs.setString(prefCacheKey, jsonEncode(_cachedRemoteData));
    await prefs.setInt(prefLastFetchKey, _lastFetchTime);
    await prefs.remove(prefUserEditsKey);

    notifyListeners();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remote config successfully refreshed!')),
      );
    }
    return true;
  }

  Future<void> promptStaleCacheUpdateIfAvailable(BuildContext context) async {
    if (!_hasStalePendingUpdate || _pendingStaleData == null) return;

    bool overrideUserEdits = false;
    final shouldApply = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Remote Config Updated'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The cached remote configuration has expired (older than 1 day), and new configuration data is available from GitHub.',
              ),
              const SizedBox(height: 12),
              const Text(
                'You currently have customized values saved.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: overrideUserEdits,
                title: const Text('Override my custom edits'),
                subtitle: const Text(
                  'If checked, your edits will be replaced with remote data. If unchecked, your edits are kept and only unedited values will update.',
                  style: TextStyle(fontSize: 12),
                ),
                onChanged: (val) {
                  setDialogState(() {
                    overrideUserEdits = val ?? false;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep Current'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Apply Update'),
            ),
          ],
        ),
      ),
    );

    if (shouldApply == true && _pendingStaleData != null) {
      final prefs = await SharedPreferences.getInstance();
      _cachedRemoteData = _pendingStaleData!;
      _lastFetchTime = DateTime.now().millisecondsSinceEpoch;
      _hasStalePendingUpdate = false;
      _pendingStaleData = null;

      if (overrideUserEdits) {
        _userEdits.clear();
        await prefs.remove(prefUserEditsKey);
      }

      await prefs.setString(prefCacheKey, jsonEncode(_cachedRemoteData));
      await prefs.setInt(prefLastFetchKey, _lastFetchTime);
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              overrideUserEdits
                  ? 'Remote config updated and edits overridden.'
                  : 'Remote config updated while preserving your edits.',
            ),
          ),
        );
      }
    }
  }

  Future<void> setUserEdit(String key, dynamic value) async {
    _userEdits[key] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefUserEditsKey, jsonEncode(_userEdits));
    notifyListeners();
  }

  Future<void> clearUserEdit(String key) async {
    _userEdits.remove(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefUserEditsKey, jsonEncode(_userEdits));
    notifyListeners();
  }

  Future<void> clearAllUserEdits() async {
    _userEdits.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefUserEditsKey);
    notifyListeners();
  }

  dynamic getValue(String key) {
    if (bypassRemoteConfig) {
      return defaultConfigs[key];
    }
    if (_userEdits.containsKey(key)) {
      return _userEdits[key];
    }
    if (_cachedRemoteData.containsKey(key)) {
      return _cachedRemoteData[key];
    }
    return defaultConfigs[key];
  }

  bool getBool(String key, {bool defaultValue = false}) {
    final val = getValue(key);
    if (val is bool) return val;
    if (val is String) {
      return val.toLowerCase() == 'true';
    }
    return defaultValue;
  }

  String getString(String key, {String defaultValue = ''}) {
    final val = getValue(key);
    if (val != null) return val.toString();
    return defaultValue;
  }

  bool get enableUpdateCheck =>
      getBool('enable_update_check', defaultValue: true);
  String get latestVersion =>
      getString('latest_version', defaultValue: '1.0.0');
  bool get isForceUpdate => getBool('is_force_update', defaultValue: false);
  String get updateMessage =>
      getString('message', defaultValue: 'New updates available!');

  List<Map<String, dynamic>> get appNotifications {
    final jsonStr = getString('app_notifications');
    if (jsonStr.isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(
          decoded.whereType<Map<String, dynamic>>(),
        );
      }
    } catch (e) {
      LoggerService.log(
        'Failed to parse app_notifications: $e',
        tag: 'RemoteConfig',
      );
    }
    return [];
  }
}
