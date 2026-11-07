import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:valorant_thunai/screens/bundles/all_bundles_screen.dart';
import 'package:valorant_thunai/screens/settings/appearance_screen.dart';
import 'package:valorant_thunai/screens/settings/remote_config_screen.dart';
import 'package:valorant_thunai/screens/home/home_screen.dart';
import 'package:valorant_thunai/screens/hub/hub_screen.dart';
import 'package:valorant_thunai/screens/party/party_screen.dart';
import 'package:valorant_thunai/screens/profile/profile_screen.dart';
import 'package:valorant_thunai/screens/settings/settings_screen.dart';
import 'package:valorant_thunai/screens/social/social_chat_screen.dart';
import 'package:valorant_thunai/widgets/account_switcher_bottom_sheet.dart';
import 'package:valorant_thunai/constants.dart';
import 'package:zenrouter/zenrouter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/screens/auth/riot_login_screen.dart';
import 'package:valorant_thunai/services/connectivity_service.dart';
import 'package:valorant_thunai/widgets/no_network_overlay.dart';

import 'package:valorant_thunai/l10n/app_localizations.dart';
import 'package:valorant_thunai/services/quick_actions_service.dart';

abstract class AppRoute extends RouteTarget with RouteUnique {}

class TabLayout extends AppRoute with RouteLayout<AppRoute> {
  @override
  IndexedStackPath<AppRoute> resolvePath(AppCoordinator coordinator) =>
      coordinator.tabPath;

  @override
  Widget build(AppCoordinator coordinator, BuildContext context) {
    return RootLayout(coordinator: coordinator, child: buildPath(coordinator));
  }
}

class HomeTabRoute extends AppRoute {
  @override
  Type get layout => TabLayout;

  @override
  Uri toUri() => Uri.parse('/');

  @override
  Widget build(AppCoordinator coordinator, BuildContext context) {
    return HomePage();
  }
}

class ProfilePageRoute extends AppRoute {
  @override
  Type get layout => TabLayout;

  @override
  Uri toUri() => Uri.parse('/profile');

  @override
  Widget build(AppCoordinator coordinator, BuildContext context) {
    return const ProfilePage();
  }
}

class SettingsPageRoute extends AppRoute {
  @override
  Type get layout => TabLayout;

  @override
  Uri toUri() => Uri.parse('/settings');

  @override
  Widget build(AppCoordinator coordinator, BuildContext context) {
    return SettingsPage();
  }
}

class PartyPageRoute extends AppRoute {
  @override
  Type get layout => TabLayout;

  @override
  Uri toUri() => Uri.parse('/party');

  @override
  Widget build(AppCoordinator coordinator, BuildContext context) {
    return const PartyPage();
  }
}

class HubPageRoute extends AppRoute {
  @override
  Type get layout => TabLayout;

  @override
  Uri toUri() => Uri.parse('/hub');

  @override
  Widget build(AppCoordinator coordinator, BuildContext context) {
    return const HubPage();
  }
}

class AllPageRoute extends AppRoute {
  @override
  Type get layout => TabLayout;

  @override
  Uri toUri() => Uri.parse('/all');

  @override
  Widget build(AppCoordinator coordinator, BuildContext context) {
    return AllPage();
  }
}

class AppearancePageRoute extends AppRoute {
  @override
  Type get layout => TabLayout;

  @override
  Uri toUri() => Uri.parse('/settings/appearance');

  @override
  Widget build(AppCoordinator coordinator, BuildContext context) {
    return const AppearancePage();
  }
}

class RemoteConfigPageRoute extends AppRoute {
  @override
  Type get layout => TabLayout;

  @override
  Uri toUri() => Uri.parse('/settings/remote-config');

  @override
  Widget build(AppCoordinator coordinator, BuildContext context) {
    return const RemoteConfigScreen();
  }
}

class SocialChatRoute extends AppRoute {
  final String? recipientPuuid;
  final String? recipientName;

  SocialChatRoute({this.recipientPuuid, this.recipientName});

  @override
  Type get layout => TabLayout;

  @override
  Uri toUri() => Uri.parse('/social');

  @override
  Widget build(AppCoordinator coordinator, BuildContext context) {
    return SocialChatScreen(
      initialRecipientPuuid: recipientPuuid,
      initialRecipientName: recipientName,
    );
  }
}

class NotFoundRoute extends AppRoute {
  @override
  Type get layout => TabLayout;

  @override
  Uri toUri() => Uri.parse('/404');

  @override
  Widget build(AppCoordinator coordinator, BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          AppLocalizations.of(context)?.pageNotFound ?? 'Page not found',
        ),
      ),
    );
  }
}

final appCoordinatorProvider = Provider<AppCoordinator>(
  (ref) => AppCoordinator(),
);

