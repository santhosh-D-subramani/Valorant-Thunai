import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:valorant_thunai/services/player_bookmark_service.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class BookmarkedPlayersScreen extends StatefulWidget {
  final void Function(BookmarkedPlayer player) onSelect;

  const BookmarkedPlayersScreen({super.key, required this.onSelect});

  @override
  State<BookmarkedPlayersScreen> createState() =>
      _BookmarkedPlayersScreenState();
}

class _BookmarkedPlayersScreenState extends State<BookmarkedPlayersScreen> {
  List<BookmarkedPlayer> _bookmarks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bookmarks = await PlayerBookmarkService.getAll();
    if (!mounted) return;
    setState(() {
      _bookmarks = bookmarks;
      _isLoading = false;
    });
  }

  Future<void> _remove(String puuid) async {
    await PlayerBookmarkService.remove(puuid);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bookmarkedPlayersTitle),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _bookmarks.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 60.0,
                  horizontal: 24,
                ),
                child: Column(
                  children: [
                    Icon(Icons.star_border, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      l10n.bookmarkedPlayersEmptyPrompt,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16.0),
                itemCount: _bookmarks.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final player = _bookmarks[index];
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        widget.onSelect(player);
                        Navigator.of(context).pop();
                      },
                      child: Row(
                        children: [
                          if (player.playerCardId.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl:
                                  'https://media.valorant-api.com/playercards/${player.playerCardId}/smallart.png',
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                    children: [
                                      TextSpan(text: player.gameName),
                                      TextSpan(
                                        text: player.tagline.isNotEmpty
                                            ? '#${player.tagline}'
                                            : '',
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
                                  l10n.regionPrefix(
                                    player.region.toUpperCase(),
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.star, color: Colors.amber),
                            tooltip: l10n.removeBookmarkTooltip,
                            onPressed: () => _remove(player.puuid),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
