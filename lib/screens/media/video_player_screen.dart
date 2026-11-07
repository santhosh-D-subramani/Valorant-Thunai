import 'dart:io';

import 'package:flutter/material.dart';

import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:video_player/video_player.dart';
import 'package:valorant_thunai/services/video_cache_manager.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String title;

  const FullScreenVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() async {
    try {
      final resolvedPath = await VideoCacheManager.getVideoPath(
        widget.videoUrl,
      );

      if (!mounted) return;

      if (resolvedPath.startsWith('http://') ||
          resolvedPath.startsWith('https://')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(resolvedPath));
      } else {
        _controller = VideoPlayerController.file(File(resolvedPath));
      }

      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = true;
        });

        _controller!.addListener(_onControllerUpdate);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  void _onControllerUpdate() {
    if (!mounted || _controller == null) return;
    final value = _controller!.value;
    if (value.isPlaying != _isPlaying) {
      setState(() {
        _isPlaying = value.isPlaying;
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        l10n?.errorPlayingVideo(_error!) ??
                            'Error playing video:\n$_error',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : !_isInitialized
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const FunnyLoadingView(color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(
                          l10n?.loadingVideo ?? 'Loading video...',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                  : AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
            ),

            if (_isInitialized)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    if (_controller != null) {
                      if (_isPlaying) {
                        _controller!.pause();
                      } else {
                        _controller!.play();
                      }
                    }
                  },
                  child: Container(
                    color: Colors.transparent,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 16,
                          left: 16,
                          right: 64,
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(blurRadius: 6, color: Colors.black),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 30,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),

                        Positioned(
                          bottom: 36,
                          right: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                _isMuted ? Icons.volume_off : Icons.volume_up,
                                color: Colors.white,
                                size: 24,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isMuted = !_isMuted;
                                  _controller?.setVolume(_isMuted ? 0.0 : 1.0);
                                });
                              },
                            ),
                          ),
                        ),

                        if (!_isPlaying)
                          const Center(
                            child: Icon(
                              Icons.play_arrow,
                              color: Colors.white70,
                              size: 80,
                            ),
                          ),

                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              VideoProgressIndicator(
                                _controller!,
                                allowScrubbing: true,
                                colors: const VideoProgressColors(
                                  playedColor: Colors.redAccent,
                                  bufferedColor: Colors.white24,
                                  backgroundColor: Colors.white12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (!_isInitialized)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
