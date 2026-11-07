import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_thunai/main.dart' show prefs;
import 'package:valorant_thunai/services/valorant_api.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/providers/skin_provider.dart';
import 'package:valorant_thunai/services/logger_service.dart';
import 'package:valorant_thunai/screens/media/skin_details_screen.dart';
import 'package:valorant_thunai/screens/accessories/accessory_inspector.dart';
import 'package:valorant_thunai/screens/bundles/bundle_detail_screen.dart';
import 'package:valorant_thunai/screens/home/favorites_screen.dart';
import 'package:valorant_thunai/screens/loadout/auto_loadouts_screen.dart';
import 'package:valorant_thunai/screens/loadout/loadout_presets_screen.dart';
import 'package:valorant_thunai/models/loadout_preset.dart';
import 'package:valorant_thunai/providers/preset_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/utils/cache_managers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';
import 'package:valorant_thunai/services/widget_sync_service.dart';
import 'package:valorant_thunai/services/notification_service.dart';
import 'package:valorant_thunai/services/shop_history_service.dart';
import 'package:valorant_thunai/screens/shop/shop_history_screen.dart';
import 'package:valorant_thunai/widgets/hanging_sasuke_charm.dart';
import 'package:valorant_thunai/providers/display_settings_provider.dart';
import 'package:valorant_thunai/providers/skin_wishlist_provider.dart';
import 'package:valorant_thunai/services/skin_wishlist_service.dart';
import 'package:valorant_thunai/screens/shop/skin_wishlist_screen.dart';
import 'package:valorant_thunai/utils/format_utils.dart';

enum _ShopMenuAction { favorites, history, wishlist }

const Map<String, Map<String, String>> _fallbackTiers = {
  '12683d76-48d7-84a3-4e09-6985794f0445': {
    'color': '5a9fe233',
    'displayIcon': 'https://media.valorant-api.com/contenttiers/12683d76-48d7-84a3-4e09-6985794f0445/displayicon.png',
  },
  '0cebb8be-46d7-c12a-d306-e9907bfc5a25': {
    'color': '00958733',
    'displayIcon': 'https://media.valorant-api.com/contenttiers/0cebb8be-46d7-c12a-d306-e9907bfc5a25/displayicon.png',
  },
  '60bca009-4182-7998-dee7-b8a2558dc369': {
    'color': 'd1548d33',
    'displayIcon': 'https://media.valorant-api.com/contenttiers/60bca009-4182-7998-dee7-b8a2558dc369/displayicon.png',
  },
  '411e4a55-4e59-7757-41f0-86a53f101bb5': {
    'color': 'fad66333',
    'displayIcon': 'https://media.valorant-api.com/contenttiers/411e4a55-4e59-7757-41f0-86a53f101bb5/displayicon.png',
  },
  'e046854e-406c-37f4-6607-19a9ba8426fc': {
    'color': 'f5955b33',
    'displayIcon': 'https://media.valorant-api.com/contenttiers/e046854e-406c-37f4-6607-19a9ba8426fc/displayicon.png',
  },
};

class DailyShopScreen extends ConsumerStatefulWidget {
  const DailyShopScreen({super.key});

  @override
  ConsumerState<DailyShopScreen> createState() => _DailyShopScreenState();
}

class _DailyShopScreenState extends ConsumerState<DailyShopScreen> {
  bool _isLoadingShop = false;
  bool _isOffline = false;
  bool _showSasuke =
      DateTime.now().month == 7 &&
      (DateTime.now().day == 22 || DateTime.now().day == 23);
  Map<String, dynamic>? _shopData;
  Timer? _countdownTimer;
  int _remainingDurationInSeconds = 0;
  int _accessoryRemainingDurationInSeconds = 0;
  int _bonusStoreRemainingDurationInSeconds = 0;
  Map<String, int> _bundleRemainingDurationMap = {};

  bool _dailyOffersExpanded = true;
  bool _blackMarketExpanded = true;
  bool _weeklyAccessoriesExpanded = true;

  String? _lastPuuid;
  String? _lastAccessToken;

  Map<String, int> _daysSinceLastSeen = {};

