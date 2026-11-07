import 'package:valorant_thunai/providers/skin_provider.dart';

class WeaponAssetResolver {
  static String extractSkinDisplayIcon(dynamic skinMap) {
    if (skinMap == null || skinMap is! Map) return '';

    final displayIcon = skinMap['displayIcon'] as String?;
    if (displayIcon != null && displayIcon.isNotEmpty) {
      return displayIcon;
    }

    final chromas = skinMap['chromas'] as List? ?? [];
    for (var c in chromas) {
      if (c is Map) {
        final fullRender = c['fullRender'] as String?;
        if (fullRender != null && fullRender.isNotEmpty) {
          return fullRender;
        }
        final cIcon = c['displayIcon'] as String?;
        if (cIcon != null && cIcon.isNotEmpty) {
          return cIcon;
        }
      }
    }

    final levels = skinMap['levels'] as List? ?? [];
    for (var l in levels) {
      if (l is Map) {
        final lIcon = l['displayIcon'] as String?;
        if (lIcon != null && lIcon.isNotEmpty) {
          return lIcon;
        }
      }
    }

    return '';
  }

  static String resolveSkinImageUrl({
    required dynamic weapon,
    String? skinId,
    String? skinLevelId,
    String? chromaId,
    required Map<String, SkinMetadata> skinsMap,
  }) {
    String skinImageUrl = '';

    SkinMetadata? skinMeta;
    if (chromaId != null && chromaId.isNotEmpty) {
      skinMeta = skinsMap[chromaId] ?? skinsMap[chromaId.toLowerCase()];
    }
    if (skinMeta == null && skinLevelId != null && skinLevelId.isNotEmpty) {
      skinMeta = skinsMap[skinLevelId] ?? skinsMap[skinLevelId.toLowerCase()];
    }
    if (skinMeta == null && skinId != null && skinId.isNotEmpty) {
      skinMeta = skinsMap[skinId] ?? skinsMap[skinId.toLowerCase()];
    }

    if (skinMeta != null) {
      if (chromaId != null && chromaId.isNotEmpty) {
        try {
          final chroma = skinMeta.chromas.firstWhere(
            (c) => c.uuid.toLowerCase() == chromaId.toLowerCase(),
          );
          if (chroma.displayIcon.isNotEmpty) {
            skinImageUrl = chroma.displayIcon;
          }
        } catch (_) {}
      }

      if (skinImageUrl.isEmpty && skinMeta.displayIcon.isNotEmpty) {
        skinImageUrl = skinMeta.displayIcon;
      }

      if (skinImageUrl.isEmpty && skinMeta.chromas.isNotEmpty) {
        for (var c in skinMeta.chromas) {
          if (c.displayIcon.isNotEmpty) {
            skinImageUrl = c.displayIcon;
            break;
          }
        }
      }
    }

    if (skinImageUrl.isEmpty && weapon != null && weapon is Map) {
      final defaultSkinUuid = weapon['defaultSkinUuid'] as String?;
      final skins = weapon['skins'] as List? ?? [];
      if (defaultSkinUuid != null && defaultSkinUuid.isNotEmpty) {
        try {
          final defSkin = skins.firstWhere(
            (s) =>
                (s['uuid'] as String).toLowerCase() ==
                defaultSkinUuid.toLowerCase(),
          );
          skinImageUrl = extractSkinDisplayIcon(defSkin);
        } catch (_) {}
      }

      if (skinImageUrl.isEmpty && skins.isNotEmpty) {
        for (var s in skins) {
          skinImageUrl = extractSkinDisplayIcon(s);
          if (skinImageUrl.isNotEmpty) break;
        }
      }

      if (skinImageUrl.isEmpty) {
        skinImageUrl = weapon['displayIcon'] ?? weapon['killStreamIcon'] ?? '';
      }
    }

    return skinImageUrl;
  }

  static String? resolveBuddyImageUrl({
    String? charmId,
    required Map<String, dynamic> buddiesMap,
  }) {
    if (charmId == null || charmId.isEmpty) return null;
    final buddy = buddiesMap[charmId];
    return buddy?['displayIcon'] as String?;
  }

  static String? resolveBuddyName({
    String? charmId,
    required Map<String, dynamic> buddiesMap,
  }) {
    if (charmId == null || charmId.isEmpty) return null;
    final buddy = buddiesMap[charmId];
    return buddy?['displayName'] as String?;
  }
}
