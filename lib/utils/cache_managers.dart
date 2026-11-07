import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

class CustomCacheManagers {
  static const String bundleCacheKey = 'bundleCacheData';
  static const String dailyStoreCacheKey = 'dailyStoreCacheData';
  static const String tierImageCacheKey = 'tierImageCacheData';
  static const String loadoutPresetCacheKey = 'loadoutPresetCacheData';

  static final CacheManager bundleCacheManager = CacheManager(
    Config(
      bundleCacheKey,
      stalePeriod: const Duration(days: 24),
      maxNrOfCacheObjects: 200,
    ),
  );

  static final CacheManager dailyStoreCacheManager = CacheManager(
    Config(
      dailyStoreCacheKey,
      stalePeriod: const Duration(hours: 7),
      maxNrOfCacheObjects: 100,
    ),
  );

  static final CacheManager tierImageCacheManager = CacheManager(
    Config(
      tierImageCacheKey,
      stalePeriod: const Duration(days: 365 * 100),
      maxNrOfCacheObjects: 150,
    ),
  );

  static final CacheManager loadoutPresetCacheManager = CacheManager(
    Config(
      loadoutPresetCacheKey,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 300,
    ),
  );

  static Future<double> getCacheSizeInMB(String cacheKey) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/$cacheKey');
      if (await cacheDir.exists()) {
        int totalSize = 0;
        await for (final file in cacheDir.list(
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

  static Future<void> clearCache(CacheManager manager, String cacheKey) async {
    try {
      await manager.emptyCache();
    } catch (_) {}

    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/$cacheKey');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (_) {}
  }
}
