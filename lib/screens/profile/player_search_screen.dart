import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:valorant_thunai/services/valorant_api.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/providers/display_settings_provider.dart';
import 'package:valorant_thunai/providers/profile_provider.dart';
import 'package:valorant_thunai/services/logger_service.dart';
import 'package:valorant_thunai/services/player_bookmark_service.dart';
import 'package:valorant_thunai/utils/cache_managers.dart';
import 'package:valorant_thunai/utils/format_utils.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';
import 'package:valorant_thunai/screens/profile/bookmarked_players_screen.dart';

class PlayerSearchPage extends ConsumerStatefulWidget {
  final String? initialQuery;
  const PlayerSearchPage({super.key, this.initialQuery});

  @override
  ConsumerState<PlayerSearchPage> createState() => _PlayerSearchPageState();
}

class _PlayerSearchPageState extends ConsumerState<PlayerSearchPage> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic>? _searchedAccount;
  Map<String, dynamic>? _searchedMmr;
  List<dynamic>? _searchedMatches;
  String? _officialName;
  String? _officialTag;

  List<Map<String, dynamic>> _recentSearches = [];

  List<BookmarkedPlayer> _bookmarkedPlayers = [];
  bool _isCurrentPlayerBookmarked = false;

  final Map<String, String> _agentNameIconMap = {};

  DisplaySettings get _displaySettings => ref.read(displaySettingsProvider);
  final Map<String, String> _agentNameBustMap = {};
  final Map<String, String> _mapNameIconMap = {};
  final Map<String, String> _mapNameSplashMap = {};

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _loadBookmarkedPlayers();
    _loadValorantAssets();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _searchController.text = widget.initialQuery!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchPlayer(widget.initialQuery!.trim());
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final historyStr = prefs.getString('recent_player_searches') ?? '[]';
    try {
      final List<dynamic> list = jsonDecode(historyStr);
      setState(() {
        _recentSearches = list
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (e) {
      LoggerService.log(
        'Error loading search history: $e',
        tag: 'PlayerSearchPage',
      );
    }
  }

  Future<void> _saveSearchToHistory(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    _recentSearches.removeWhere(
      (element) =>
          element['puuid'] == item['puuid'] ||
          (element['gameName']?.toLowerCase() ==
                  item['gameName']?.toLowerCase() &&
              element['tagline']?.toLowerCase() ==
                  item['tagline']?.toLowerCase()),
    );

    _recentSearches.insert(0, item);

    if (_recentSearches.length > 5) {
      _recentSearches = _recentSearches.sublist(0, 5);
    }

    await prefs.setString(
      'recent_player_searches',
      jsonEncode(_recentSearches),
    );
    setState(() {});
  }

  Future<void> _deleteFromHistory(int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches.removeAt(index);
    });
    await prefs.setString(
      'recent_player_searches',
      jsonEncode(_recentSearches),
    );
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_player_searches');
    setState(() {
      _recentSearches = [];
    });
  }

  Future<void> _loadBookmarkedPlayers() async {
    final bookmarks = await PlayerBookmarkService.getAll();
    if (!mounted) return;
    setState(() {
      _bookmarkedPlayers = bookmarks;
    });
  }

  Future<void> _toggleBookmarkForCurrentPlayer() async {
    final account = _searchedAccount;
    if (account == null) return;
    final puuid = account['puuid'] ?? '';
    if (puuid.isEmpty) return;

    final player = BookmarkedPlayer(
      puuid: puuid,
      gameName: _officialName ?? account['name'] ?? '',
      tagline: _officialTag ?? account['tag'] ?? '',
      region: account['region'] ?? 'na',
      playerCardId: account['card']?['id'] ?? '',
    );

    final isNowBookmarked = await PlayerBookmarkService.toggle(player);
    await _loadBookmarkedPlayers();
    if (!mounted) return;
    setState(() {
      _isCurrentPlayerBookmarked = isNowBookmarked;
    });
  }

  Future<void> _removeBookmark(String puuid) async {
    await PlayerBookmarkService.remove(puuid);
    await _loadBookmarkedPlayers();
  }

  Future<void> _loadValorantAssets() async {
    try {
      final agentsRes = await http.get(
        Uri.parse(
          'https://valorant-api.com/v1/agents?isPlayableCharacter=true',
        ),
      );
      final mapsRes = await http.get(
        Uri.parse('https://valorant-api.com/v1/maps'),
      );

      if (agentsRes.statusCode == 200) {
        final agentsData = jsonDecode(agentsRes.body)['data'] as List;
        for (var agent in agentsData) {
          final name = agent['displayName']?.toString().toLowerCase();
          final icon = agent['displayIcon']?.toString();
          final bust =
              agent['bustPortrait']?.toString() ??
              agent['fullPortraitV2']?.toString();
          if (name != null && icon != null) {
            _agentNameIconMap[name] = icon;
            if (bust != null) {
              _agentNameBustMap[name] = bust;
            }
          }
        }
      }

      if (mapsRes.statusCode == 200) {
        final mapsData = jsonDecode(mapsRes.body)['data'] as List;
        for (var map in mapsData) {
          final name = map['displayName']?.toString().toLowerCase();
          final icon = map['listViewIcon']?.toString();
          final splash = map['splash']?.toString();
          if (name != null && icon != null) {
            _mapNameIconMap[name] = icon;
            if (splash != null) {
              _mapNameSplashMap[name] = splash;
            }
          }
        }
      }
    } catch (e) {
      LoggerService.log('Failed to load assets: $e', tag: 'PlayerSearchPage');
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  String _getShardFromRegion(String region) {
    final r = region.toLowerCase();
    if (r == 'latam' || r == 'br' || r == 'na') {
      return 'na';
    }
    if (r == 'eu') return 'eu';
    if (r == 'ap') return 'ap';
    if (r == 'kr') return 'kr';
    if (r == 'pbe') return 'pbe';
    return 'na';
  }

  Future<void> _searchPlayer(String query) async {
    if (query.trim().isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _searchedAccount = null;
      _searchedMmr = null;
      _searchedMatches = null;
      _officialName = null;
      _officialTag = null;
      _isCurrentPlayerBookmarked = false;
    });

    _searchFocusNode.unfocus();

    try {
      final authState = ref.read(authProvider);
      final loggedInUser = authState.user;
      if (loggedInUser == null) {
        throw Exception(l10n.mustBeLoggedInToSearch);
      }

      final api = ref.read(valorantApiProvider);
      Map<String, dynamic>? accountDetails;
      String puuid = '';
      String region = '';

      if (query.contains('#')) {
        final parts = query.split('#');
        final name = parts[0].trim();
        final tag = parts[1].trim();

        if (name.isEmpty || tag.isEmpty) {
          throw Exception(l10n.invalidNameTagFormat);
        }

        accountDetails = await api.fetchHenrikAccountByNameAndTag(name, tag);
      } else if (query.trim().length == 36) {
        puuid = query.trim();
        accountDetails = await api.fetchHenrikAccount(puuid);
      } else {
        throw Exception(l10n.enterValidNameTagOrPuuid);
      }

      if (accountDetails == null) {
        throw Exception(l10n.playerNotFound);
      }

      puuid = accountDetails['puuid'] ?? '';
      region = accountDetails['region'] ?? 'na';
      final shard = _getShardFromRegion(region);

      final results = await Future.wait([
        api
            .getPlayersNames(
              [puuid],
              loggedInUser.accessToken,
              loggedInUser.entitlementsToken,
              shard,
            )
            .catchError((_) => []),
        ValorantApi.getHenrikMMR(region, puuid).catchError((_) => null),
        ValorantApi.fetchHenrikMatches(region, puuid).catchError((_) => null),
      ]);

      final nameServiceList = results[0] as List<dynamic>;
      final mmrData = results[1] as Map<String, dynamic>?;
      final matchesList = results[2] as List<dynamic>?;

      if (nameServiceList.isNotEmpty) {
        final officialPlayer = nameServiceList[0];
        _officialName = officialPlayer['GameName'];
        _officialTag = officialPlayer['TagLine'];
      }

      final bookmarked = await PlayerBookmarkService.isBookmarked(puuid);

      setState(() {
        _searchedAccount = accountDetails;
        _searchedMmr = mmrData;
        _searchedMatches = matchesList;
        _isCurrentPlayerBookmarked = bookmarked;
      });

      await _saveSearchToHistory({
        'puuid': puuid,
        'gameName': _officialName ?? accountDetails['name'],
        'tagline': _officialTag ?? accountDetails['tag'],
        'region': region,
        'playerCardId': accountDetails['card']?['id'] ?? '',
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
      LoggerService.log('Search player failed: $e', tag: 'PlayerSearchPage');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(displaySettingsProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.searchPlayersTitle),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: l10n.bookmarkedPlayersTitle,
            icon: const Icon(Icons.bookmark_outline),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => BookmarkedPlayersScreen(
                    onSelect: (player) {
                      _searchController.text =
                          '${player.gameName}#${player.tagline}';
                      _searchPlayer('${player.gameName}#${player.tagline}');
                    },
                  ),
                ),
              );
              _loadBookmarkedPlayers();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchBox(theme, isDark),
              const SizedBox(height: 20),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                _buildErrorCard(theme)
              else if (_searchedAccount != null) ...[
                _buildProfileCard(theme, isDark),
                const SizedBox(height: 24),
                _buildMatchHistorySection(theme, isDark),
              ] else ...[
                if (_bookmarkedPlayers.isNotEmpty) ...[
                  _buildBookmarkedPlayersSection(theme, isDark),
                  const SizedBox(height: 24),
                ],
                _buildRecentSearchesSection(theme, isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBox(ThemeData theme, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: _searchPlayer,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: l10n.searchPlayerHint,
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        onChanged: (text) {
          setState(() {});
        },
      ),
    );
  }

  Widget _buildErrorCard(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _errorMessage ?? l10n.anErrorOccurred,
                style: TextStyle(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarkedPlayersSection(ThemeData theme, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.bookmarkedPlayersHeader,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            TextButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => BookmarkedPlayersScreen(
                      onSelect: (player) {
                        _searchController.text =
                            '${player.gameName}#${player.tagline}';
                        _searchPlayer('${player.gameName}#${player.tagline}');
                      },
                    ),
                  ),
                );
                _loadBookmarkedPlayers();
              },
              child: Text(l10n.viewAllButton),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _bookmarkedPlayers.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final player = _bookmarkedPlayers[index];
              return InputChip(
                avatar: const Icon(Icons.star, size: 16, color: Colors.amber),
                label: Text('${player.gameName}#${player.tagline}'),
                onPressed: () {
                  _searchController.text =
                      '${player.gameName}#${player.tagline}';
                  _searchPlayer('${player.gameName}#${player.tagline}');
                },
                onDeleted: () => _removeBookmark(player.puuid),
                deleteIconColor: Colors.grey,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSearchesSection(ThemeData theme, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    if (_recentSearches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60.0),
        child: Column(
          children: [
            Icon(
              Icons.person_search_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.searchEmptyPrompt,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.recentSearchesHeader,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            TextButton(
              onPressed: _clearHistory,
              child: Text(l10n.clearAllButton),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentSearches.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = _recentSearches[index];
            final gameName = item['gameName'] ?? l10n.unknownItem;
            final tagline = item['tagline'] ?? '';
            final region = item['region']?.toString().toUpperCase() ?? 'NA';
            final playerCardId = item['playerCardId'] ?? '';

            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  _searchController.text = '$gameName#$tagline';
                  _searchPlayer('$gameName#$tagline');
                },
                child: Row(
                  children: [
                    if (playerCardId.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl:
                            'https://media.valorant-api.com/playercards/$playerCardId/smallart.png',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.person,
                            size: 24,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.person,
                          size: 24,
                          color: Colors.grey,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              children: [
                                TextSpan(text: gameName),
                                TextSpan(
                                  text: tagline.isNotEmpty ? '#$tagline' : '',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.regionPrefix(region),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.grey,
                      ),
                      onPressed: () => _deleteFromHistory(index),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProfileCard(ThemeData theme, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final account = _searchedAccount!;
    final name = _officialName ?? account['name'] ?? l10n.unknownItem;
    final tag = _officialTag ?? account['tag'] ?? '0000';
    final level = account['account_level'] ?? 0;

    final competitiveTiers = ref.watch(competitiveTiersProvider).value ?? {};

    int currentTierId = 0;
    int currentRR = 0;
    if (_searchedMmr != null) {
      final activeAct = ref.watch(activeActProvider).value;
      final currentRank = resolveCurrentCompetitiveRank(
        _searchedMmr,
        activeAct,
      );
      currentTierId = currentRank.currentTier;
      currentRR = currentRank.currentRR;
    }

    final currentTierData = competitiveTiers[currentTierId];
    final currentTierIcon = currentTierData?['largeIcon'];
    final currentTierName = currentTierData?['tierName'] ?? l10n.unranked;

    int peakTierId = 0;
    String peakSeason = 'ACT 1';
    if (_searchedMmr != null) {
      final highestRank = _searchedMmr!['highest_rank'];
      peakTierId = highestRank?['tier'] ?? 0;
      final seasonName = highestRank?['season']?.toString().toUpperCase();
      if (seasonName != null) {
        if (seasonName.startsWith('E') && seasonName.contains('A')) {
          final parts = seasonName.split('A');
          peakSeason = '${parts[0]} // ACT ${parts[1]}';
        } else {
          peakSeason = seasonName;
        }
      }
    }

    final peakTierData = competitiveTiers[peakTierId];
    final peakTierIcon = peakTierData?['largeIcon'];
    final peakTierName = peakTierData?['tierName'] ?? l10n.unranked;

    final playerCardId = account['card']?['id'] ?? '';
    final bannerUrl =
        'https://media.valorant-api.com/playercards/$playerCardId/wideart.png';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      children: [
                        TextSpan(text: name),
                        TextSpan(
                          text: '#$tag',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _isCurrentPlayerBookmarked
                      ? l10n.removeBookmarkTooltip
                      : l10n.addBookmarkTooltip,
                  icon: Icon(
                    _isCurrentPlayerBookmarked ? Icons.star : Icons.star_border,
                    color: _isCurrentPlayerBookmarked
                        ? Colors.amber
                        : Colors.grey,
                  ),
                  onPressed: _toggleBookmarkForCurrentPlayer,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (account['region'] ?? 'na').toString().toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(0),
                  bottomRight: Radius.circular(0),
                ),
                child: CachedNetworkImage(
                  imageUrl: bannerUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    height: 120,
                    width: double.infinity,
                    color: Colors.grey[800],
                    child: const Icon(
                      Icons.image,
                      size: 50,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -15,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.blueGrey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    l10n.playerLv(level),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildStatColumn(
                  topLabel: l10n.currentRankUpper,
                  iconWidget: currentTierIcon != null
                      ? CachedNetworkImage(
                          imageUrl: currentTierIcon,
                          width: 70,
                          height: 70,
                          cacheManager:
                              CustomCacheManagers.tierImageCacheManager,
                        )
                      : const Icon(
                          Icons.security,
                          size: 70,
                          color: Colors.grey,
                        ),
                  rankName: currentTierName,
                  bottomLabel: l10n.rrSuffix(currentRR),
                ),
                _buildStatColumn(
                  topLabel: peakSeason,
                  iconWidget: peakTierIcon != null
                      ? CachedNetworkImage(
                          imageUrl: peakTierIcon,
                          width: 70,
                          height: 70,
                          cacheManager:
                              CustomCacheManagers.tierImageCacheManager,
                        )
                      : const Icon(
                          Icons.emoji_events,
                          size: 70,
                          color: Colors.grey,
                        ),
                  rankName: peakTierName,
                  bottomLabel: l10n.lifetimePeak,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn({
    required String topLabel,
    required Widget iconWidget,
    required String rankName,
    required String bottomLabel,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            topLabel,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          iconWidget,
          const SizedBox(height: 10),
          Text(
            rankName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFFB54545),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            bottomLabel,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchHistorySection(ThemeData theme, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    if (_searchedMatches == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history_toggle_off, size: 50, color: Colors.grey[500]),
              const SizedBox(height: 8),
              Text(
                l10n.matchesNotAvailable,
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    final matches = _searchedMatches!;
    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            l10n.noRecentMatchesFound,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.recentMatchesHeader,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: matches.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final match = matches[index];
            final metadata = match['metadata'] ?? {};
            final mapName = metadata['map']?.toString() ?? l10n.unknownMap;
            final mode = metadata['mode']?.toString() ?? 'Unrated';
            final roundsPlayed = metadata['rounds_played'] ?? 0;

            final startTimestamp = metadata['game_start'] ?? 0;
            final matchDate = startTimestamp > 0
                ? DateTime.fromMillisecondsSinceEpoch(startTimestamp * 1000)
                : DateTime.now();
            final dateLabel =
                FormatUtils.formatDateTime(matchDate, _displaySettings);

            final searchPuuid = _searchedAccount?['puuid'] ?? '';
            final players = match['players']?['all_players'] as List? ?? [];
            final playerInfo = players.firstWhere(
              (p) => p['puuid'] == searchPuuid,
              orElse: () => null,
            );

            String characterName = 'Jett';
            String team = 'Blue';
            int kills = 0;
            int deaths = 0;
            int assists = 0;
            int score = 0;
            int rankTier = 0;

            if (playerInfo != null) {
              characterName = playerInfo['character']?.toString() ?? 'Jett';
              team = playerInfo['team']?.toString() ?? 'Blue';
              final stats = playerInfo['stats'] ?? {};
              kills = stats['kills'] ?? 0;
              deaths = stats['deaths'] ?? 0;
              assists = stats['assists'] ?? 0;
              score = stats['score'] ?? 0;
              rankTier = playerInfo['currenttier'] ?? 0;
            }

            final combatScore = roundsPlayed > 0
                ? (score / roundsPlayed).round()
                : 0;

            final teamKey = team.toLowerCase();
            final teams = match['teams'] ?? {};
            final playerTeamDetails = teams[teamKey] ?? {};

            final bool hasWon = playerTeamDetails['has_won'] ?? false;
            final int roundsWon = playerTeamDetails['rounds_won'] ?? 0;
            final int roundsLost = playerTeamDetails['rounds_won'] != null
                ? (roundsPlayed - roundsWon)
                : 0;

            final isDraw = roundsWon == roundsLost && roundsPlayed > 0;
            final outcomeColor = isDraw
                ? Colors.grey[700]
                : (hasWon ? Colors.green[600] : Colors.red[700]);
            final outcomeText = isDraw
                ? l10n.matchResultDraw
                : (hasWon ? l10n.matchResultVictory : l10n.matchResultDefeat);

            final agentIcon = _agentNameIconMap[characterName.toLowerCase()];
            final mapSplash = _mapNameSplashMap[mapName.toLowerCase()];

            final competitiveTiers =
                ref.watch(competitiveTiersProvider).value ?? {};
            final currentTierData = competitiveTiers[rankTier];
            final rankIconUrl = currentTierData?['smallIcon'];

            return Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.military_tech,
                          size: 32,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.monitor,
                                    size: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    mode,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              hasWon ? '+14' : (isDraw ? '0' : '-19'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: hasWon
                                    ? Colors.green[600]
                                    : Colors.red[600],
                              ),
                            ),
                            Text(
                              '0',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                value: hasWon ? 0.75 : 0.25,
                                strokeWidth: 3,
                                color: hasWon
                                    ? Colors.green[500]
                                    : Colors.red[500],
                                backgroundColor: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[300],
                              ),
                            ),
                            if (rankIconUrl != null)
                              CachedNetworkImage(
                                imageUrl: rankIconUrl,
                                width: 24,
                                height: 24,
                                cacheManager:
                                    CustomCacheManagers.tierImageCacheManager,
                              )
                            else
                              const Icon(
                                Icons.shield,
                                size: 20,
                                color: Colors.grey,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(
                    height: 80,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        if (mapSplash != null)
                          Positioned.fill(
                            child: CachedNetworkImage(
                              imageUrl: mapSplash,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              errorWidget: (context, url, error) =>
                                  Container(color: Colors.grey[800]),
                            ),
                          )
                        else
                          Container(color: Colors.grey[800]),

                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withValues(alpha: 0.8),
                                  Colors.black.withValues(alpha: 0.2),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          ),
                        ),

                        if (agentIcon != null)
                          Positioned(
                            left: 16,
                            top: 12,
                            bottom: 12,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: agentIcon,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),

                        Positioned(
                          left: 88,
                          top: 0,
                          bottom: 0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                characterName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  mapName,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Positioned(
                          right: 16,
                          top: 24,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: outcomeColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              outcomeText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.track_changes,
                              size: 20,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$kills / $deaths / $assists',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.bar_chart,
                              size: 20,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              FormatUtils.formatNumber(
                                combatScore,
                                _displaySettings,
                              ),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.flag, size: 20, color: Colors.grey[500]),
                            const SizedBox(width: 8),
                            Text(
                              '$roundsWon - $roundsLost',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: Colors.grey[500],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