class AppCoordinator extends Coordinator<AppRoute> {
  late final tabPath = IndexedStackPath<AppRoute>.createWith(
    coordinator: this,
    label: 'tab',
    [
      HomeTabRoute(),
      ProfilePageRoute(),
      PartyPageRoute(),
      HubPageRoute(),
      SettingsPageRoute(),
    ],
  )..bindLayout(TabLayout.new);

  @override
  List<StackPath<RouteTarget>> get paths => [...super.paths, tabPath];

  @override
  AppRoute parseRouteFromUri(Uri uri) {
    return switch (uri.pathSegments) {
      [] => HomeTabRoute(),
      ['all'] => AllPageRoute(),
      ['profile'] => ProfilePageRoute(),
      ['party'] => PartyPageRoute(),
      ['hub'] => HubPageRoute(),
      ['settings'] => SettingsPageRoute(),
      ['settings', 'remote-config'] => RemoteConfigPageRoute(),
      ['social'] => SocialChatRoute(),

      _ => NotFoundRoute(),
    };
  }

  void switchToTab(int index) {
    if (index == AppTab.home.index) {
      navigate(HomeTabRoute());
    } else if (index == AppTab.profile.index) {
      navigate(ProfilePageRoute());
    } else if (index == AppTab.party.index) {
      navigate(PartyPageRoute());
    } else if (index == AppTab.hub.index) {
      navigate(HubPageRoute());
    } else if (index == AppTab.settings.index) {
      navigate(SettingsPageRoute());
    }
  }

  int get currentTab => tabPath.activeIndex;
}

enum AppTab { home, profile, party, hub, settings }

class RootLayout extends ConsumerWidget {
  final AppCoordinator coordinator;
  final Widget child;

  const RootLayout({super.key, required this.coordinator, required this.child});

  List<AppTab> _getEnabledTabs() {
    return AppTab.values.toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);
    final l10n = AppLocalizations.of(context);

