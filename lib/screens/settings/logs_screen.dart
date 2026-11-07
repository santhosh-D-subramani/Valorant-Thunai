import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:valorant_thunai/services/logger_service.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  bool _isUncensored = false;

  @override
  void initState() {
    super.initState();
    _isUncensored = LoggerService.bypassCensoring;
  }

  void _toggleCensoring() {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isUncensored = !_isUncensored;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isUncensored
              ? l10n.uncensoredLogsActiveSnackbar
              : l10n.logsCensoredSnackbar,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final logs = LoggerService.getLogs(censored: !_isUncensored).reversed
        .toList();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n.systemLogsTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(
              _isUncensored ? Icons.lock_open_rounded : Icons.shield_rounded,
              color: _isUncensored
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
              size: 22,
            ),
            tooltip: _isUncensored
                ? l10n.censorLogsTooltip
                : l10n.unlockUncensoredLogsTooltip,
            onPressed: _toggleCensoring,
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 22),
            tooltip: l10n.copyAllTooltip,
            onPressed: () {
              final textToCopy = LoggerService.getFullLogs(
                censored: !_isUncensored,
              );
              Clipboard.setData(ClipboardData(text: textToCopy));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _isUncensored
                        ? l10n.uncensoredLogsCopiedSnackbar
                        : l10n.censoredLogsCopiedSnackbar,
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 22),
            tooltip: l10n.clearTooltip,
            onPressed: () {
              setState(() {
                LoggerService.clearLogs();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: l10n.refreshTooltip,
            onPressed: () {
              setState(() {});
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (_isUncensored) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.uncensoredModeWarning,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: logs.isEmpty
                      ? Center(
                          child: Text(
                            l10n.noLogsAvailableMessage,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: logs.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            return _LogLine(log: logs[index]);
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  final String log;

  const _LogLine({required this.log});

  @override
  Widget build(BuildContext context) {
    String timestamp = '';
    String tag = '';
    String message = log;

    if (log.startsWith('[')) {
      final endTimestamp = log.indexOf(']');
      if (endTimestamp != -1) {
        timestamp = log.substring(1, endTimestamp);
        message = log.substring(endTimestamp + 1).trim();

        if (message.startsWith('[')) {
          final endTag = message.indexOf(']');
          if (endTag != -1) {
            tag = message.substring(1, endTag);
            message = message.substring(endTag + 1).trim();
          }
        }
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final timestampColor = isDark ? Colors.grey[500] : Colors.grey[600];
    final tagColor = isDark ? Colors.blue[300] : Colors.blue[700];

    Color? messageColor = isDark ? Colors.grey[300] : Colors.grey[800];
    if (message.toLowerCase().contains('error') ||
        message.toLowerCase().contains('failed')) {
      messageColor = isDark ? Colors.red[300] : Colors.red[700];
    } else if (message.toLowerCase().contains('success')) {
      messageColor = isDark ? Colors.green[300] : Colors.green[700];
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.4,
        ),
        children: [
          if (timestamp.isNotEmpty)
            TextSpan(
              text: '[$timestamp] ',
              style: TextStyle(color: timestampColor),
            ),
          if (tag.isNotEmpty)
            TextSpan(
              text: '[$tag] ',
              style: TextStyle(color: tagColor, fontWeight: FontWeight.w600),
            ),
          TextSpan(
            text: message,
            style: TextStyle(color: messageColor),
          ),
        ],
      ),
    );
  }
}
