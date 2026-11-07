import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityService {
  static Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup('1.1.1.1')
          .timeout(const Duration(seconds: 2));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}
    return false;
  }
}

class ConnectivityNotifier extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    _check();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _check());
    return true;
  }

  Future<void> _check() async {
    final online = await ConnectivityService.hasInternet();
    if (state != online) {
      state = online;
    }
  }

  Future<bool> forceCheck() async {
    final online = await ConnectivityService.hasInternet();
    if (state != online) {
      state = online;
    }
    return online;
  }
}

final connectivityProvider = NotifierProvider<ConnectivityNotifier, bool>(
  ConnectivityNotifier.new,
);
