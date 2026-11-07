import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_thunai/models/favorite_item.dart';
import 'package:valorant_thunai/services/logger_service.dart';

class SkinChroma {
  final String uuid;
  final String displayName;
  final String displayIcon;
  final String? swatch;
  final String? streamedVideo;

  SkinChroma({
    required this.uuid,
    required this.displayName,
    required this.displayIcon,
    this.swatch,
    this.streamedVideo,
  });
}

class SkinLevel {
  final String uuid;
  final String displayName;
  final String? levelItem;
  final String? streamedVideo;

  SkinLevel({
    required this.uuid,
    required this.displayName,
    this.levelItem,
    this.streamedVideo,
  });
}

class SkinMetadata {
  final String uuid;
  final String displayName;
  final String displayIcon;
  final String? contentTierUuid;
  final List<SkinChroma> chromas;
  final List<SkinLevel> levels;

  SkinMetadata({
    required this.uuid,
    required this.displayName,
    required this.displayIcon,
    this.contentTierUuid,
    this.chromas = const [],
    this.levels = const [],
  });
}

final skinsMetadataProvider = FutureProvider<Map<String, SkinMetadata>>((
  ref,
) async {
  final response = await http.get(
    Uri.parse('https://valorant-api.com/v1/weapons/skins'),
  );
  LoggerService.log(
    'Fetched skins metadata from Valorant-API. Status: ${response.statusCode}',
    tag: 'SkinsMetadata',
  );
  if (response.statusCode == 200) {
    final List data = jsonDecode(response.body)['data'];
    final Map<String, SkinMetadata> map = {};

    for (var skin in data) {
      final List chromasData = skin['chromas'] ?? [];
      final List levelsData = skin['levels'] ?? [];

      final List<SkinChroma> parsedChromas = chromasData
          .map(
            (c) => SkinChroma(
              uuid: c['uuid'],
              displayName: c['displayName'],
              displayIcon: c['fullRender'] ?? c['displayIcon'] ?? '',
              swatch: c['swatch'],
              streamedVideo: c['streamedVideo'],
            ),
          )
          .toList();

      final List<SkinLevel> parsedLevels = [];
      for (var level in levelsData) {
        final levelUuid = level['uuid'];
        parsedLevels.add(
          SkinLevel(
            uuid: levelUuid,
            displayName: level['displayName'],
            levelItem: level['levelItem'],
            streamedVideo: level['streamedVideo'],
          ),
        );
      }

      String defaultIcon = skin['displayIcon'] ?? '';
      if (defaultIcon.isEmpty && parsedChromas.isNotEmpty) {
        defaultIcon = parsedChromas.first.displayIcon;
      }
      if (defaultIcon.isEmpty && parsedLevels.isNotEmpty) {
        for (var l in levelsData) {
          if (l['displayIcon'] != null &&
              (l['displayIcon'] as String).isNotEmpty) {
            defaultIcon = l['displayIcon'];
            break;
          }
        }
      }

      final skinUuid = (skin['uuid'] as String).toLowerCase();
      final meta = SkinMetadata(
        uuid: skinUuid,
        displayName: skin['displayName'] ?? '',
        displayIcon: defaultIcon,
        contentTierUuid: skin['contentTierUuid'],
        chromas: parsedChromas,
        levels: parsedLevels,
      );

      map[skinUuid] = meta;
      map[skin['uuid']] = meta;

      for (var level in levelsData) {
        final levelUuid = (level['uuid'] as String).toLowerCase();
        final lMeta = SkinMetadata(
          uuid: levelUuid,
          displayName: skin['displayName'] ?? '',
          displayIcon: (level['displayIcon'] as String?)?.isNotEmpty == true
              ? level['displayIcon']
              : defaultIcon,
          contentTierUuid: skin['contentTierUuid'],
          chromas: parsedChromas,
          levels: parsedLevels,
        );
        map[levelUuid] = lMeta;
        map[level['uuid']] = lMeta;
      }

      for (var chroma in parsedChromas) {
        final chromaUuid = chroma.uuid.toLowerCase();
        final cMeta = SkinMetadata(
          uuid: chromaUuid,
          displayName: chroma.displayName.isNotEmpty
              ? chroma.displayName
              : (skin['displayName'] ?? ''),
          displayIcon: chroma.displayIcon.isNotEmpty
              ? chroma.displayIcon
              : defaultIcon,
          contentTierUuid: skin['contentTierUuid'],
          chromas: parsedChromas,
          levels: parsedLevels,
        );
        map[chromaUuid] = cMeta;
        map[chroma.uuid] = cMeta;
      }
    }
    return map;
  } else {
    LoggerService.log(
      'Error status from Valorant-API: ${response.statusCode}, body: ${response.body}',
      tag: 'SkinsMetadata',
    );
  }
  throw Exception('Failed to load skin metadata (${response.statusCode})');
});

class BundleMetadata {
  final String uuid;
  final String displayName;
  final String displayIcon;
  final String? displayIcon2;
  final String? verticalPromoImage;
  final String? description;

  BundleMetadata({
    required this.uuid,
    required this.displayName,
    required this.displayIcon,
    this.displayIcon2,
    this.verticalPromoImage,
    this.description,
  });
}

