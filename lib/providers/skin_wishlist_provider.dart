import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/services/skin_wishlist_service.dart';

final skinWishlistProvider =
    NotifierProvider<SkinWishlistNotifier, Set<String>>(() {
      return SkinWishlistNotifier();
    });

class SkinWishlistNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    _load();
    return <String>{};
  }

  Future<void> _load() async {
    state = await SkinWishlistService.getWishlist();
  }

  bool isWishlisted(String skinId) => state.contains(skinId);

  Future<void> toggle(String skinId) async {
    state = await SkinWishlistService.toggle(skinId);
  }

  Future<void> remove(String skinId) async {
    state = await SkinWishlistService.remove(skinId);
  }
}
