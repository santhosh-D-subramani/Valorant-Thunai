import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:valorant_thunai/providers/skin_provider.dart';
import 'package:valorant_thunai/screens/media/video_player_screen.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class SkinDetailsScreen extends ConsumerStatefulWidget {
  final SkinMetadata skin;

  const SkinDetailsScreen({super.key, required this.skin});

  @override
  ConsumerState<SkinDetailsScreen> createState() => _SkinDetailsScreenState();
}

class _SkinDetailsScreenState extends ConsumerState<SkinDetailsScreen> {
  late SkinChroma _selectedChroma;

  @override
  void initState() {
    super.initState();
    _selectedChroma = widget.skin.chromas.isNotEmpty
        ? widget.skin.chromas.first
        : SkinChroma(
            uuid: '',
            displayName: widget.skin.displayName,
            displayIcon: widget.skin.displayIcon,
          );
  }

  String _formatChromaName(String displayName) {
    final clean = displayName
        .replaceAll('\r\n', ' ')
        .replaceAll('\n', ' ')
        .trim();
    final match = RegExp(r'\(([^)]+)\)').firstMatch(clean);
    if (match != null && match.group(1) != null) {
      return match.group(1)!;
    }
    if (clean.toLowerCase() == widget.skin.displayName.toLowerCase()) {
      return 'Default';
    }
    return clean;
  }

  String? _getActiveChromaVideo() {
    if (_selectedChroma.streamedVideo != null &&
        _selectedChroma.streamedVideo!.isNotEmpty) {
      return _selectedChroma.streamedVideo;
    }
    if (widget.skin.levels.isNotEmpty) {
      for (final lvl in widget.skin.levels.reversed) {
        if (lvl.streamedVideo != null && lvl.streamedVideo!.isNotEmpty) {
          return lvl.streamedVideo;
        }
      }
    }
    return null;
  }

  void _playVideo(String url, {String? title}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenVideoPlayer(
          videoUrl: url,
          title: title ?? widget.skin.displayName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isFavorite =
        ref.watch(favoritesProvider)[widget.skin.uuid]?.isFavorite == true;
    final activeVideoUrl = _getActiveChromaVideo();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.skin.displayName,
          style: GoogleFonts.outfit(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              color: isFavorite
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            onPressed: () {
              ref
                  .read(favoritesProvider.notifier)
                  .toggleFavorite(widget.skin.uuid);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    l10n.colorVariantsTitle,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatChromaName(_selectedChroma.displayName),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: Hero(
                          tag: 'skin_${widget.skin.uuid}',
                          child: Image.network(
                            _selectedChroma.displayIcon.isNotEmpty
                                ? _selectedChroma.displayIcon
                                : widget.skin.displayIcon,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (activeVideoUrl != null)
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Material(
                          color: colorScheme.primary,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _playVideo(
                              activeVideoUrl,
                              title:
                                  '${widget.skin.displayName} (${_formatChromaName(_selectedChroma.displayName)})',
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: colorScheme.onPrimary,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (widget.skin.chromas.length > 1)
                SizedBox(
                  height: 55,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.skin.chromas.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final chroma = widget.skin.chromas[index];
                      final isSelected = _selectedChroma.uuid == chroma.uuid;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedChroma = chroma;
                          });
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.outline,
                                  width: isSelected ? 3 : 1,
                                ),
                                image: chroma.swatch != null
                                    ? DecorationImage(
                                        image: NetworkImage(chroma.swatch!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: colorScheme.surfaceContainerHighest,
                              ),
                            ),
                            if (chroma.streamedVideo != null)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.play_arrow,
                                    size: 10,
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 32),
              Text(
                l10n.skinLevelsTitle,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.skin.levels.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: colorScheme.outline),
                  itemBuilder: (context, index) {
                    final level = widget.skin.levels[index];
                    final levelNumber = index + 1;
                    final isMaxLevel = index == widget.skin.levels.length - 1;

                    String levelDescription = '';
                    if (level.levelItem != null) {
                      levelDescription = level.levelItem!.split('::').last;
                      if (levelDescription.contains('VFX')) {
                        levelDescription = l10n.visualEffectsLevelItem;
                      }
                    }

                    String? videoUrlToPlay;
                    String videoTitleToPlay =
                        '${widget.skin.displayName} - Level $levelNumber';

                    if (isMaxLevel &&
                        _selectedChroma.streamedVideo != null &&
                        _selectedChroma.streamedVideo!.isNotEmpty) {
                      videoUrlToPlay = _selectedChroma.streamedVideo;
                      videoTitleToPlay =
                          '${widget.skin.displayName} - ${_formatChromaName(_selectedChroma.displayName)}';
                    } else if (level.streamedVideo != null &&
                        level.streamedVideo!.isNotEmpty) {
                      videoUrlToPlay = level.streamedVideo;
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      title: Text(
                        l10n.levelNumberTitle(levelNumber),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      subtitle:
                          isMaxLevel &&
                              _selectedChroma.streamedVideo != null &&
                              _selectedChroma.streamedVideo!.isNotEmpty
                          ? Text(
                              l10n.variantPreviewSubtitle(
                                _formatChromaName(_selectedChroma.displayName),
                              ),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (levelDescription.isNotEmpty)
                            Text(
                              levelDescription,
                              style: GoogleFonts.inter(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (videoUrlToPlay != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.play_circle_outline,
                                color: colorScheme.primary,
                                size: 28,
                              ),
                              onPressed: () => _playVideo(
                                videoUrlToPlay!,
                                title: videoTitleToPlay,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
