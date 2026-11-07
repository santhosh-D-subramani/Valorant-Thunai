import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'logger_service.dart';

class RiotLockfile {
  final String name;
  final int pid;
  final int port;
  final String password;
  final String protocol;

  RiotLockfile({
    required this.name,
    required this.pid,
    required this.port,
    required this.password,
    required this.protocol,
  });

  @override
  String toString() {
    return 'RiotLockfile(name: $name, pid: $pid, port: $port, protocol: $protocol)';
  }
}

final riotLocalServiceProvider = Provider<RiotLocalService>((ref) {
  return RiotLocalService(ref);
});

class RiotLocalService {
  final Ref ref;

  RiotLocalService(this.ref);

  Future<RiotLockfile?> getLockfile() async {
    try {
      if (!Platform.isWindows) {
        LoggerService.log(
          'Lockfile is only readable on Windows.',
          tag: 'RiotLocalService',
        );
        return null;
      }

      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData == null) {
        LoggerService.log(
          'LOCALAPPDATA environment variable not found.',
          tag: 'RiotLocalService',
        );
        return null;
      }

      final lockfilePath =
          '$localAppData\\Riot Games\\Riot Client\\Config\\lockfile';
      final file = File(lockfilePath);

      if (!await file.exists()) {
        LoggerService.log(
          'Riot Client lockfile not found at: $lockfilePath',
          tag: 'RiotLocalService',
        );
        return null;
      }

      final content = await file.readAsString();
      final parts = content.split(':');
      if (parts.length >= 5) {
        final lockfile = RiotLockfile(
          name: parts[0],
          pid: int.tryParse(parts[1]) ?? 0,
          port: int.tryParse(parts[2]) ?? 0,
          password: parts[3],
          protocol: parts[4],
        );
        LoggerService.log(
          'Successfully loaded lockfile: $lockfile',
          tag: 'RiotLocalService',
        );
        return lockfile;
      } else {
        LoggerService.log(
          'Invalid lockfile format: $content',
          tag: 'RiotLocalService',
        );
      }
    } catch (e) {
      LoggerService.log('Error reading lockfile: $e', tag: 'RiotLocalService');
    }
    return null;
  }

  Future<List<dynamic>> getFriends(RiotLockfile lockfile) async {
    final host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
    final url = '${lockfile.protocol}://$host:${lockfile.port}/chat/v4/friends';
    final authHeader =
        'Basic ${base64.encode(utf8.encode('riot:${lockfile.password}'))}';

    LoggerService.log(
      'Fetching friends from local API: $url',
      tag: 'RiotLocalService',
    );

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['friends'] ?? [];
    } else {
      throw Exception(
        'Failed to load friends from local API: ${response.statusCode} (body: ${response.body})',
      );
    }
  }

  Future<void> addFriend(
    RiotLockfile lockfile,
    String gameName,
    String gameTag,
  ) async {
    final host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
    final authHeader =
        'Basic ${base64.encode(utf8.encode('riot:${lockfile.password}'))}';

    final endpoints = [
      '${lockfile.protocol}://$host:${lockfile.port}/chat/v4/friendclaims',
      '${lockfile.protocol}://$host:${lockfile.port}/chat/v4/friendrequests',
    ];

    Exception? lastException;

    for (var url in endpoints) {
      try {
        LoggerService.log(
          'Attempting to add friend at: $url',
          tag: 'RiotLocalService',
        );
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Authorization': authHeader,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'game_name': gameName, 'game_tag': gameTag}),
        );

        if (response.statusCode == 200 ||
            response.statusCode == 201 ||
            response.statusCode == 204) {
          LoggerService.log(
            'Successfully sent friend request to $gameName#$gameTag via $url',
            tag: 'RiotLocalService',
          );
          return;
        } else if (response.statusCode == 404) {
          LoggerService.log(
            'Endpoint $url not found (404), trying next fallback...',
            tag: 'RiotLocalService',
          );
          continue;
        } else {
          throw Exception(
            'Riot API returned status code ${response.statusCode}: ${response.body}',
          );
        }
      } catch (e) {
        LoggerService.log(
          'Failed to add friend via $url: $e',
          tag: 'RiotLocalService',
        );
        lastException = e as Exception;
      }
    }

    throw lastException ?? Exception('Failed to send friend request');
  }
}