  @override
  void initState() {
    super.initState();
    _checkSasukePref();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        _lastPuuid = user.puuid;
        _lastAccessToken = user.accessToken;
        _fetchShop();
      }
    });
  }

  Future<void> _checkSasukePref() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final isBirthdayOrEve = now.month == 7 && (now.day == 22 || now.day == 23);
    if (!isBirthdayOrEve) {
      if (mounted) {
        setState(() {
          _showSasuke = false;
        });
      }
    } else {
      final dontShow = prefs.getBool('show_sasuke_appbar') == false;
      if (mounted) {
        setState(() {
          _showSasuke = !dontShow;
        });
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  static const List<String> sasukeFacts = [
    'Fun fact: Sasuke is actually left-handed, but he wields his sword and uses Chidori with his right hand!',
    'Fun fact: Sasuke\'s favorite foods are omusubi with okaka and tomatoes.',
    'Fun fact: Sasuke\'s least favorite foods are natto and anything sweet.',
    'Fun fact: Sasuke\'s name comes from Sasuke Sarutobi, the father of the Third Hokage.',
    'Fun fact: Sasuke didn\'t exist in the original concept for Naruto; Kishimoto\'s editor suggested adding a rival!',
    'Fun fact: Sasuke is one of the few characters who never uses honorifics, speaking strictly without them to almost everyone.',
    'Fun fact: The Uchiha clan crest is a fan, which references their affinity for fire jutsu (fanning the flames).',
    'Fun fact: Sasuke was the youngest student in his Academy class to graduate.',
    'Fun fact: Sasuke\'s Mangekyo Sharingan design is an inverted color scheme of his regular Sharingan.',
    'Fun fact: In Boruto, Sasuke is the only shinobi to fight Otsutsuki level threats with just one arm.',
    'Fun fact: Kishimoto has stated that Sasuke is his favorite character to draw, despite the difficulty.',
    'Fun fact: Sasuke\'s signature jutsu, Kirin, is named after a mythical chimerical beast from Chinese mythology.',
    'Fun fact: Throughout the series, Sasuke changes his outfit more times than any other main character.',
    'Fun fact: Sasuke\'s voice actor in Japanese, Noriaki Sugiyama, also voices Uryu Ishida in Bleach!',
    'Fun fact: Sasuke possesses the unique straight tomoe Mangekyo Sharingan, granting him superior fluidity in movement.',
  ];

  Future<void> _showSasukeDialog() async {
    bool dontShowAgain = false;
    final random = math.Random();
    final String funFact = sasukeFacts[random.nextInt(sasukeFacts.length)];
    final now = DateTime.now();
    final isBirthdayTomorrow = now.month == 7 && now.day == 22;
    final String titleText = isBirthdayTomorrow
        ? "Sasuke's birthday tomorrow"
        : "Happy birthday, Sasuke";

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 28),
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFFB8A8FF).withValues(alpha: 0.28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.38),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF15121F),
                      Color(0xFF211832),
                      Color(0xFF111820),
                    ],
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      right: -46,
                      top: -42,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(22),
                        ),
                        child: Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF7C5CFF).withValues(alpha: 0.58),
                                const Color(0xFFFF4655).withValues(alpha: 0.10),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -12,
                      top: -35,
                      child: Opacity(
                        opacity: 0.92,
                        child: Image.asset(
                          'assets/sasuke.webp',
                          height: 175,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 80),
                            child: Text(
                              'UCHIHA FILE',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.7,
                                color: const Color(0xFFFFD166),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(right: 80),
                            child: Text(
                              titleText,
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.04,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.only(right: 65),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.10),
                                ),
                              ),
                              child: Text(
                                funFact,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  height: 1.45,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.82),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setDialogState(() {
                                dontShowAgain = !dontShowAgain;
                              });
                              setState(() {
                                _showSasuke = !dontShowAgain;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      color: dontShowAgain
                                          ? const Color(0xFFFF4655)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: dontShowAgain
                                            ? const Color(0xFFFF8A95)
                                            : Colors.white.withValues(
                                                alpha: 0.45,
                                              ),
                                      ),
                                    ),
                                    child: dontShowAgain
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 14,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Don\'t show sasuke anymore',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withValues(
                                          alpha: 0.76,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: const Color(0xFFFF4655),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(dialogContext);
                              },
                              child: Text(
                                'Close',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    await prefs.setBool('show_sasuke_appbar', !dontShowAgain);
    if (mounted) {
      setState(() {
        _showSasuke = !dontShowAgain;
      });
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingDurationInSeconds > 0) {
          _remainingDurationInSeconds--;
        }
        if (_accessoryRemainingDurationInSeconds > 0) {
          _accessoryRemainingDurationInSeconds--;
        }
        if (_bonusStoreRemainingDurationInSeconds > 0) {
          _bonusStoreRemainingDurationInSeconds--;
        }
        _bundleRemainingDurationMap.updateAll(
          (key, val) => val > 0 ? val - 1 : 0,
        );
      });
    });
  }

  void _fetchShop({bool forceRefresh = false}) async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user != null) {
      final api = ref.read(valorantApiProvider);

      if (forceRefresh) {
        ref
            .read(authProvider.notifier)
            .refreshProfile(authState.activeUserIndex);
      }

      setState(() {
        _isLoadingShop = true;
        _isOffline = false;
      });

      try {
        final data = await api.getStorefrontWithCache(
          shard: user.shard,
          puuid: user.puuid,
          accessToken: user.accessToken,
          entitlementsToken: user.entitlementsToken,
          forceRefresh: forceRefresh,
        );

        if (!mounted) return;

        int remainingSeconds = 0;
        final skinsPanel = data['SkinsPanelLayout'];
        if (skinsPanel != null) {
          remainingSeconds =
              skinsPanel['SingleItemOffersRemainingDurationInSeconds'] ?? 0;
        }

        final Map<String, int> bundleSeconds = {};
        final featuredBundle = data['FeaturedBundle'];
        if (featuredBundle != null) {
          final List bundlesList = [];
          if (featuredBundle['Bundles'] != null) {
            bundlesList.addAll(featuredBundle['Bundles']);
          } else if (featuredBundle['Bundle'] != null) {
            bundlesList.add(featuredBundle['Bundle']);
          }

          for (var b in bundlesList) {
            final String bundleId = b['DataAssetID'] ?? b['ID'] ?? '';
            final int seconds =
                b['RemainingDurationInSeconds'] ??
                b['DurationRemainingInSeconds'] ??
                0;
            if (bundleId.isNotEmpty) {
              bundleSeconds[bundleId] = seconds;
            }
          }
        }

        final accessoryStore = data['AccessoryStore'];
        int accessoryRemainingSeconds = 0;
        if (accessoryStore != null) {
          accessoryRemainingSeconds =
              accessoryStore['AccessoryStoreRemainingDurationInSeconds'] ?? 0;
        }

        final bonusStore = data['BonusStore'];
        int bonusStoreRemainingSeconds = 0;
        if (bonusStore != null) {
          bonusStoreRemainingSeconds =
              bonusStore['BonusStoreRemainingDurationInSeconds'] ?? 0;
        }

        if (bonusStore != null && bonusStoreRemainingSeconds > 0) {
          _maybeNotifyNightMarket(bonusStoreRemainingSeconds);
        }

        setState(() {
          _shopData = data;
          _isLoadingShop = false;
          _remainingDurationInSeconds = remainingSeconds;
          _accessoryRemainingDurationInSeconds = accessoryRemainingSeconds;
          _bonusStoreRemainingDurationInSeconds = bonusStoreRemainingSeconds;
          _bundleRemainingDurationMap = bundleSeconds;
        });

        _startTimer();
        _syncToWidget(data, remainingSeconds);
        if (skinsPanel != null) {
          final List offers = skinsPanel['SingleItemOffers'] ?? [];
          final offerIds = offers.map((e) => e.toString()).toList();
          await ShopHistoryService.recordToday(
            user.puuid,
            offerIds,
            remainingSeconds: remainingSeconds,
          );
          _checkWishlistedSkinsInShop(offers, remainingSeconds);
          _loadDaysSinceLastSeen(user.puuid, offerIds);
        }
      } catch (e) {
        if (!mounted) return;

        LoggerService.log("Storefront fetch failed: $e", tag: 'ValorantApi');

        bool hasInternet = true;
        try {
          final result = await InternetAddress.lookup('google.com')
              .timeout(const Duration(seconds: 5));
          hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        } catch (_) {
          hasInternet = false;
        }

        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;

        setState(() {
          if (!hasInternet) {
            _isOffline = true;
            _isLoadingShop = false;
            if (_shopData != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.noInternetShopRefreshFailed)),
              );
            }
          } else {
            _isOffline = false;
            if (_shopData == null) {
              _isLoadingShop = true;
            } else {
              _isLoadingShop = false;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.failedToRefreshShop(e.toString()))),
              );
            }
          }
        });
      }
    }
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00:00';
    final hours = (totalSeconds / 3600).floor();
    final minutes = ((totalSeconds % 3600) / 60).floor();
    final seconds = totalSeconds % 60;

    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');
    return '$hStr:$mStr:$sStr';
  }

  String _formatBundleDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00:00';
    final days = (totalSeconds / 86400).floor();
    final hours = ((totalSeconds % 86400) / 3600).floor();
    final minutes = ((totalSeconds % 3600) / 60).floor();
    final seconds = totalSeconds % 60;

    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');

    if (days > 0) {
      return '${days}d $hStr:$mStr:$sStr';
    } else {
      return '$hStr:$mStr:$sStr';
    }
  }

  Color _parseRiotColor(String hexStr, {double? overrideAlpha}) {
    var hex = hexStr.replaceAll('#', '').trim();
    if (hex.length == 8) {
      final r = hex.substring(0, 2);
      final g = hex.substring(2, 4);
      final b = hex.substring(4, 6);
      final a = hex.substring(6, 8);

      if (overrideAlpha != null) {
        final alphaInt = (overrideAlpha * 255).clamp(0, 255).round();
        final alphaHex = alphaInt
            .toRadixString(16)
            .padLeft(2, '0')
            .toUpperCase();
        hex = '$alphaHex$r$g$b';
      } else {
        hex = '$a$r$g$b';
      }
    } else if (hex.length == 6) {
      if (overrideAlpha != null) {
        final alphaInt = (overrideAlpha * 255).clamp(0, 255).round();
        final alphaHex = alphaInt
            .toRadixString(16)
            .padLeft(2, '0')
            .toUpperCase();
        hex = '$alphaHex$hex';
      } else {
        hex = 'FF$hex';
      }
    } else {
      return Colors.grey;
    }
    return Color(int.parse(hex, radix: 16));
  }

  ContentTier? _getTier(
    String? contentTierUuid,
    Map<String, ContentTier>? tiersMap,
  ) {
    if (contentTierUuid == null) return null;
    if (tiersMap != null && tiersMap.containsKey(contentTierUuid)) {
      return tiersMap[contentTierUuid];
    }
    if (_fallbackTiers.containsKey(contentTierUuid)) {
      final fb = _fallbackTiers[contentTierUuid]!;
      return ContentTier(
        uuid: contentTierUuid,
        displayName: '',
        displayIcon: fb['displayIcon']!,
        color: fb['color']!,
      );
    }
    return null;
  }

  Future<void> _loadDaysSinceLastSeen(
    String puuid,
    List<String> offerIds,
  ) async {
    try {
      final entries = await ShopHistoryService.getHistory(puuid);
      final today = DateTime.now();
      final priorEntries = entries
          .where(
            (e) =>
                e.date.year != today.year ||
                e.date.month != today.month ||
                e.date.day != today.day,
          )
          .toList();
      final Map<String, int> result = {};
      for (final id in offerIds) {
        final days = ShopHistoryService.daysSinceLastSeen(priorEntries, id);
        if (days != null) result[id] = days;
      }
      if (mounted) {
        setState(() {
          _daysSinceLastSeen = result;
        });
      }
    } catch (e) {
      LoggerService.log(
        'Failed to compute days-since-last-seen: $e',
        tag: 'ShopHistory',
      );
    }
  }

  Future<void> _maybeNotifyNightMarket(int remainingSeconds) async {
    try {
      final enabled = prefs.getBool('night_market_alerts_enabled') ?? true;
      if (!enabled) return;

      final rotationEnd = DateTime.now().add(
        Duration(seconds: remainingSeconds),
      );
      final rotationId =
          'night_market_${rotationEnd.year}-${rotationEnd.month}-${rotationEnd.day}';

      final lastNotifiedRotation = prefs.getString(
        'night_market_last_rotation_id',
      );
      if (lastNotifiedRotation == rotationId) return;

      await prefs.setString('night_market_last_rotation_id', rotationId);

      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      await ref
          .read(notificationProvider.notifier)
          .addLocalNotification(
            id: rotationId,
            title: l10n.nightMarketNotificationTitle,
            body: l10n.nightMarketNotificationBody,
          );
    } catch (e) {
      LoggerService.log(
        'Failed to send Night Market alert: $e',
        tag: 'NightMarket',
      );
    }
  }

  Future<void> _checkWishlistedSkinsInShop(
    List<dynamic> singleItemOffers,
    int remainingSeconds,
  ) async {
    if (singleItemOffers.isEmpty) return;
    try {
      final wishlist = await SkinWishlistService.getWishlist();
      if (wishlist.isEmpty) return;

      final rotationEnd = DateTime.now().add(
        Duration(seconds: remainingSeconds),
      );
      final rotationId =
          'skin_shop_${rotationEnd.year}-${rotationEnd.month}-${rotationEnd.day}';

      final skinsMap = await ref.read(skinsMetadataProvider.future);

      for (final offerId in singleItemOffers) {
        final skinId = offerId.toString();
        if (!wishlist.contains(skinId)) continue;

        final shouldNotify = await SkinWishlistService.shouldNotifyPresence(
          skinId,
          rotationId,
        );
        if (!shouldNotify) continue;
        if (!mounted) return;

        final l10n = AppLocalizations.of(context);
        final skinName =
            skinsMap[skinId]?.displayName ?? l10n?.noName ?? skinId;

        await ref
            .read(notificationProvider.notifier)
            .addLocalNotification(
              id: 'skin_wishlist_${skinId}_$rotationId',
              title:
                  l10n?.wishlistSkinInShopTitle ??
                  'Wishlisted skin in today\'s shop',
              body:
                  l10n?.wishlistSkinInShopBody(skinName) ??
                  '$skinName is available in your shop today!',
              payload: skinId,
            );
      }
    } catch (e) {
      LoggerService.log(
        'Failed to check wishlisted skins in shop: $e',
        tag: 'SkinWishlist',
      );
    }
  }

  Widget _buildPresetQuickSwap(BuildContext context) {
    final theme = Theme.of(context);
    final presets = ref.watch(presetsProvider).value ?? const <LoadoutPreset>[];
    if (presets.isEmpty) return const SizedBox.shrink();

    final quickPresets = presets.take(8).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.swap_horiz,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Quick Loadout Swap',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoadoutPresetsScreen(),
                    ),
                  );
                },
                child: const Text('Manage', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: quickPresets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final preset = quickPresets[i];
                return ActionChip(
                  avatar: const Icon(Icons.checkroom, size: 16),
                  label: Text(preset.name),
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  onPressed: () => _confirmApplyPreset(preset),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmApplyPreset(LoadoutPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Apply "${preset.name}"?'),
        content: const Text(
          'This pushes these weapon skins to your equipped loadout in-game right now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(presetsProvider.notifier).applyPresetToGame(preset);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Applied "${preset.name}" to your loadout')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to apply preset: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _syncToWidget(
    Map<String, dynamic> data,
    int remainingSeconds,
  ) async {
    try {
      final skinsPanel = data['SkinsPanelLayout'];
      if (skinsPanel == null) return;
      final List singleItemOffers = skinsPanel['SingleItemOffers'] ?? [];
      final List singleItemStoreOffers =
          skinsPanel['SingleItemStoreOffers'] ?? [];

      final Map<String, int> prices = {};
      for (var offer in singleItemStoreOffers) {
        final String? offerId = offer['OfferID'] ?? offer['offerId'];
        if (offerId == null) continue;
        final costs = offer['Costs'] ?? offer['Cost'];
        if (costs is Map) {
          int price =
              (costs['85ad13f7-3d1b-1612-dae0-a682f310051c'] ??
              costs['85ad13f73d1b1612dae0a682f310051c'] ??
              0);
          if (price == 0 && costs.isNotEmpty) {
            final values = costs.values.toList();
            if (values.isNotEmpty && values[0] is int) {
              price = values[0];
            }
          }
          prices[offerId] = price;
        }
      }

      final skinsMetadata = await ref.read(skinsMetadataProvider.future);
      final tiersMap = await ref.read(contentTiersProvider.future);

      final List<Map<String, dynamic>> preparedSkins = [];
      for (var offerId in singleItemOffers) {
        final meta = skinsMetadata[offerId];
        final name = meta?.displayName ?? 'Valorant Weapon';
        final iconUrl = meta?.displayIcon ?? '';
        final price = prices[offerId]?.toString() ?? '0';
        final tier = _getTier(meta?.contentTierUuid, tiersMap);
        final tierColor = tier?.color ?? '#FFFF4655';

        preparedSkins.add({
          'name': name,
          'price': price,
          'iconUrl': iconUrl,
          'tierColor': tierColor,
        });
      }

      final expiry = await _computeWidgetExpiry();

      await WidgetSyncService.syncDailyShop(
        skins: preparedSkins,
        remainingDurationInSeconds: remainingSeconds,
        expiryLabel: expiry?.$1,
        expirySeconds: expiry?.$2,
      );
    } catch (e) {
      LoggerService.log('Error syncing widget: $e', tag: 'Widget');
    }
  }

  Future<(String, int)?> _computeWidgetExpiry() async {
    if (_bonusStoreRemainingDurationInSeconds > 0) {
      final l10n = mounted ? AppLocalizations.of(context) : null;
      return (
        l10n?.nightMarketHeader ?? 'Night Market',
        _bonusStoreRemainingDurationInSeconds,
      );
    }

    if (_bundleRemainingDurationMap.isEmpty) return null;
    try {
      String? bestId;
      int bestSeconds = -1;
      for (final entry in _bundleRemainingDurationMap.entries) {
        if (entry.value <= 0) continue;
        if (bestSeconds == -1 || entry.value < bestSeconds) {
          bestSeconds = entry.value;
          bestId = entry.key;
        }
      }
      if (bestId == null) return null;

      final bundlesMap = await ref.read(bundlesMetadataProvider.future);
      final name = bundlesMap[bestId]?.displayName ?? 'Featured Bundle';
      return (name, bestSeconds);
    } catch (e) {
      LoggerService.log('Error computing widget expiry: $e', tag: 'Widget');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final displaySettings = ref.watch(displaySettingsProvider);

    final favorites = ref.watch(favoritesProvider);
    final skinWishlist = ref.watch(skinWishlistProvider);
    final skinsMap = ref.watch(skinsMetadataProvider).value ?? {};
    final cardsMap = ref.watch(playerCardsProvider).value ?? {};
    final buddiesMap = ref.watch(buddiesProvider).value ?? {};
    final spraysMap = ref.watch(spraysProvider).value ?? {};
    final titlesMap = ref.watch(titlesProvider).value ?? {};

    final List<String> activeFavoriteNames = [];
    if (user != null && _shopData != null) {
      final data = _shopData!;
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      final skinsPanel = data['SkinsPanelLayout'];
      final List singleItemOffers = skinsPanel != null
          ? skinsPanel['SingleItemOffers'] ?? []
          : [];
      for (var offerId in singleItemOffers) {
        final fav = favorites[offerId];
        if (fav != null &&
            fav.isFavorite &&
            fav.updatedDate.isBefore(startOfToday)) {
          final name = skinsMap[offerId]?.displayName ?? 'Favorite Skin';
          if (!activeFavoriteNames.contains(name)) {
            activeFavoriteNames.add(name);
          }
        }
      }

      final accessoryStore = data['AccessoryStore'];
      final List accessoryOffers = accessoryStore != null
          ? accessoryStore['AccessoryStoreOffers'] ?? []
          : [];
      for (var offerData in accessoryOffers) {
        final offer = offerData['Offer'];
        if (offer == null) continue;
        final rewards = offer['Rewards'] as List? ?? [];
        for (var reward in rewards) {
          final itemId = reward['ItemID'] as String? ?? '';
          final fav = favorites[itemId];
          if (fav != null &&
              fav.isFavorite &&
              fav.updatedDate.isBefore(startOfToday)) {
            final name =
                skinsMap[itemId]?.displayName ??
                buddiesMap[itemId]?['displayName'] ??
                spraysMap[itemId]?['displayName'] ??
                titlesMap[itemId]?['titleText'] ??
                cardsMap[itemId]?['displayName'] ??
                'Favorite Accessory';
            if (!activeFavoriteNames.contains(name)) {
              activeFavoriteNames.add(name);
            }
          }
        }
      }
    }

    if (user != null &&
        (user.puuid != _lastPuuid || user.accessToken != _lastAccessToken)) {
      _lastPuuid = user.puuid;
      _lastAccessToken = user.accessToken;
      _shopData = null;
      _fetchShop();
    }

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.dailyShopTitle)),
        body: Center(child: Text(l10n.pleaseLoginFirstInSettings)),
      );
    }

    if (_isOffline && _shopData == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.redAccent,
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.noInternetTitle,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.noInternetDescription,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _fetchShop(),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.retryButton),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoadingShop && _shopData == null) {
      return const Scaffold(body: FunnyLoadingView());
    }

    if (_shopData == null) {
      return const Scaffold(body: FunnyLoadingView());
    }

    final data = _shopData!;
    final skinsPanel = data['SkinsPanelLayout'];
    if (skinsPanel == null) {
      return CustomScrollView(
        slivers: [
          SliverAppBar(title: Text(l10n.dailyShopTitle), floating: true),
          SliverFillRemaining(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(const JsonEncoder.withIndent('  ').convert(data)),
              ),
            ),
          ),
        ],
      );
    }

    final List singleItemOffers = skinsPanel['SingleItemOffers'] ?? [];

    final Map<String, int> prices = {};
    final List singleItemStoreOffers =
        skinsPanel['SingleItemStoreOffers'] ?? [];

    for (var offer in singleItemStoreOffers) {
      final String? offerId = offer['OfferID'] ?? offer['offerId'];
      if (offerId == null) continue;

      final costs = offer['Costs'] ?? offer['Cost'];
      if (costs is Map) {
        int price =
            (costs['85ad13f7-3d1b-1612-dae0-a682f310051c'] ??
            costs['85ad13f73d1b1612dae0a682f310051c'] ??
            0);
        if (price == 0 && costs.isNotEmpty) {
          final values = costs.values.toList();
          if (values.isNotEmpty) {
            price = values[0] is int ? values[0] : 0;
          }
        }
        prices[offerId] = price;
      }
    }

    final featuredBundle = data['FeaturedBundle'];
    final List bundlesList = [];
    final Map<String, int> bundlePrices = {};

    if (featuredBundle != null) {
      if (featuredBundle['Bundles'] != null) {
        bundlesList.addAll(featuredBundle['Bundles']);
      } else if (featuredBundle['Bundle'] != null) {
        bundlesList.add(featuredBundle['Bundle']);
      }

      for (var b in bundlesList) {
        final String bundleId = b['DataAssetID'] ?? b['ID'] ?? '';
        if (bundleId.isNotEmpty) {
          int price = 0;
          final discountedCost = b['TotalDiscountedCost'];

          if (discountedCost is Map) {
            price =
                discountedCost['85ad13f7-3d1b-1612-dae0-a682f310051c'] ??
                discountedCost['85ad13f73d1b1612dae0a682f310051c'] ??
                0;
            if (price == 0 && discountedCost.isNotEmpty) {
              final values = discountedCost.values.toList();
              if (values.isNotEmpty && values[0] is int) {
                price = values[0];
              }
            }
          } else if (discountedCost is int) {
            price = discountedCost;
          }

          if (price == 0 && b['Costs'] is Map) {
            price = b['Costs']['85ad13f7-3d1b-1612-dae0-a682f310051c'] ?? 0;
          }
          bundlePrices[bundleId] = price;
        }
      }
    }

    final skinsMetadata = ref.watch(skinsMetadataProvider);
    final bundlesMetadata = ref.watch(bundlesMetadataProvider);
    final contentTiers = ref.watch(contentTiersProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 2 : 1;
        final isSpecialDate =
            (DateTime.now().month == 7 &&
                (DateTime.now().day == 22 || DateTime.now().day == 23)) ||
            (DateTime.now().month == 6 &&
                (DateTime.now().day == 22 || DateTime.now().day == 23));

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: !isSpecialDate,
              backgroundColor: Colors.transparent,
              actions: !isSpecialDate
                  ? [
                      _CurrencyDisplay(
                        vp: user.vp ?? 0,
                        radianite: user.radianite ?? 0,
                        kingdomCredits: user.kingdomCredits ?? 0,
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<_ShopMenuAction>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (action) {
                          switch (action) {
                            case _ShopMenuAction.favorites:
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FavoritesScreen(),
                                ),
                              );
                            case _ShopMenuAction.history:
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ShopHistoryScreen(puuid: user.puuid),
                                ),
                              );
                            case _ShopMenuAction.wishlist:
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SkinWishlistScreen(),
                                ),
                              );
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: _ShopMenuAction.favorites,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.favorite),
                              title: Text(l10n.favoritesTitle),
                            ),
                          ),
                          PopupMenuItem(
                            value: _ShopMenuAction.history,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.history),
                              title: Text(l10n.shopHistoryTitle),
                            ),
                          ),
                          PopupMenuItem(
                            value: _ShopMenuAction.wishlist,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.star),
                              title: Text(l10n.skinWishlistTitle),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                    ]
                  : null,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    if (user.playerCardId != null &&
                        user.playerCardId!.isNotEmpty &&
                        user.playerCardId !=
                            '00000000-0000-0000-0000-000000000000')
                      Image.network(
                        'https://media.valorant-api.com/playercards/${user.playerCardId}/wideart.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: Theme.of(context).colorScheme.primary
                              .withValues(alpha: 0.1),
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${user.gameName} #${user.tagline ?? ''}'
                                .toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'LEVEL ${user.level ?? 0}',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_showSasuke)
                      Positioned(
                        top: 2,
                        right: 16,
                        child: HangingSasukeCharm(onTap: _showSasukeDialog),
                      ),
                  ],
                ),
              ),
            ),

            if (isSpecialDate)
              SliverPersistentHeader(
                pinned: true,
                delegate: _CurrencyHeaderDelegate(
                  topInset: MediaQuery.paddingOf(context).top,
                  child: _CurrencyDisplay(
                    vp: user.vp ?? 0,
                    radianite: user.radianite ?? 0,
                    kingdomCredits: user.kingdomCredits ?? 0,
                  ),
                ),
              ),

            if (activeFavoriteNames.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF4655), Color(0xFFFF7685)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4655).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.favoriteItemInStoreBanner,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${activeFavoriteNames.join(", ")} is available in your store today!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                child: Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHigh
                      .withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AutoLoadoutsScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.tune,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Auto Loadouts',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .tertiaryContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'BETA',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onTertiaryContainer,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'MAP & AGENT',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Pair presets with maps or locked agents (Beta) • Apply anytime',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(child: _buildPresetQuickSwap(context)),

            SliverToBoxAdapter(
              child: _AccordionSection(
                title: l10n.dailyOffersHeader,
                icon: Icons.local_mall,
                isExpanded: _dailyOffersExpanded,
                onTap: () {
                  setState(() {
                    _dailyOffersExpanded = !_dailyOffersExpanded;
                  });
                },
                countdownText: _formatDuration(_remainingDurationInSeconds),
                onRefresh: () => _fetchShop(forceRefresh: true),
                leadingAction: isSpecialDate
                    ? IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 28,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: l10n.favoritesTitle,
                        icon: Icon(
                          Icons.favorite,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: 0.72),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FavoritesScreen(),
                            ),
                          );
                        },
                      )
                    : null,
                child: skinsMetadata.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l10n.genericError(err.toString())),
                    ),
                  ),
                  data: (metadataMap) {
                    return contentTiers.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (err, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(l10n.genericError(err.toString())),
                        ),
                      ),
                      data: (tiersMap) {
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: constraints.maxWidth > 800
                                    ? 2.5
                                    : 2.0,
                              ),
                          itemCount: singleItemOffers.length,
                          itemBuilder: (context, index) {
                            final offerId = singleItemOffers[index];
                            final price = prices[offerId] ?? 0;
                            final metadata = metadataMap[offerId];

                            if (metadata == null) {
                              return Card(
                                child: Center(child: Text('Skin $offerId')),
                              );
                            }

                            final tierUuid = metadata.contentTierUuid;
                            final tier = _getTier(tierUuid, tiersMap);
                            final opaqueColor = tier != null
                                ? _parseRiotColor(
                                    tier.color,
                                    overrideAlpha: 1.0,
                                  )
                                : Theme.of(context).colorScheme.primary;
                            final cardBgColor = tier != null
                                ? _parseRiotColor(
                                    tier.color,
                                    overrideAlpha: 0.12,
                                  )
                                : Theme.of(context).cardColor;

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SkinDetailsScreen(skin: metadata),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: cardBgColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: opaqueColor.withValues(alpha: 0.35),
                                    width: 1.5,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (tier != null &&
                                                tier.displayIcon.isNotEmpty)
                                              Image.network(
                                                tier.displayIcon,
                                                width: 20,
                                                height: 20,
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, _, _) =>
                                                    const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                    ),
                                              )
                                            else
                                              const SizedBox(
                                                width: 20,
                                                height: 20,
                                              ),
                                            Expanded(
                                              child: Container(
                                                alignment: Alignment.center,
                                                child: Hero(
                                                  tag: 'skin_$offerId',
                                                  child: CachedNetworkImage(
                                                    imageUrl:
                                                        metadata.displayIcon,
                                                    cacheManager:
                                                        CustomCacheManagers
                                                            .dailyStoreCacheManager,
                                                    fit: BoxFit.contain,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (favorites[offerId]
                                                    ?.isFavorite ==
                                                true)
                                              const Padding(
                                                padding: EdgeInsets.only(
                                                  right: 6,
                                                ),
                                                child: Icon(
                                                  Icons.star,
                                                  color: Colors.amber,
                                                  size: 20,
                                                ),
                                              ),
                                            GestureDetector(
                                              onTap: () {
                                                ref
                                                    .read(
                                                      skinWishlistProvider
                                                          .notifier,
                                                    )
                                                    .toggle(offerId);
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 4,
                                                ),
                                                child: Icon(
                                                  skinWishlist.contains(offerId)
                                                      ? Icons.star
                                                      : Icons.star_border,
                                                  color:
                                                      skinWishlist.contains(
                                                        offerId,
                                                      )
                                                      ? Colors.amber
                                                      : opaqueColor,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              Icons.chevron_right,
                                              color: opaqueColor,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  metadata.displayName,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: opaqueColor,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                _LastSeenBadge(
                                                  daysSinceLastSeen:
                                                      _daysSinceLastSeen[offerId],
                                                  color: opaqueColor,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                FormatUtils.formatNumber(
                                                  price,
                                                  displaySettings,
                                                ),
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: opaqueColor,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              ColorFiltered(
                                                colorFilter: ColorFilter.mode(
                                                  opaqueColor,
                                                  BlendMode.srcIn,
                                                ),
                                                child: Image.network(
                                                  'https://media.valorant-api.com/currencies/85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741/displayicon.png',
                                                  width: 14,
                                                  height: 14,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, _, _) =>
                                                      Icon(
                                                        Icons.circle,
                                                        size: 10,
                                                        color: opaqueColor,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            if (_shopData != null &&
                _shopData!['BonusStore'] != null &&
                (_shopData!['BonusStore']['BonusStoreOffers'] as List? ?? [])
                    .isNotEmpty)
              SliverToBoxAdapter(
                child: _AccordionSection(
                  title: l10n.blackMarket,
                  icon: Icons.percent,
                  isExpanded: _blackMarketExpanded,
                  onTap: () {
                    setState(() {
                      _blackMarketExpanded = !_blackMarketExpanded;
                    });
                  },
                  countdownText: _formatBundleDuration(
                    _bonusStoreRemainingDurationInSeconds,
                  ),
                  onRefresh: () => _fetchShop(forceRefresh: true),
                  child: skinsMetadata.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l10n.genericError(err.toString())),
                      ),
                    ),
                    data: (metadataMap) {
                      return contentTiers.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (err, _) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(l10n.genericError(err.toString())),
                          ),
                        ),
                        data: (tiersMap) {
                          final bonusStoreOffers =
                              _shopData!['BonusStore']['BonusStoreOffers']
                                  as List;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: constraints.maxWidth > 800
                                      ? 2.5
                                      : 2.0,
                                ),
                            itemCount: bonusStoreOffers.length,
                            itemBuilder: (context, index) {
                              final offerData = bonusStoreOffers[index];
                              final offer = offerData['Offer'];
                              if (offer == null) return const SizedBox.shrink();

                              final rewards = offer['Rewards'] as List? ?? [];
                              if (rewards.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              final itemId =
                                  rewards[0]['ItemID'] as String? ?? '';
                              final metadata = metadataMap[itemId];

                              final originalCosts = offer['Cost'] ?? {};
                              int originalPrice =
                                  originalCosts['85ad13f7-3d1b-1612-dae0-a682f310051c'] ??
                                  originalCosts['85ad13f73d1b1612dae0a682f310051c'] ??
                                  0;
                              if (originalPrice == 0 &&
                                  originalCosts.isNotEmpty) {
                                originalPrice = originalCosts.values.firstWhere(
                                  (v) => v is int,
                                  orElse: () => 0,
                                ) as int;
                              }

                              final discountCosts =
                                  offerData['DiscountCosts'] ?? {};
                              int discountedPrice =
                                  discountCosts['85ad13f7-3d1b-1612-dae0-a682f310051c'] ??
                                  discountCosts['85ad13f73d1b1612dae0a682f310051c'] ??
                                  0;
                              if (discountedPrice == 0 &&
                                  discountCosts.isNotEmpty) {
                                discountedPrice =
                                    discountCosts.values.firstWhere(
                                      (v) => v is int,
                                      orElse: () => 0,
                                    ) as int;
                              }

                              final discountPercent =
                                  offerData['DiscountPercent'] ?? 0;

                              if (metadata == null) {
                                return Card(
                                  child: Center(child: Text('Skin $itemId')),
                                );
                              }

                              final tierUuid = metadata.contentTierUuid;
                              final tier = _getTier(tierUuid, tiersMap);
                              final opaqueColor = tier != null
                                  ? _parseRiotColor(
                                      tier.color,
                                      overrideAlpha: 1.0,
                                    )
                                  : Theme.of(context).colorScheme.primary;
                              final cardBgColor = tier != null
                                  ? _parseRiotColor(
                                      tier.color,
                                      overrideAlpha: 0.12,
                                    )
                                  : Theme.of(context).cardColor;

                              final isFavorite =
                                  favorites[itemId]?.isFavorite == true;

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          SkinDetailsScreen(skin: metadata),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: cardBgColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: opaqueColor.withValues(
                                        alpha: 0.35,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (tier != null &&
                                                  tier.displayIcon.isNotEmpty)
                                                Image.network(
                                                  tier.displayIcon,
                                                  width: 20,
                                                  height: 20,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, _, _) =>
                                                      const SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                      ),
                                                )
                                              else
                                                const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                ),
                                              Expanded(
                                                child: Container(
                                                  alignment: Alignment.center,
                                                  child: Hero(
                                                    tag: 'skin_$itemId',
                                                    child: CachedNetworkImage(
                                                      imageUrl:
                                                          metadata.displayIcon,
                                                      cacheManager:
                                                          CustomCacheManagers
                                                              .dailyStoreCacheManager,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (isFavorite)
                                                const Padding(
                                                  padding: EdgeInsets.only(
                                                    right: 6,
                                                  ),
                                                  child: Icon(
                                                    Icons.star,
                                                    color: Colors.amber,
                                                    size: 20,
                                                  ),
                                                ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFFF4655,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '-$discountPercent%',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.chevron_right,
                                                color: opaqueColor,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                metadata.displayName,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: opaqueColor,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  FormatUtils.formatNumber(
                                                    originalPrice,
                                                    displaySettings,
                                                  ),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: opaqueColor
                                                        .withValues(alpha: 0.5),
                                                    decoration: TextDecoration
                                                        .lineThrough,
                                                  ),
                                                ),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      FormatUtils.formatNumber(
                                                        discountedPrice,
                                                        displaySettings,
                                                      ),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: opaqueColor,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    ColorFiltered(
                                                      colorFilter:
                                                          ColorFilter.mode(
                                                            opaqueColor,
                                                            BlendMode.srcIn,
                                                          ),
                                                      child: Image.network(
                                                        'https://media.valorant-api.com/currencies/85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741/displayicon.png',
                                                        width: 14,
                                                        height: 14,
                                                        fit: BoxFit.contain,
                                                        errorBuilder:
                                                            (_, _, _) => Icon(
                                                              Icons.circle,
                                                              size: 10,
                                                              color:
                                                                  opaqueColor,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

            if (bundlesList.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                  child: Text(
                    l10n.featuredBundles,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),

            if (bundlesList.isNotEmpty)
              bundlesMetadata.when(
                loading: () => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: FunnyLoadingView(),
                    ),
                  ),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(l10n.errorLoadingBundles(err.toString())),
                    ),
                  ),
                ),
                data: (bundlesMap) {
                  final bool isWideScreen =
                      constraints.maxWidth >= 700 || crossAxisCount >= 2;

                  Widget buildBundleCard(int index, {required bool isGrid}) {
                    final bundle = bundlesList[index];
                    final String bundleId =
                        bundle['DataAssetID'] ?? bundle['ID'] ?? '';
                    final price = bundlePrices[bundleId] ?? 0;
                    final metadata = bundlesMap[bundleId];

                    if (metadata == null) {
                      return const SizedBox.shrink();
                    }

                    final image = metadata.displayIcon2 ?? metadata.displayIcon;

                    final Widget infoSection = Container(
                      padding: const EdgeInsets.all(16),
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: isGrid
                            ? MainAxisAlignment.spaceBetween
                            : MainAxisAlignment.start,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                metadata.displayName,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                              ),
                              if (metadata.description != null &&
                                  metadata.description!.isNotEmpty &&
                                  metadata.description !=
                                      metadata.displayName) ...[
                                const SizedBox(height: 6),
                                Text(
                                  metadata.description!,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              CachedNetworkImage(
                                imageUrl: 'https://media.valorant-api.com/currencies/85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741/displayicon.png',
                                cacheManager:
                                    CustomCacheManagers.bundleCacheManager,
                                width: 18,
                                height: 18,
                                fit: BoxFit.contain,
                                errorWidget: (_, _, _) =>
                                    const Icon(Icons.monetization_on, size: 18),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                price > 0
                                    ? FormatUtils.formatNumber(
                                        price,
                                        displaySettings,
                                      )
                                    : l10n.freeLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatBundleDuration(
                                  _bundleRemainingDurationMap[bundleId] ?? 0,
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.access_time,
                                size: 15,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.8),
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );

                    return Container(
                      margin: isGrid
                          ? EdgeInsets.zero
                          : const EdgeInsets.only(bottom: 16),
                      child: Card(
                        elevation: 2,
                        shadowColor: Colors.black.withValues(alpha: 0.1),
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BundleDetailPage(
                                  uuid: bundleId,
                                  storefrontBundleData: bundle,
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (image.isNotEmpty)
                                AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: CachedNetworkImage(
                                    imageUrl: image,
                                    cacheManager:
                                        CustomCacheManagers.bundleCacheManager,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) =>
                                        const Icon(Icons.image, size: 50),
                                  ),
                                ),
                              if (isGrid)
                                Expanded(child: infoSection)
                              else
                                infoSection,
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  if (isWideScreen) {
                    final double columnWidth =
                        (constraints.maxWidth - 32 - 16) / 2;
                    final double estimatedCardHeight =
                        (columnWidth * 9 / 16) + 130;
                    final double bundleAspectRatio =
                        (columnWidth / estimatedCardHeight).clamp(0.95, 1.4);

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: bundleAspectRatio,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              buildBundleCard(index, isGrid: true),
                          childCount: bundlesList.length,
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            buildBundleCard(index, isGrid: false),
                        childCount: bundlesList.length,
                      ),
                    ),
                  );
                },
              ),

            if (_shopData != null && (_shopData!['AccessoryStore'] != null))
              SliverToBoxAdapter(
                child: _AccordionSection(
                  title: l10n.weeklyAccessories,
                  icon: Icons.grid_view,
                  isExpanded: _weeklyAccessoriesExpanded,
                  onTap: () {
                    setState(() {
                      _weeklyAccessoriesExpanded = !_weeklyAccessoriesExpanded;
                    });
                  },
                  countdownText: _formatBundleDuration(
                    _accessoryRemainingDurationInSeconds,
                  ),
                  onRefresh: () => _fetchShop(forceRefresh: true),
                  child: Builder(
                    builder: (context) {
                      final accessoryStore = _shopData!['AccessoryStore'];
                      final List accessoryOffers = accessoryStore != null
                          ? accessoryStore['AccessoryStoreOffers'] ?? []
                          : [];

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: constraints.maxWidth > 800
                              ? 5.0
                              : 4.2,
                        ),
                        itemCount: accessoryOffers.length,
                        itemBuilder: (context, index) {
                          final offerData = accessoryOffers[index];
                          final offer = offerData['Offer'];
                          if (offer == null) return const SizedBox.shrink();

                          final costs = offer['Cost'] ?? {};
                          final price =
                              costs['85ca954a-41f2-ce94-9b45-8ca3dd39a00d'] ??
                              0;
                          final rewards = offer['Rewards'] as List? ?? [];
                          if (rewards.isEmpty) return const SizedBox.shrink();

                          final reward = rewards[0];
                          final itemId = reward['ItemID'] as String? ?? '';

                          String displayName = 'Accessory';
                          String displayIcon = '';
                          String itemType = 'Accessory';
                          dynamic resolvedItem;

                          if (skinsMap.containsKey(itemId)) {
                            final skin = skinsMap[itemId]!;
                            displayName = skin.displayName;
                            displayIcon = skin.displayIcon;
                            itemType = 'Skin';
                            resolvedItem = skin;
                          } else if (cardsMap.containsKey(itemId)) {
                            final card = cardsMap[itemId]!;
                            displayName = card['displayName'] ?? 'Card';
                            displayIcon =
                                card['wideArt'] ?? card['displayIcon'] ?? '';
                            itemType = 'Player Card';
                            resolvedItem = card;
                          } else if (buddiesMap.containsKey(itemId)) {
                            final buddy = buddiesMap[itemId]!;
                            displayName = buddy['displayName'] ?? 'Buddy';
                            displayIcon = buddy['displayIcon'] ?? '';
                            itemType = 'Gun Buddy';
                            resolvedItem = buddy;
                          } else if (spraysMap.containsKey(itemId)) {
                            final spray = spraysMap[itemId]!;
                            displayName = spray['displayName'] ?? 'Spray';
                            displayIcon =
                                spray['displayIcon'] ?? spray['fullIcon'] ?? '';
                            itemType = 'Spray';
                            resolvedItem = spray;
                          } else if (titlesMap.containsKey(itemId)) {
                            final titleItem = titlesMap[itemId]!;
                            displayName =
                                titleItem['titleText'] ?? 'Player Title';
                            itemType = 'Title';
                            resolvedItem = titleItem;
                          } else {
                            displayName = 'Unknown Title';
                            itemType = 'Title';
                          }

                          final cardBgColor = Theme.of(context).cardColor;
                          final opaqueColor = Theme.of(context)
                              .colorScheme
                              .primary;
                          final isFavorite =
                              favorites[itemId]?.isFavorite == true;

                          return GestureDetector(
                            onTap: itemType == 'Skin' && resolvedItem != null
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SkinDetailsScreen(
                                          skin: resolvedItem,
                                        ),
                                      ),
                                    );
                                  }
                                : (itemType == 'Player Card' &&
                                          resolvedItem != null
                                      ? () => AccessoryInspector.showPlayerCard(
                                          context,
                                          resolvedItem,
                                        )
                                      : (itemType == 'Spray' &&
                                                resolvedItem != null
                                            ? () =>
                                                  AccessoryInspector.showSpray(
                                                    context,
                                                    resolvedItem,
                                                  )
                                            : null)),
                            child: Container(
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isFavorite
                                      ? Colors.amber.withValues(alpha: 0.5)
                                      : opaqueColor.withValues(alpha: 0.15),
                                  width: 1.5,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14.0,
                                  vertical: 10.0,
                                ),
                                child: Row(
                                  children: [
                                    if (displayIcon.isNotEmpty)
                                      Container(
                                        width: 48,
                                        height: 48,
                                        margin: const EdgeInsets.only(
                                          right: 12,
                                        ),
                                        alignment: Alignment.center,
                                        child: CachedNetworkImage(
                                          imageUrl: displayIcon,
                                          cacheManager: CustomCacheManagers
                                              .dailyStoreCacheManager,
                                          fit: BoxFit.contain,
                                          errorWidget: (_, _, _) =>
                                              const SizedBox.shrink(),
                                        ),
                                      ),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              itemType.toUpperCase(),
                                              style: GoogleFonts.inter(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.redAccent,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            displayName,
                                            style: GoogleFonts.outfit(
                                              fontSize: itemType == 'Title'
                                                  ? 14
                                                  : 13,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (isFavorite)
                                          const Padding(
                                            padding: EdgeInsets.only(bottom: 4),
                                            child: Icon(
                                              Icons.star,
                                              color: Colors.amber,
                                              size: 16,
                                            ),
                                          ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              FormatUtils.formatNumber(
                                                price,
                                                displaySettings,
                                              ),
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            CachedNetworkImage(
                                              imageUrl: 'https://media.valorant-api.com/currencies/85ca954a-41f2-ce94-9b45-8ca3dd39a00d/displayicon.png',
                                              cacheManager: CustomCacheManagers
                                                  .dailyStoreCacheManager,
                                              width: 14,
                                              height: 14,
                                              fit: BoxFit.contain,
                                              errorWidget: (_, _, _) =>
                                                  const Icon(
                                                    Icons.monetization_on,
                                                    size: 14,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    if (itemType == 'Skin' ||
                                        itemType == 'Player Card' ||
                                        itemType == 'Spray') ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right,
                                        color: opaqueColor,
                                        size: 18,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LastSeenBadge extends StatelessWidget {
  final int? daysSinceLastSeen;
  final Color color;

  const _LastSeenBadge({required this.daysSinceLastSeen, required this.color});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = daysSinceLastSeen == null
        ? l10n.shopHistoryNewBadge
        : l10n.shopHistoryLastSeenDaysAgo(daysSinceLastSeen!);
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: color.withValues(alpha: 0.7),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _CurrencyDisplay extends StatelessWidget {
  final int vp;
  final int radianite;
  final int kingdomCredits;

  const _CurrencyDisplay({
    required this.vp,
    required this.radianite,
    required this.kingdomCredits,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CurrencyItem(
              value: vp,
              iconUrl: 'https://media.valorant-api.com/currencies/85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741/displayicon.png',
            ),
            const SizedBox(width: 6),
            _CurrencyItem(
              value: radianite,
              iconUrl: 'https://media.valorant-api.com/currencies/e59aa87c-4cbf-517a-5983-6e81511be9b7/displayicon.png',
            ),
            const SizedBox(width: 6),
            _CurrencyItem(
              value: kingdomCredits,
              iconUrl: 'https://media.valorant-api.com/currencies/85ca954a-41f2-ce94-9b45-8ca3dd39a00d/displayicon.png',
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topInset;
  final Widget child;

  const _CurrencyHeaderDelegate({required this.topInset, required this.child});

  @override
  double get minExtent => 50 + topInset;

  @override
  double get maxExtent => 50 + topInset;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          if (overlapsContent)
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, topInset + 6, 16, 6),
          child: child,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CurrencyHeaderDelegate oldDelegate) {
    return topInset != oldDelegate.topInset || child != oldDelegate.child;
  }
}

class _CurrencyItem extends ConsumerWidget {
  final int value;
  final String iconUrl;

  const _CurrencyItem({required this.value, required this.iconUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displaySettings = ref.watch(displaySettingsProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CachedNetworkImage(
            imageUrl: iconUrl,
            cacheManager: CustomCacheManagers.bundleCacheManager,
            width: 18,
            height: 18,
            fit: BoxFit.contain,
            errorWidget: (_, _, _) => const Icon(Icons.money, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            FormatUtils.formatNumber(value, displaySettings),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccordionSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback onTap;
  final String countdownText;
  final VoidCallback? onRefresh;
  final Widget? leadingAction;
  final Widget child;

  const _AccordionSection({
    required this.title,
    required this.icon,
    required this.isExpanded,
    required this.onTap,
    required this.countdownText,
    this.onRefresh,
    this.leadingAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExpanded
              ? colorScheme.primary.withValues(alpha: 0.22)
              : colorScheme.outlineVariant.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          if (isExpanded)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isExpanded
                    ? [
                        colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.35,
                        ),
                        colorScheme.surfaceContainer.withValues(alpha: 0.55),
                      ]
                    : [
                        colorScheme.surfaceContainer.withValues(alpha: 0.15),
                        colorScheme.surfaceContainerLow.withValues(alpha: 0.25),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                bottom: BorderSide(
                  color: isExpanded
                      ? colorScheme.outlineVariant.withValues(alpha: 0.15)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        color: isExpanded
                            ? colorScheme.primary
                            : colorScheme.onSurface.withValues(alpha: 0.5),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: isExpanded
                                ? colorScheme.onSurface
                                : colorScheme.onSurface.withValues(alpha: 0.65),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (leadingAction != null) ...[
                        leadingAction!,
                        const SizedBox(width: 8),
                      ],
                      if (onRefresh != null) ...[
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 28,
                            height: 28,
                          ),
                          padding: EdgeInsets.zero,
                          tooltip: l10n.refreshTooltip,
                          icon: Icon(
                            Icons.refresh,
                            size: 16,
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.55,
                            ),
                          ),
                          onPressed: onRefresh,
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (countdownText.isNotEmpty &&
                          countdownText != '00:00:00') ...[
                        Text(
                          countdownText,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.access_time,
                          size: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                        const SizedBox(width: 8),
                      ],
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            child: Container(
              width: double.infinity,
              color: colorScheme.surfaceContainerLow.withValues(alpha: 0.05),
              child: isExpanded
                  ? Padding(padding: const EdgeInsets.all(12.0), child: child)
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
