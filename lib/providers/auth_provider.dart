import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_thunai/services/riot_auth_service.dart';
import 'package:valorant_thunai/services/valorant_api.dart';
import 'package:valorant_thunai/services/connectivity_service.dart';
import 'package:valorant_thunai/services/logger_service.dart';
import 'package:valorant_thunai/services/widget_sync_service.dart';

class AuthState {
  final List<RiotUser> allUsers;
  final int activeUserIndex;
  final int previousUserIndex;
  final bool isLoading;
  final String? error;
  final bool hasSessionExpired;
  final bool isSessionExpiredDismissed;

  AuthState({
    this.allUsers = const [],
    this.activeUserIndex = 0,
    this.previousUserIndex = 0,
    this.isLoading = false,
    this.error,
    this.hasSessionExpired = false,
    this.isSessionExpiredDismissed = false,
  });

  RiotUser? get user => allUsers.isNotEmpty && activeUserIndex < allUsers.length
      ? allUsers[activeUserIndex]
      : null;

  AuthState copyWith({
    List<RiotUser>? allUsers,
    int? activeUserIndex,
    int? previousUserIndex,
    bool? isLoading,
    String? error,
    bool? hasSessionExpired,
    bool? isSessionExpiredDismissed,
  }) {
    return AuthState(
      allUsers: allUsers ?? this.allUsers,
      activeUserIndex: activeUserIndex ?? this.activeUserIndex,
      previousUserIndex: previousUserIndex ?? this.previousUserIndex,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      hasSessionExpired: hasSessionExpired ?? this.hasSessionExpired,
      isSessionExpiredDismissed:
          isSessionExpiredDismissed ?? this.isSessionExpiredDismissed,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> with WidgetsBindingObserver {
  Timer? _refreshTimer;
  static int _refreshCounter = 0;
  int? _activeRefreshId;

  int _getCookieCount(String? cookiesJson) {
    if (cookiesJson == null) return 0;
    try {
      final decoded = jsonDecode(cookiesJson);
      if (decoded is List) return decoded.length;
      if (decoded is Map) return decoded.keys.length;
    } catch (_) {}
    return 0;
  }

  void _printSummary(int cid, bool success) {
    final platform = Platform.isIOS ? 'iOS' : 'Android';
    final user = state.user;
    final tokenExpirationString =
        user?.tokenExpiration?.toIso8601String() ?? 'N/A';
    LoggerService.log('''[AuthRefresh #$cid] RESULT
platform=$platform
success=$success
accessTokenPresent=${user?.accessToken.isNotEmpty == true}
accessTokenExpiry=$tokenExpirationString
refreshTokenPresent=false
cookies=${_getCookieCount(user?.cookies)}
authState=${state.hasSessionExpired ? 'EXPIRED' : 'ACTIVE'}''', tag: 'Auth');
  }

  @override
  AuthState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _refreshTimer?.cancel();
      LoggerService.log('[RefreshTimer] cancelled', tag: 'Auth');
    });
    _loadUsers();
    return AuthState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    LoggerService.log(
      '[AppLifecycle] state changed to: ${state.toString()}',
      tag: 'Auth',
    );
  }