    if (isOnline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(authProvider.notifier).checkAndRefreshSession();
      });
    }

    QuickActionsService.initialize(
      onAction: (shortcutType) {
        if (shortcutType == 'action_shop') {
          coordinator.switchToTab(AppTab.home.index);
        } else if (shortcutType == 'action_party') {
          coordinator.switchToTab(AppTab.party.index);
        } else if (shortcutType == 'action_profile') {
          coordinator.switchToTab(AppTab.profile.index);
        }
      },
    );

    final width = MediaQuery.of(context).size.width;
    final showRail = width >= 600;
    final extendRail = width >= 900;

    ref.listen(
      authProvider.select(
        (s) => s.hasSessionExpired && !s.isSessionExpiredDismissed,
      ),
      (previous, next) {
        if (next) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text(l10n?.sessionExpiredTitle ?? 'Session Expired'),
              content: Text(
                l10n?.sessionExpiredMessage ?? 'Your Riot Games session has expired. Please log in again to fetch the latest shop data.',
              ),
              actions: [
                TextButton(
                  child: Text(l10n?.later ?? 'Later'),
                  onPressed: () {
                    ref.read(authProvider.notifier).dismissSessionExpired();
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text(l10n?.loginAgain ?? 'Login Again'),
                  onPressed: () {
                    ref.read(authProvider.notifier).dismissSessionExpired();
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RiotLoginScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }
      },
    );

    final authState = ref.watch(authProvider);
    final users = authState.allUsers;
    final enabledTabs = _getEnabledTabs();

    return ListenableBuilder(
      listenable: coordinator.tabPath,
      builder: (context, _) {
        final selectedIndex = coordinator.currentTab;
        final activeAppTab =
            (selectedIndex >= 0 && selectedIndex < AppTab.values.length)
            ? AppTab.values[selectedIndex]
            : AppTab.settings;

        int displayIndex = enabledTabs.indexOf(activeAppTab);
        if (displayIndex == -1) {
          displayIndex = 0;
        }

        return Scaffold(
          bottomNavigationBar: showRail
              ? null
              : Stack(
                  children: [
                    NavigationBar(
                      selectedIndex: displayIndex,
                      onDestinationSelected: (index) {
                        final targetTab = enabledTabs[index];
                        coordinator.switchToTab(targetTab.index);
                      },
                      destinations: enabledTabs.map((tab) {
                        return switch (tab) {
                          AppTab.home => NavigationDestination(
                            icon: const Icon(Icons.home_outlined),
                            selectedIcon: const Icon(Icons.home),
                            label: l10n?.tabHome ?? 'Home',
                          ),
                          AppTab.profile => NavigationDestination(
                            icon: const Icon(Icons.account_circle_outlined),
                            selectedIcon: const Icon(Icons.account_circle),
                            label: l10n?.tabProfile ?? 'Profile',
                          ),
                          AppTab.party => NavigationDestination(
                            icon: const Icon(Icons.group_outlined),
                            selectedIcon: const Icon(Icons.group),
                            label: l10n?.tabParty ?? 'Party',
                          ),
                          AppTab.hub => NavigationDestination(
                            icon: const Icon(Icons.grid_view_outlined),
                            selectedIcon: const Icon(Icons.grid_view),
                            label: l10n?.tabHub ?? 'Career',
                          ),
                          AppTab.settings => NavigationDestination(
                            icon: _buildSettingsOrProfileIcon(
                              context: context,
                              authState: authState,
                              isSelected: false,
                            ),
                            selectedIcon: _buildSettingsOrProfileIcon(
                              context: context,
                              authState: authState,
                              isSelected: true,
                            ),
                            label: users.isEmpty
                                ? (l10n?.tabSettings ?? 'Settings')
                                : (l10n?.tabProfile ?? 'Profile'),
                          ),
                        };
                      }).toList(),
                    ),
                    Positioned.fill(
                      child: Row(
                        children: enabledTabs.map((tab) {
                          if (tab == AppTab.settings) {
                            return Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  coordinator.switchToTab(tab.index);
                                },
                                onDoubleTap: users.length > 1
                                    ? () {
                                        final swappedUser = ref
                                            .read(authProvider.notifier)
                                            .swapToPreviousAccount();
                                        if (swappedUser != null) {
                                          HapticFeedback.mediumImpact();
                                          ScaffoldMessenger.of(context)
                                              .hideCurrentSnackBar();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                swappedUser.gameName != null &&
                                                        swappedUser
                                                            .gameName!
                                                            .isNotEmpty
                                                    ? 'Switched to ${swappedUser.gameName}'
                                                    : 'Switched account',
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              duration: const Duration(
                                                seconds: 1,
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    : null,
                                onLongPress: users.length > 1
                                    ? () {
                                        showAccountSwitcherBottomSheet(
                                          context,
                                          ref,
                                        );
                                      }
                                    : null,
                              ),
                            );
                          }
                          return Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                coordinator.switchToTab(tab.index);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
          body: Stack(
            children: [
              Row(
                children: [
                  if (showRail)
                    _buildNavigationRail(
                      extended: extendRail,
                      context: context,
                      coordinator: coordinator,
                      enabledTabs: enabledTabs,
                      displayIndex: displayIndex,
                      authState: authState,
                    ),
                  Expanded(child: child),
                ],
              ),
              if (!isOnline) const NoNetworkOverlay(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsOrProfileIcon({
    required BuildContext context,
    required AuthState authState,
    required bool isSelected,
  }) {
    final users = authState.allUsers;
    if (users.isEmpty) {
      return isSelected
          ? const Icon(Icons.settings)
          : const Icon(Icons.settings_outlined);
    }

    final activeUser = authState.user;
    final theme = Theme.of(context);
    final cardId = activeUser?.playerCardId;

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ClipOval(
        child: (cardId != null && cardId.isNotEmpty)
            ? Image.network(
                'https://media.valorant-api.com/playercards/$cardId/displayicon.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.person,
                  size: 16,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              )
            : Icon(
                Icons.person,
                size: 16,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
      ),
    );
  }

  Widget _buildNavigationRail({
    required bool extended,
    required BuildContext context,
    required AppCoordinator coordinator,
    required List<AppTab> enabledTabs,
    required int displayIndex,
    required AuthState authState,
  }) {
    final l10n = AppLocalizations.of(context);
    final users = authState.allUsers;

    return NavigationRail(
      extended: extended,
      selectedIndex: displayIndex,
      onDestinationSelected: (index) {
        final targetTab = enabledTabs[index];
        coordinator.switchToTab(targetTab.index);
      },
      labelType: extended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      leading: extended
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: Text(
                appName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            )
          : const SizedBox(height: 16),
      destinations: enabledTabs.map((tab) {
        return switch (tab) {
          AppTab.home => NavigationRailDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: Text(l10n?.tabHome ?? 'Home'),
          ),
          AppTab.profile => NavigationRailDestination(
            icon: const Icon(Icons.account_circle_outlined),
            selectedIcon: const Icon(Icons.account_circle),
            label: Text(l10n?.tabProfile ?? 'Profile'),
          ),
          AppTab.party => NavigationRailDestination(
            icon: const Icon(Icons.group_outlined),
            selectedIcon: const Icon(Icons.group),
            label: Text(l10n?.tabParty ?? 'Party'),
          ),
          AppTab.hub => NavigationRailDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view),
            label: Text(l10n?.tabHub ?? 'Career'),
          ),
          AppTab.settings => NavigationRailDestination(
            icon: _buildSettingsOrProfileIcon(
              context: context,
              authState: authState,
              isSelected: false,
            ),
            selectedIcon: _buildSettingsOrProfileIcon(
              context: context,
              authState: authState,
              isSelected: true,
            ),
            label: Text(
              users.isEmpty
                  ? (l10n?.tabSettings ?? 'Settings')
                  : (l10n?.tabProfile ?? 'Profile'),
            ),
          ),
        };
      }).toList(),
    );
  }
}
