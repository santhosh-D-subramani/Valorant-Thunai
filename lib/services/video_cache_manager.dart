import 'dart:io';

import 'package:http/http.dart' as http;

import 'logger_service.dart';

class VideoCacheManager {
  static const bool enableCache = true;

  static final Directory _cacheDir = Directory(
    '${Directory.systemTemp.path}/val_shop_video_cache',
  );

  static Future<void> init() async {
    if (!enableCache) return;
    try {
      if (!await _cacheDir.exists()) {
        await _cacheDir.create(recursive: true);
      }
    } catch (e) {
      LoggerService.log(
        'Failed to initialize video cache directory: $e',
        tag: 'VideoCache',
      );
    }
  }

  static Future<String> getVideoPath(String url) async {
    if (!enableCache) return url;

    try {
      await init();
      final uri = Uri.parse(url);
      final filename = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : '${url.hashCode}.mp4';

      final file = File('${_cacheDir.path}/$filename');

      if (await file.exists()) {
        LoggerService.log(
          'Using cached video: ${file.path}',
          tag: 'VideoCache',
        );
        return file.path;
      }

      LoggerService.log('Downloading video to cache: $url', tag: 'VideoCache');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        LoggerService.log(
          'Cached video saved: ${file.path}',
          tag: 'VideoCache',
        );
        return file.path;
      } else {
        LoggerService.log(
          'Failed to download video, status: ${response.statusCode}',
          tag: 'VideoCache',
        );
      }
    } catch (e) {
      LoggerService.log('Error caching video: $e', tag: 'VideoCache');
    }

    return url;
  }

  static Future<double> getCacheSizeInMB() async {
    try {
      if (await _cacheDir.exists()) {
        int totalSize = 0;
        await for (final file in _cacheDir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
        return totalSize / (1024 * 1024);
      }
    } catch (_) {
      return 0.0;
    }
    return 0.0;
  }

  static Future<void> clearCache() async {
    try {
      if (await _cacheDir.exists()) {
        final List<FileSystemEntity> entities = await _cacheDir.list().toList();
        for (final entity in entities) {
          await entity.delete(recursive: true);
        }
      }
    } catch (_) {
      return;
    }
  }
}