final bundlesMetadataProvider = FutureProvider<Map<String, BundleMetadata>>((
  ref,
) async {
  final response = await http.get(
    Uri.parse('https://valorant-api.com/v1/bundles'),
  );
  if (response.statusCode == 200) {
    final List data = jsonDecode(response.body)['data'];
    final Map<String, BundleMetadata> map = {};

    for (var b in data) {
      map[b['uuid']] = BundleMetadata(
        uuid: b['uuid'],
        displayName: b['displayName'],
        displayIcon: b['displayIcon'] ?? b['displayIcon2'] ?? '',
        displayIcon2: b['displayIcon2'],
        verticalPromoImage: b['verticalPromoImage'],
        description: b['description'],
      );
    }
    return map;
  }
  throw Exception('Failed to load bundle metadata');
});

class ContentTier {
  final String uuid;
  final String displayName;
  final String displayIcon;
  final String color;

  ContentTier({
    required this.uuid,
    required this.displayName,
    required this.displayIcon,
    required this.color,
  });
}

final contentTiersProvider = FutureProvider<Map<String, ContentTier>>((
  ref,
) async {
  final response = await http.get(
    Uri.parse('https://valorant-api.com/v1/contenttiers'),
  );
  if (response.statusCode == 200) {
    final List data = jsonDecode(response.body)['data'];
    final Map<String, ContentTier> map = {};

    for (var t in data) {
      map[t['uuid']] = ContentTier(
        uuid: t['uuid'],
        displayName: t['devName'],
        displayIcon: t['displayIcon'] ?? '',
        color: t['highlightColor'] ?? 'FFFFFFFF',
      );
    }
    return map;
  }
  throw Exception('Failed to load content tiers');
});

final playerCardsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final response = await http.get(
    Uri.parse('https://valorant-api.com/v1/playercards'),
  );
  if (response.statusCode == 200) {
    final List data = jsonDecode(response.body)['data'];
    return {for (var item in data) item['uuid']: item};
  }
  throw Exception('Failed to load player cards');
});

final titlesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final response = await http.get(
    Uri.parse('https://valorant-api.com/v1/playertitles'),
  );
  if (response.statusCode == 200) {
    final List data = jsonDecode(response.body)['data'];
    return {for (var item in data) item['uuid']: item};
  }
  throw Exception('Failed to load player titles');
});

final buddiesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final response = await http.get(
    Uri.parse('https://valorant-api.com/v1/buddies'),
  );
  if (response.statusCode == 200) {
    final List data = jsonDecode(response.body)['data'];
    final Map<String, dynamic> map = {};
    for (var item in data) {
      map[item['uuid']] = item;
      final levels = item['levels'] as List? ?? [];
      for (var level in levels) {
        if (level['uuid'] != null) {
          map[level['uuid']] = item;
        }
      }
    }
    return map;
  }
  throw Exception('Failed to load buddies');
});

final spraysProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final response = await http.get(
    Uri.parse('https://valorant-api.com/v1/sprays'),
  );
  if (response.statusCode == 200) {
    final List data = jsonDecode(response.body)['data'];
    return {for (var item in data) item['uuid']: item};
  }
  throw Exception('Failed to load sprays');
});

class FavoritesNotifier extends Notifier<Map<String, FavoriteItem>> {
  static const String _oldFavoritesKey = 'favorite_skins';
  static const String _favoritesKey = 'favorites_data';

  @override
  Map<String, FavoriteItem> build() {
    _loadFavorites();
    return {};
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, FavoriteItem> loadedFavorites = {};

    final oldList = prefs.getStringList(_oldFavoritesKey);
    if (oldList != null) {
      final now = DateTime.now();
      for (var id in oldList) {
        loadedFavorites[id] = FavoriteItem(
          id: id,
          originalDate: now,
          updatedDate: now,
          isFavorite: true,
        );
      }
      await prefs.remove(_oldFavoritesKey);
      await _saveFavorites(prefs, loadedFavorites);
    } else {
      final jsonStr = prefs.getString(_favoritesKey);
      if (jsonStr != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(jsonStr);
          decoded.forEach((key, value) {
            loadedFavorites[key] = FavoriteItem.fromJson(value);
          });
        } catch (_) {
          loadedFavorites.clear();
        }
      }
    }
    state = loadedFavorites;
  }

  Future<void> _saveFavorites(
    SharedPreferences prefs,
    Map<String, FavoriteItem> data,
  ) async {
    final Map<String, dynamic> jsonMap = {};
    data.forEach((key, value) {
      jsonMap[key] = value.toJson();
    });
    await prefs.setString(_favoritesKey, jsonEncode(jsonMap));
  }

  Future<void> toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final map = Map<String, FavoriteItem>.from(state);

    if (map.containsKey(id)) {
      final existing = map[id]!;
      map[id] = existing.copyWith(
        isFavorite: !existing.isFavorite,
        updatedDate: DateTime.now(),
      );
    } else {
      final now = DateTime.now();
      map[id] = FavoriteItem(
        id: id,
        originalDate: now,
        updatedDate: now,
        isFavorite: true,
      );
    }

    await _saveFavorites(prefs, map);
    state = map;
  }

  Future<void> clearAllFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_favoritesKey);
    state = {};
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, Map<String, FavoriteItem>>(() {
      return FavoritesNotifier();
    });
