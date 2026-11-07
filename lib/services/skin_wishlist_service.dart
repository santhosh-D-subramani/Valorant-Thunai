import 'package:shared_preferences/shared_preferences.dart';

import 'logger_service.dart';

class SkinWishlistService {
  static const String _wishlistKey = 'skin_wishlist_v1';
  static const String _notifiedPrefix = 'skin_wishlist_notified_v1_';

  static Future<Set<String>> getWishlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_wishlistKey)?.toSet() ?? <String>{};
    } catch (e) {
      LoggerService.log(
        'Failed to read skin wishlist: $e',
        tag: 'SkinWishlist',
      );
      return <String>{};
    }
  }

  static Future<void> _save(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_wishlistKey, ids.toList());
  }

  static Future<Set<String>> toggle(String skinId) async {
    final current = await getWishlist();
    final updated = Set<String>.from(current);
    if (updated.contains(skinId)) {
      updated.remove(skinId);
    } else {
      updated.add(skinId);
    }
    await _save(updated);
    return updated;
  }

  static Future<Set<String>> remove(String skinId) async {
    final current = await getWishlist();
    if (!current.contains(skinId)) return current;
    final updated = Set<String>.from(current)..remove(skinId);
    await _save(updated);
    return updated;
  }

  static String _notifiedKey(String skinId, String rotationId) =>
      '$_notifiedPrefix${skinId}_$rotationId';

  static Future<bool> shouldNotifyPresence(
    String skinId,
    String rotationId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _notifiedKey(skinId, rotationId);
      final alreadyNotified = prefs.getBool(key) ?? false;
      if (alreadyNotified) return false;
      await prefs.setBool(key, true);
      return true;
    } catch (e) {
      LoggerService.log(
        'Failed to check skin wishlist notify state: $e',
        tag: 'SkinWishlist',
      );
      return false;
    }
  }
}