  void startTokenRefreshTimer() {
    _refreshTimer?.cancel();
    LoggerService.log(
      '[RefreshTimer] started, interval: 5 minutes',
      tag: 'Auth',
    );
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      LoggerService.log('[RefreshTimer] fired', tag: 'Auth');
      checkAndRefreshSession();
    });
  }

  Future<void> _loadUsers() async {
    final platform = Platform.isIOS ? 'iOS' : 'Android';
    final timestamp = DateTime.now().toIso8601String();
    LoggerService.log(
      '[Storage] READ START: platform=$platform, timestamp=$timestamp',
      tag: 'Auth',
    );

    final prefs = await SharedPreferences.getInstance();
    final String? usersData = prefs.getString('riot_users');
    final int activeIndex = prefs.getInt('active_user_index') ?? 0;
    final int previousIndex = prefs.getInt('previous_user_index') ?? 0;

    if (usersData != null) {
      try {
        final List<dynamic> list = jsonDecode(usersData);
        final List<RiotUser> users = list
            .map((item) => RiotUser.fromJson(item))
            .toList();
        state = state.copyWith(
          allUsers: users,
          activeUserIndex: activeIndex,
          previousUserIndex: previousIndex,
        );

        final userCount = users.length;
        final activeUser = (activeIndex >= 0 && activeIndex < users.length)
            ? users[activeIndex]
            : null;
        final tokenExists = activeUser != null;
        final tokenLength = activeUser?.accessToken.length ?? 0;
        final tokenExpiry =
            activeUser?.tokenExpiration?.toIso8601String() ?? 'N/A';
        final cookieCount = _getCookieCount(activeUser?.cookies);
        LoggerService.log(
          '[Storage] READ SUCCESS: platform=$platform, userCount=$userCount, tokenExists=$tokenExists, tokenLength=$tokenLength, tokenExpiry=$tokenExpiry, cookieCount=$cookieCount, timestamp=$timestamp',
          tag: 'Auth',
        );
      } catch (e) {
        LoggerService.log(
          '[Storage] READ FAILED: platform=$platform, error=$e, timestamp=$timestamp',
          tag: 'Auth',
        );
      }
    } else {
      final String? oldUser = prefs.getString('riot_user');
      if (oldUser != null) {
        try {
          final user = RiotUser.fromJson(jsonDecode(oldUser));
          state = state.copyWith(
            allUsers: [user],
            activeUserIndex: 0,
            previousUserIndex: 0,
          );
          _saveUsers([user], 0, 0);
          await prefs.remove('riot_user');
        } catch (e) {
          LoggerService.log('Error migrating old user: $e', tag: 'Auth');
        }
      }
    }

    await checkAndRefreshSession();

    startTokenRefreshTimer();

    _enrichAllUsersIfNeeded();
  }

  Future<void> _enrichAllUsersIfNeeded() async {
    bool changed = false;
    final updatedUsers = List<RiotUser>.from(state.allUsers);
    final valApi = ref.read(valorantApiProvider);

    for (int i = 0; i < updatedUsers.length; i++) {
      if (updatedUsers[i].gameName == null || updatedUsers[i].level == null) {
        try {
          LoggerService.log(
            'Enriching user ${updatedUsers[i].puuid} on startup...',
            tag: 'Auth',
          );
          final enriched = await valApi.enrichUserWithInfo(updatedUsers[i]);
          updatedUsers[i] = enriched;
          changed = true;
        } catch (e) {
          LoggerService.log('Failed to enrich user $i: $e', tag: 'Auth');
        }
      }
    }

    if (changed) {
      state = state.copyWith(allUsers: updatedUsers);
      _saveUsers(updatedUsers, state.activeUserIndex, state.previousUserIndex);
    }
  }

  Future<void> _saveUsers(
    List<RiotUser> users,
    int activeIndex, [
    int? previousIndex,
  ]) async {
    final platform = Platform.isIOS ? 'iOS' : 'Android';
    final timestamp = DateTime.now().toIso8601String();
    final userCount = users.length;
    final activeUser = (activeIndex >= 0 && activeIndex < users.length)
        ? users[activeIndex]
        : null;
    final tokenExists = activeUser != null;
    final tokenLength = activeUser?.accessToken.length ?? 0;
    final tokenExpiry = activeUser?.tokenExpiration?.toIso8601String() ?? 'N/A';
    final cookieCount = _getCookieCount(activeUser?.cookies);
    LoggerService.log(
      '[Storage] WRITE START: platform=$platform, userCount=$userCount, tokenExists=$tokenExists, tokenLength=$tokenLength, tokenExpiry=$tokenExpiry, cookieCount=$cookieCount, timestamp=$timestamp',
      tag: 'Auth',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'riot_users',
      jsonEncode(users.map((u) => u.toJson()).toList()),
    );
    await prefs.setInt('active_user_index', activeIndex);
    if (previousIndex != null) {
      await prefs.setInt('previous_user_index', previousIndex);
    }
    LoggerService.log(
      '[Storage] WRITE COMPLETED: platform=$platform, timestamp=$timestamp',
      tag: 'Auth',
    );
  }

  Future<void> loginWithTokens(
    String accessToken,
    String idToken, {
    String? cookies,
    int? correlationId,
  }) async {
    final cid = correlationId ?? -1;
    final logPrefix = cid != -1 ? '[AuthRefresh #$cid] ' : '';
    LoggerService.log(
      '${logPrefix}loginWithTokens internal started, inputs: accessTokenExists=${accessToken.isNotEmpty}, accessTokenLength=${accessToken.length}, idTokenExists=${idToken.isNotEmpty}, idTokenLength=${idToken.length}, cookiesExists=${cookies != null}, cookiesLength=${cookies?.length ?? 0}',
      tag: 'Auth',
    );

    final authService = ref.read(riotAuthServiceProvider);
    state = state.copyWith(
      isLoading: true,
      error: null,
      hasSessionExpired: false,
    );
    try {
      LoggerService.log(
        '${logPrefix}Calling fetchTokens inside loginWithTokens...',
        tag: 'Auth',
      );
      var user = await authService.fetchTokens(
        accessToken,
        idToken,
        cookies: cookies,
        correlationId: cid,
      );

      try {
        final valApi = ref.read(valorantApiProvider);
        user = await valApi.enrichUserWithInfo(user);
      } catch (e) {
        LoggerService.log(
          '${logPrefix}Error enriching user info: $e',
          tag: 'Auth',
        );
      }

      final updatedUsers = List<RiotUser>.from(state.allUsers);
      final existingIndex = updatedUsers.indexWhere(
        (u) => u.puuid == user.puuid,
      );

      int newActiveIndex;
      int newPreviousIndex = state.previousUserIndex;
      if (existingIndex != -1) {
        updatedUsers[existingIndex] = user;
        if (state.activeUserIndex != existingIndex) {
          newPreviousIndex = state.activeUserIndex;
        }
        newActiveIndex = existingIndex;
      } else {
        updatedUsers.add(user);
        newPreviousIndex = state.activeUserIndex;
        newActiveIndex = updatedUsers.length - 1;
      }

      await _saveUsers(updatedUsers, newActiveIndex, newPreviousIndex);
      state = state.copyWith(
        allUsers: updatedUsers,
        activeUserIndex: newActiveIndex,
        previousUserIndex: newPreviousIndex,
        isLoading: false,
        hasSessionExpired: false,
        isSessionExpiredDismissed: false,
      );
      LoggerService.log(
        '${logPrefix}loginWithTokens finished successfully. Persisted user count: ${updatedUsers.length}',
        tag: 'Auth',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      LoggerService.log(
        '${logPrefix}loginWithTokens failed with error: $e',
        tag: 'Auth',
      );
      rethrow;
    }
  }

  bool _isRefreshing = false;
  Completer<void>? _refreshCompleter;

  Future<void> checkAndRefreshSession({bool force = false}) async {
    final bool isOnline = await ConnectivityService.hasInternet();
    final int cid = ++_refreshCounter;
    final platform = Platform.isIOS ? 'iOS' : 'Android';
    final timestamp = DateTime.now().toIso8601String();

    if (_isRefreshing && _activeRefreshId != null) {
      LoggerService.log(
        '[AuthRefresh #$cid] START while #$_activeRefreshId is running',
        tag: 'Auth',
      );
    } else {
      LoggerService.log('[AuthRefresh #$cid] START', tag: 'Auth');
    }
    _activeRefreshId = cid;

    final user = state.user;
    final bool tokenExists = user != null;
    final int tokenLength = user?.accessToken.length ?? 0;
    final String tokenExpiry =
        user?.tokenExpiration?.toIso8601String() ?? 'N/A';
    final bool refreshTokenExists = false;
    final int refreshTokenLength = 0;
    final int storedCookieCount = _getCookieCount(user?.cookies);

    LoggerService.log(
      '[AuthRefresh #$cid] LOAD_STATE: platform=$platform, force=$force, isOnline=$isOnline, hasSessionExpired=${state.hasSessionExpired}, isRefreshing=$_isRefreshing, userExists=$tokenExists, accessTokenLength=$tokenLength, accessTokenExpiry=$tokenExpiry, refreshTokenExists=$refreshTokenExists, refreshTokenLength=$refreshTokenLength, storedCookieCount=$storedCookieCount, timestamp=$timestamp',
      tag: 'Auth',
    );

    if (!isOnline) {
      LoggerService.log(
        '[AuthRefresh #$cid] Network offline, skipping checkAndRefreshSession.',
        tag: 'Auth',
      );
      _printSummary(cid, false);
      return;
    }

    if (state.hasSessionExpired) {
      LoggerService.log(
        '[AuthRefresh #$cid] Session already marked as expired, skipping checkAndRefreshSession.',
        tag: 'Auth',
      );
      _printSummary(cid, false);
      return;
    }

    if (_isRefreshing) {
      LoggerService.log(
        '[AuthRefresh #$cid] A refresh is already in progress, waiting for existing completer.',
        tag: 'Auth',
      );
      if (_refreshCompleter != null) {
        try {
          await _refreshCompleter!.future;
          _printSummary(cid, true);
        } catch (e) {
          LoggerService.log(
            '[AuthRefresh #$cid] Existing completer failed: $e',
            tag: 'Auth',
          );
          _printSummary(cid, false);
        }
      } else {
        _printSummary(cid, false);
      }
      return;
    }

    if (user == null || user.cookies == null) {
      LoggerService.log(
        '[AuthRefresh #$cid] No user or cookies stored, cannot silent refresh.',
        tag: 'Auth',
      );
      _printSummary(cid, false);
      return;
    }

    try {
      bool shouldRefresh = force;
      if (!shouldRefresh) {
        if (user.isTokenExpiringSoon) {
          shouldRefresh = true;
          LoggerService.log(
            '[AuthRefresh #$cid] Token expiring soon (expires at ${user.tokenExpiration}), triggering refresh...',
            tag: 'Auth',
          );
        }
      }

      if (shouldRefresh) {
        _isRefreshing = true;
        _refreshCompleter = Completer<void>();
        LoggerService.log(
          '[AuthRefresh #$cid] Refreshing token (force: $force)...',
          tag: 'Auth',
        );
        try {
          LoggerService.log(
            '[AuthRefresh #$cid] Calling silentRefresh...',
            tag: 'Auth',
          );
          final newUser = await ref
              .read(riotAuthServiceProvider)
              .silentRefresh(user, correlationId: cid);
          LoggerService.log(
            '[AuthRefresh #$cid] silentRefresh returned successfully',
            tag: 'Auth',
          );

          LoggerService.log(
            '[AuthRefresh #$cid] loginWithTokens started',
            tag: 'Auth',
          );
          await loginWithTokens(
            newUser.accessToken,
            newUser.idToken,
            cookies: newUser.cookies,
            correlationId: cid,
          );
          LoggerService.log(
            '[AuthRefresh #$cid] loginWithTokens completed',
            tag: 'Auth',
          );

          _refreshCompleter?.complete();
          _printSummary(cid, true);
        } catch (e, stack) {
          LoggerService.log(
            '[AuthRefresh #$cid] silentRefresh or loginWithTokens threw: $e\nStack trace: $stack',
            tag: 'Auth',
          );
          _refreshCompleter?.completeError(e);
          rethrow;
        } finally {
          _isRefreshing = false;
          _refreshCompleter = null;
        }
      } else {
        LoggerService.log(
          '[AuthRefresh #$cid] Token not expiring yet, no refresh needed.',
          tag: 'Auth',
        );
        _printSummary(cid, true);
      }
    } catch (e) {
      LoggerService.log('[AuthRefresh #$cid] Refresh failed: $e', tag: 'Auth');
      _isRefreshing = false;
      _refreshCompleter = null;
      setSessionExpired(true);
      _printSummary(cid, false);
    }
  }

  Future<void> refreshProfile(int index) async {
    if (index < 0 || index >= state.allUsers.length) return;

    state = state.copyWith(isLoading: true);
    try {
      final user = state.allUsers[index];
      final valApi = ref.read(valorantApiProvider);
      final enriched = await valApi.enrichUserWithInfo(user);

      final updatedUsers = List<RiotUser>.from(state.allUsers);
      updatedUsers[index] = enriched;

      state = state.copyWith(allUsers: updatedUsers, isLoading: false);
      await _saveUsers(
        updatedUsers,
        state.activeUserIndex,
        state.previousUserIndex,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  void switchAccount(int index) {
    if (index >= 0 && index < state.allUsers.length) {
      if (index != state.activeUserIndex) {
        final prevIndex = state.activeUserIndex;
        state = state.copyWith(
          activeUserIndex: index,
          previousUserIndex: prevIndex,
        );
        _saveUsers(state.allUsers, index, prevIndex);
      }
    }
  }

  RiotUser? swapToPreviousAccount() {
    if (state.allUsers.length <= 1) return null;
    int targetIndex = state.previousUserIndex;
    if (targetIndex >= state.allUsers.length ||
        targetIndex < 0 ||
        targetIndex == state.activeUserIndex) {
      targetIndex = state.activeUserIndex == 0 ? 1 : 0;
    }
    final oldActive = state.activeUserIndex;
    state = state.copyWith(
      activeUserIndex: targetIndex,
      previousUserIndex: oldActive,
    );
    _saveUsers(state.allUsers, targetIndex, oldActive);
    return state.user;
  }

  Future<void> logoutAccount(int index) async {
    if (index < 0 || index >= state.allUsers.length) return;

    final updatedUsers = List<RiotUser>.from(state.allUsers);
    updatedUsers.removeAt(index);

    int newIndex = state.activeUserIndex;
    if (index <= state.activeUserIndex) {
      newIndex = (state.activeUserIndex - 1).clamp(
        0,
        updatedUsers.isEmpty ? 0 : updatedUsers.length - 1,
      );
    }

    int newPreviousIndex = state.previousUserIndex;
    if (index <= state.previousUserIndex) {
      newPreviousIndex = (state.previousUserIndex - 1).clamp(
        0,
        updatedUsers.isEmpty ? 0 : updatedUsers.length - 1,
      );
    }

    if (updatedUsers.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('riot_users');
      await prefs.remove('active_user_index');
      await prefs.remove('previous_user_index');
      await WidgetSyncService.clearWidgetData();
      state = AuthState();
    } else {
      await _saveUsers(updatedUsers, newIndex, newPreviousIndex);
      state = state.copyWith(
        allUsers: updatedUsers,
        activeUserIndex: newIndex,
        previousUserIndex: newPreviousIndex,
      );
    }
  }

  void setSessionExpired(bool expired, {bool force = false}) {
    final bool wasExpired = state.hasSessionExpired;
    state = state.copyWith(
      hasSessionExpired: expired,
      isSessionExpiredDismissed: (force || (!wasExpired && expired))
          ? false
          : state.isSessionExpiredDismissed,
    );
  }

  void dismissSessionExpired() {
    state = state.copyWith(isSessionExpiredDismissed: true);
  }

  Future<void> logout() async {
    await logoutAccount(state.activeUserIndex);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
