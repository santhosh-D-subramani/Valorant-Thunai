import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/constants.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/screens/auth/riot_login_screen.dart';
import 'package:valorant_thunai/screens/shop/daily_shop_screen.dart';
import 'package:valorant_thunai/services/update_service.dart';
import 'package:valorant_thunai/screens/home/notifications_screen.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkUpdates(context);
    });

    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (user != null) {
      return const DailyShopScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(appName),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.notifications),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.welcomeToValShop,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(l10n.loginToViewOffers),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RiotLoginScreen(),
                  ),
                );
              },
              child: Text(l10n.loginWithRiot),
            ),
          ],
        ),
      ),
    );
  }
}
