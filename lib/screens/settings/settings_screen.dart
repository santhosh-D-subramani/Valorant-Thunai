import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/providers/locale_provider.dart';
import 'package:valorant_thunai/providers/version_provider.dart';
import 'package:valorant_thunai/screens/auth/riot_login_screen.dart';
import 'package:valorant_thunai/screens/home/notifications_screen.dart';
import 'package:valorant_thunai/screens/hub/game_info/game_info_hub_screen.dart';
import 'package:valorant_thunai/screens/settings/appearance_screen.dart';
import 'package:valorant_thunai/screens/settings/cache_manager_screen.dart';
import 'package:valorant_thunai/screens/settings/display_settings_screen.dart';
import 'package:valorant_thunai/screens/settings/key_manager_screen.dart';
import 'package:valorant_thunai/screens/settings/logs_screen.dart';
import 'package:valorant_thunai/screens/settings/remote_config_screen.dart';
import 'package:valorant_thunai/screens/settings/support_screen.dart';
import 'package:valorant_thunai/services/logger_service.dart';
import 'package:valorant_thunai/services/notification_service.dart';
import 'package:valorant_thunai/services/remote_config_service.dart';
import 'package:valorant_thunai/services/update_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _tapCount = 0;
  bool _developerUnlocked = false;
  bool _bypassActive = false;
  bool _bypassLogCensoring = false;

  @override
  void initState() {
    super.initState();
    _loadBypassState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBypassState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _developerUnlocked = prefs.getBool('developer_unlocked') ?? false;
      _bypassActive = prefs.getBool('bypass_remote_config') ?? false;
      _bypassLogCensoring = prefs.getBool('bypass_log_censoring') ?? false;
    });
    LoggerService.initFromPrefs(prefs);
  }

  Future<void> _toggleBypass(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bypass_remote_config', value);
    RemoteConfigService.bypassRemoteConfig = value;
    setState(() {
      _bypassActive = value;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? "Remote Config bypass activated! Restrictions ignored."
                : "Remote Config bypass deactivated.",
          ),
        ),
      );
    }
  }

  Future<void> _toggleLogCensorBypass(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bypass_log_censoring', value);
    LoggerService.bypassCensoring = value;
    setState(() {
      _bypassLogCensoring = value;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? "Log censoring bypassed! Raw tokens & keys will be visible."
                : "Log censoring re-enabled! Sensitive tokens & keys masked.",
          ),
        ),
      );
    }
  }

  Future<void> _handleVersionTap() async {
    if (_developerUnlocked) return;
    setState(() {
      _tapCount++;
    });
    final l10n = AppLocalizations.of(context)!;
    if (_tapCount >= 7) {
      _tapCount = 0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('developer_unlocked', true);
      setState(() {
        _developerUnlocked = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.developerModeUnlockedSnackbar)),
        );
      }
    } else if (_tapCount >= 4) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 600),
          content: Text('${7 - _tapCount} steps away from Developer Options'),
        ),
      );
    }
  }

  void _showLanguageSelector(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.read(localeProvider);
    final isIndia = LocaleNotifier.isIndia();

    final List<_LanguageOption> options = isIndia
        ? [
            _LanguageOption(
              locale: const Locale('ta'),
              nativeName: 'தமிழ்',
              englishName: 'Tamil',
            ),
            _LanguageOption(
              locale: const Locale('en'),
              nativeName: 'English',
              englishName: 'English',
            ),
            _LanguageOption(
              locale: null,
              nativeName: l10n.languageSystemDefault,
              englishName: l10n.languageSystemDefaultSubtitle,
            ),
          ]
        : [
            _LanguageOption(
              locale: const Locale('en'),
              nativeName: 'English',
              englishName: 'English',
            ),
            _LanguageOption(
              locale: const Locale('ta'),
              nativeName: 'தமிழ்',
              englishName: 'Tamil',
            ),
            _LanguageOption(
              locale: null,
              nativeName: l10n.languageSystemDefault,
              englishName: l10n.languageSystemDefaultSubtitle,
            ),
          ];

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Text(
                    l10n.selectLanguageTitle,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    child: Column(
                      children: options.asMap().entries.map((entry) {
                        final index = entry.key;
                        final opt = entry.value;
                        final isLast = index == options.length - 1;
                        final isSelected = opt.locale == null
                            ? currentLocale == null
                            : currentLocale?.languageCode ==
                                  opt.locale?.languageCode;

                        return Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                              ),
                              title: Text(
                                opt.nativeName,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                opt.englishName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    )
                                  : null,
                              onTap: () {
                                ref
                                    .read(localeProvider.notifier)
                                    .setLocale(opt.locale);
                                Navigator.pop(bottomSheetContext);
                              },
                            ),
                            if (!isLast)
                              Divider(
                                height: 1,
                                thickness: 1,
                                indent: 56,
                                color: Colors.grey.withValues(alpha: 0.1),
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider);
    final users = authState.allUsers;
    final activeIndex = authState.activeUserIndex;
    final theme = Theme.of(context);

    final notifications = ref.watch(notificationProvider);
    final unreadCount = notifications.where((n) => !n.isRead).length;
    final currentLocale = ref.watch(localeProvider);
    final String currentLanguageSubtitle =
        switch (currentLocale?.languageCode) {
          'ta' => 'தமிழ் (Tamil)',
          'en' => 'English',
          _ => l10n.languageSystemDefault,
        };

    final preferencesItems = [
      _SettingEntry(
        title: l10n.appearanceTitle,
        subtitle: l10n.themeColorIconSubtitle,
        category: 'Preferences & Interface',
        icon: Icons.palette_outlined,
        widget: ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: Text(l10n.appearanceTitle),
          subtitle: Text(l10n.themeColorIconSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AppearancePage()),
            );
          },
        ),
      ),
      _SettingEntry(
        title: l10n.languageTitle,
        subtitle: currentLanguageSubtitle,
        category: 'Preferences & Interface',
        icon: Icons.language_outlined,
        widget: ListTile(
          leading: const Icon(Icons.language_outlined),
          title: Text(l10n.languageTitle),
          subtitle: Text(currentLanguageSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showLanguageSelector(context),
        ),
      ),
      _SettingEntry(
        title: l10n.displaySettingsTitle,
        subtitle: l10n.displaySettingsSubtitle,
        category: 'Preferences & Interface',
        icon: Icons.tune_outlined,
        widget: ListTile(
          leading: const Icon(Icons.tune_outlined),
          title: Text(l10n.displaySettingsTitle),
          subtitle: Text(l10n.displaySettingsSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const DisplaySettingsScreen(),
              ),
            );
          },
        ),
      ),
    ];

    final notificationItems = [
      _SettingEntry(
        title: l10n.notificationsTitle,
        subtitle: unreadCount > 0
            ? l10n.unreadCount(unreadCount)
            : l10n.noNewNotifications,
        category: 'Notifications & Alerts',
        icon: Icons.notifications_outlined,
        widget: ListTile(
          leading: Stack(
            children: [
              const Icon(Icons.notifications_outlined),
              if (unreadCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 8,
                      minHeight: 8,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(l10n.notificationsTitle),
          subtitle: Text(
            unreadCount > 0
                ? l10n.unreadCount(unreadCount)
                : l10n.noNewNotifications,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NotificationsScreen(),
              ),
            );
          },
        ),
      ),
      _SettingEntry(
        title: l10n.nightMarketAlertSettingTitle,
        subtitle: l10n.nightMarketAlertSettingSubtitle,
        category: 'Notifications & Alerts',
        icon: Icons.storefront_outlined,
        widget: const NightMarketAlertSettingTile(),
      ),
      _SettingEntry(
        title: l10n.showSasukeEasterEggTitle,
        subtitle: l10n.showSasukeEasterEggSubtitle,
        category: 'Notifications & Alerts',
        icon: Icons.person_pin,
        widget: const SasukeSettingTile(),
      ),
    ];

    final contentItems = [
      _SettingEntry(
        title: l10n.gameInfoHubTitle,
        subtitle: l10n.gameInfoWeaponsSubtitle,
        category: 'Content & Resources',
        icon: Icons.menu_book_outlined,
        widget: ListTile(
          leading: const Icon(Icons.menu_book_outlined),
          title: Text(l10n.gameInfoHubTitle),
          subtitle: Text(l10n.gameInfoWeaponsSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const GameInfoHubScreen(),
              ),
            );
          },
        ),
      ),
      _SettingEntry(
        title: l10n.cacheManagerTitle,
        subtitle: l10n.manageCachedImagesSubtitle,
        category: 'Content & Resources',
        icon: Icons.cleaning_services_outlined,
        widget: ListTile(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: Text(l10n.cacheManagerTitle),
          subtitle: Text(l10n.manageCachedImagesSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const CacheManagerPage()),
            );
          },
        ),
      ),
      if (UpdateService.isUpdateEnabled)
        _SettingEntry(
          title: l10n.checkForUpdates,
          subtitle: 'Check if a newer version of Valorant Thunai is available',
          category: 'Content & Resources',
          icon: Icons.system_update_outlined,
          widget: ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: Text(l10n.checkForUpdates),
            subtitle: const Text(
              'Check if a newer version of the app is available',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => UpdateService.checkUpdates(context, manual: true),
          ),
        ),
    ];

    final toolsItems = [
      _SettingEntry(
        title: 'API Keys & Credentials',
        subtitle: 'Configure HenrikDev API key and custom endpoints',
        category: 'Tools & Configuration',
        icon: Icons.key_outlined,
        widget: ListTile(
          leading: const Icon(Icons.key_outlined),
          title: const Text('API Keys & Credentials'),
          subtitle: const Text(
            'Configure HenrikDev API key and custom endpoints',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const KeyManagerScreen()),
            );
          },
        ),
      ),
      _SettingEntry(
        title: 'Remote Configuration',
        subtitle: 'GitHub raw config, 1-day cache, and visual value editor',
        category: 'Tools & Configuration',
        icon: Icons.cloud_sync_outlined,
        widget: ListTile(
          leading: const Icon(Icons.cloud_sync_outlined),
          title: const Text('Remote Configuration'),
          subtitle: const Text(
            'GitHub raw config, cache, and visual value editor',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const RemoteConfigScreen(),
              ),
            );
          },
        ),
      ),
      _SettingEntry(
        title: l10n.appLogsTitle,
        subtitle: l10n.viewDebuggingLogsSubtitle,
        category: 'Tools & Configuration',
        icon: Icons.bug_report_outlined,
        widget: ListTile(
          leading: const Icon(Icons.bug_report_outlined),
          title: Text(l10n.appLogsTitle),
          subtitle: Text(l10n.viewDebuggingLogsSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (context) => const LogsScreen()));
          },
        ),
      ),
    ];

    final supportItems = [
      _SettingEntry(
        title: l10n.helpFaqTitle,
        subtitle: 'Get answers to frequently asked questions',
        category: 'Support & Community',
        icon: Icons.help_outline,
        widget: ListTile(
          leading: const Icon(Icons.help_outline),
          title: Text(l10n.helpFaqTitle),
          subtitle: const Text('Get answers to frequently asked questions'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SupportPage()),
            );
          },
        ),
      ),
      _SettingEntry(
        title: l10n.rateValShopTitle,
        subtitle: l10n.rateValShopSubtitle,
        category: 'Support & Community',
        icon: Icons.star_outline,
        widget: ListTile(
          leading: const Icon(Icons.star_outline),
          title: Text(l10n.rateValShopTitle),
          subtitle: Text(l10n.rateValShopSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => UpdateService.openRating(),
        ),
      ),
      _SettingEntry(
        title: l10n.discoverMoreAppsTitle,
        subtitle: l10n.discoverMoreAppsSubtitle,
        category: 'Support & Community',
        icon: Icons.apps_outlined,
        widget: ListTile(
          leading: const Icon(Icons.apps_outlined),
          title: Text(l10n.discoverMoreAppsTitle),
          subtitle: Text(l10n.discoverMoreAppsSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => UpdateService.openOtherApps(),
        ),
      ),
    ];

    final developerItems = [
      if (_developerUnlocked) ...[
        _SettingEntry(
          title: l10n.bypassRemoteConfigTitle,
          subtitle: l10n.bypassRemoteConfigSubtitle,
          category: l10n.developerOptionsHeader,
          icon: Icons.developer_mode_outlined,
          widget: SwitchListTile(
            secondary: const Icon(Icons.developer_mode_outlined),
            title: Text(l10n.bypassRemoteConfigTitle),
            subtitle: Text(l10n.bypassRemoteConfigSubtitle),
            value: _bypassActive,
            onChanged: _toggleBypass,
          ),
        ),
        _SettingEntry(
          title: l10n.bypassLogCensoringTitle,
          subtitle: l10n.bypassLogCensoringSubtitle,
          category: l10n.developerOptionsHeader,
          icon: Icons.security_outlined,
          widget: SwitchListTile(
            secondary: const Icon(Icons.security_outlined),
            title: Text(l10n.bypassLogCensoringTitle),
            subtitle: Text(l10n.bypassLogCensoringSubtitle),
            value: _bypassLogCensoring,
            onChanged: _toggleLogCensorBypass,
          ),
        ),
        _SettingEntry(
          title: l10n.lockDeveloperModeTitle,
          subtitle: 'Disable developer mode and restore restrictions',
          category: l10n.developerOptionsHeader,
          icon: Icons.lock_outline,
          widget: ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.lockDeveloperModeTitle),
            subtitle: const Text(
              'Disable developer mode and restore restrictions',
            ),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('developer_unlocked', false);
              await prefs.setBool('bypass_remote_config', false);
              await prefs.setBool('bypass_log_censoring', false);
              RemoteConfigService.bypassRemoteConfig = false;
              LoggerService.bypassCensoring = false;
              setState(() {
                _developerUnlocked = false;
                _bypassActive = false;
                _bypassLogCensoring = false;
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.developerModeLockedSnackbar)),
                );
              }
            },
          ),
        ),
      ],
    ];

    final allSearchEntries = [
      ...preferencesItems,
      ...notificationItems,
      ...contentItems,
      ...toolsItems,
      ...supportItems,
      ...developerItems,
    ];

    final filteredSearchEntries = _searchQuery.isEmpty
        ? <_SettingEntry>[]
        : allSearchEntries.where((entry) {
            final q = _searchQuery.toLowerCase();
            return entry.title.toLowerCase().contains(q) ||
                entry.subtitle.toLowerCase().contains(q) ||
                entry.category.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabSettings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SearchBar(
                controller: _searchController,
                hintText: 'Search settings...',
                leading: const Icon(Icons.search),
                trailing: [
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    ),
                ],
                elevation: WidgetStateProperty.all(0),
                backgroundColor: WidgetStateProperty.all(
                  theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                ),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim();
                  });
                },
              ),
            ),

            if (_searchQuery.isNotEmpty) ...[
              if (filteredSearchEntries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 48,
                    horizontal: 24,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No settings found for "$_searchQuery"',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try searching with a different keyword',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
              else
                _buildSectionGroup(
                  context,
                  title: 'Search Results (${filteredSearchEntries.length})',
                  children: filteredSearchEntries.map((e) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              e.category,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                        e.widget,
                      ],
                    );
                  }).toList(),
                ),
            ] else ...[
              _buildSectionGroup(
                context,
                title: l10n.accountsSectionHeader,
                footer: users.isNotEmpty
                    ? 'Notice: Using third-party tools involves a small risk to your account status. Use this app moderately and avoid unnecessary frequent refreshes to prevent rate limiting.'
                    : null,
                children: [
                  if (users.isEmpty)
                    ListTile(
                      leading: const Icon(Icons.login),
                      title: Text(l10n.loginWithRiot),
                      subtitle: Text(l10n.signInToViewStoreSubtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const RiotLoginScreen(),
                          ),
                        );
                      },
                    )
                  else ...[
                    ...users.asMap().entries.map((entry) {
                      final index = entry.key;
                      final user = entry.value;
                      final isActive = index == activeIndex;

                      return InkWell(
                        onTap: () {
                          ref.read(authProvider.notifier).switchAccount(index);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  user.playerCardId != null
                                      ? 'https://media.valorant-api.com/playercards/${user.playerCardId}/displayicon.png'
                                      : 'https://media.valorant-api.com/playercards/9fb3f4ab-4c11-1a3b-955e-5e9ad13289f3/displayicon.png',
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 56,
                                    height: 56,
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.person, size: 28),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            user.gameName != null &&
                                                    user.gameName!.isNotEmpty
                                                ? user.gameName!
                                                : (authState.isLoading
                                                      ? 'Refreshing...'
                                                      : 'Account ${index + 1}'),
                                            style: GoogleFonts.inter(
                                              fontWeight: isActive
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              fontSize: 16,
                                              color:
                                                  (user.gameName == null &&
                                                      authState.isLoading)
                                                  ? Colors.grey
                                                  : theme.colorScheme.onSurface,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (user.tagline != null &&
                                            user.tagline!.isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '#${user.tagline}',
                                            style: GoogleFonts.inter(
                                              color: Colors.grey,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Level ${user.level ?? '??'}',
                                          style: GoogleFonts.inter(
                                            color: Colors.grey,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (isActive) ...[
                                          const Icon(
                                            Icons.check,
                                            color: Colors.redAccent,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                        ],
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(
                                            Icons.refresh,
                                            size: 20,
                                          ),
                                          onPressed: authState.isLoading
                                              ? null
                                              : () async {
                                                  try {
                                                    await ref
                                                        .read(
                                                          authProvider.notifier,
                                                        )
                                                        .refreshProfile(index);

                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            l10n.profileUpdatedSnackbar,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  } catch (e) {
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            l10n.updateFailedSnackbar(
                                                              e.toString(),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  }
                                                },
                                        ),
                                        const SizedBox(width: 12),
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(
                                            Icons.logout,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Text(l10n.logOutTitle),
                                                content: Text(
                                                  l10n.logOutConfirmMessage,
                                                ),
                                                actions: [
                                                  TextButton(
                                                    child: Text(l10n.cancel),
                                                    onPressed: () =>
                                                        Navigator.of(context)
                                                            .pop(),
                                                  ),
                                                  TextButton(
                                                    child: Text(
                                                      l10n.logOutTitle,
                                                      style: const TextStyle(
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                    onPressed: () async {
                                                      Navigator.of(context)
                                                          .pop();
                                                      await ref
                                                          .read(
                                                            authProvider
                                                                .notifier,
                                                          )
                                                          .logoutAccount(index);
                                                    },
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: Text(l10n.addAnotherAccount),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const RiotLoginScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),

              if (preferencesItems.isNotEmpty)
                _buildSectionGroup(
                  context,
                  title: 'Preferences & Interface',
                  children: preferencesItems.map((e) => e.widget).toList(),
                ),

              if (notificationItems.isNotEmpty)
                _buildSectionGroup(
                  context,
                  title: 'Notifications & Alerts',
                  children: notificationItems.map((e) => e.widget).toList(),
                ),

              if (contentItems.isNotEmpty)
                _buildSectionGroup(
                  context,
                  title: 'Content & Resources',
                  children: contentItems.map((e) => e.widget).toList(),
                ),

              if (toolsItems.isNotEmpty)
                _buildSectionGroup(
                  context,
                  title: 'Tools & Configuration',
                  children: toolsItems.map((e) => e.widget).toList(),
                ),

              if (supportItems.isNotEmpty)
                _buildSectionGroup(
                  context,
                  title: l10n.supportSectionHeader,
                  children: supportItems.map((e) => e.widget).toList(),
                ),

              if (_developerUnlocked && developerItems.isNotEmpty)
                _buildSectionGroup(
                  context,
                  title: l10n.developerOptionsHeader,
                  children: developerItems.map((e) => e.widget).toList(),
                ),

              const SizedBox(height: 16),

              GestureDetector(
                onTap: _handleVersionTap,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ref
                        .watch(appVersionProvider)
                        .when(
                          data: (version) => Text(
                            'Version $version',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          loading: () => const Text(
                            'Version ...',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          error: (_, _) => const Text(
                            'Version Unknown',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionGroup(
    BuildContext context, {
    String? title,
    String? footer,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 6),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              child: Column(
                children: children.asMap().entries.map((entry) {
                  final index = entry.key;
                  final child = entry.value;
                  final isLast = index == children.length - 1;
                  return Column(
                    children: [
                      child,
                      if (!isLast)
                        Divider(
                          height: 1,
                          thickness: 1,
                          indent: 56,
                          color: Colors.grey.withValues(alpha: 0.1),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4, right: 12),
              child: Text(
                footer,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingEntry {
  final String title;
  final String subtitle;
  final String category;
  final IconData icon;
  final Widget widget;

  _SettingEntry({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.widget,
  });
}

class SasukeSettingTile extends StatefulWidget {
  const SasukeSettingTile({super.key});

  @override
  State<SasukeSettingTile> createState() => _SasukeSettingTileState();
}

class _SasukeSettingTileState extends State<SasukeSettingTile> {
  bool _showSasuke = true;

  @override
  void initState() {
    super.initState();
    _loadPref();
  }

  Future<void> _loadPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showSasuke = prefs.getBool('show_sasuke_appbar') ?? true;
    });
  }

  Future<void> _toggleSasuke(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_sasuke_appbar', value);
    setState(() {
      _showSasuke = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSasuke) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    return SwitchListTile(
      secondary: const Icon(Icons.person_pin),
      title: Text(l10n.showSasukeEasterEggTitle),
      subtitle: Text(l10n.showSasukeEasterEggSubtitle),
      value: _showSasuke,
      onChanged: _toggleSasuke,
    );
  }
}

class NightMarketAlertSettingTile extends StatefulWidget {
  const NightMarketAlertSettingTile({super.key});

  @override
  State<NightMarketAlertSettingTile> createState() =>
      _NightMarketAlertSettingTileState();
}

class _NightMarketAlertSettingTileState
    extends State<NightMarketAlertSettingTile> {
  bool _nightMarketAlertsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPref();
  }

  Future<void> _loadPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nightMarketAlertsEnabled =
          prefs.getBool('night_market_alerts_enabled') ?? true;
    });
  }

  Future<void> _toggleNightMarketAlerts(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('night_market_alerts_enabled', value);
    setState(() {
      _nightMarketAlertsEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SwitchListTile(
      secondary: const Icon(Icons.storefront_outlined),
      title: Text(l10n.nightMarketAlertSettingTitle),
      subtitle: Text(l10n.nightMarketAlertSettingSubtitle),
      value: _nightMarketAlertsEnabled,
      onChanged: _toggleNightMarketAlerts,
    );
  }
}

class _LanguageOption {
  final Locale? locale;
  final String nativeName;
  final String englishName;

  const _LanguageOption({
    required this.locale,
    required this.nativeName,
    required this.englishName,
  });
}
