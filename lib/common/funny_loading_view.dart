import 'dart:async';

import 'package:flutter/material.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class FunnyLoadingView extends StatefulWidget {
  final Color? color;

  final double? strokeWidth;

  const FunnyLoadingView({super.key, this.color, this.strokeWidth});

  @override
  State<FunnyLoadingView> createState() => _FunnyLoadingViewState();
}

class _FunnyLoadingViewState extends State<FunnyLoadingView> {
  late final Timer _timer;
  int _elapsedSeconds = 0;
  int _currentMessageIndex = 0;
  final List<String> _shuffledMessages = [];
  bool _initializedMessages = false;

  List<String> _getFunnyMessages(AppLocalizations l10n) {
    return [
      l10n.funnyLoading1,
      l10n.funnyLoading2,
      l10n.funnyLoading3,
      l10n.funnyLoading4,
      l10n.funnyLoading5,
      l10n.funnyLoading6,
      l10n.funnyLoading7,
      l10n.funnyLoading8,
      l10n.funnyLoading9,
      l10n.funnyLoading10,
      l10n.funnyLoading11,
      l10n.funnyLoading12,
      l10n.funnyLoading13,
      l10n.funnyLoading14,
      l10n.funnyLoading15,
      l10n.funnyLoading16,
      l10n.funnyLoading17,
      l10n.funnyLoading18,
      l10n.funnyLoading19,
      l10n.funnyLoading20,
      l10n.funnyLoading21,
      l10n.funnyLoading22,
      l10n.funnyLoading23,
      l10n.funnyLoading24,
      l10n.funnyLoading25,
      l10n.funnyLoading26,
      l10n.funnyLoading27,
      l10n.funnyLoading28,
      l10n.funnyLoading29,
      l10n.funnyLoading30,
      l10n.funnyLoading31,
      l10n.funnyLoading32,
      l10n.funnyLoading33,
      l10n.funnyLoading34,
      l10n.funnyLoading35,
      l10n.funnyLoading36,
      l10n.funnyLoading37,
      l10n.funnyLoading38,
      l10n.funnyLoading39,
      l10n.funnyLoading40,
      l10n.funnyLoading41,
      l10n.funnyLoading42,
      l10n.funnyLoading43,
      l10n.funnyLoading44,
      l10n.funnyLoading45,
      l10n.funnyLoading46,
      l10n.funnyLoading47,
      l10n.funnyLoading48,
      l10n.funnyLoading49,
      l10n.funnyLoading50,
      l10n.funnyLoading51,
      l10n.funnyLoading52,
      l10n.funnyLoading53,
      l10n.funnyLoading54,
      l10n.funnyLoading55,
      l10n.funnyLoading56,
      l10n.funnyLoading57,
      l10n.funnyLoading58,
    ];
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
        if (_elapsedSeconds >= 6 && _shuffledMessages.isNotEmpty) {
          final activeLoadingSecs = _elapsedSeconds - 6;
          _currentMessageIndex =
              (activeLoadingSecs ~/ 6) % _shuffledMessages.length;
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedMessages) {
      final l10n = AppLocalizations.of(context);
      if (l10n != null) {
        _shuffledMessages.addAll(_getFunnyMessages(l10n));
        _shuffledMessages.shuffle();
        _initializedMessages = true;
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 150 || constraints.maxHeight < 80) {
          return Center(
            child: CircularProgressIndicator(
              color: widget.color,
              strokeWidth: widget.strokeWidth,
            ),
          );
        }

        final showMessage = _elapsedSeconds >= 6;
        final message = _shuffledMessages.isNotEmpty
            ? _shuffledMessages[_currentMessageIndex]
            : '';

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: widget.color,
                  strokeWidth: widget.strokeWidth,
                ),
                if (showMessage) ...[
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      message,
                      key: ValueKey<String>(message),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
