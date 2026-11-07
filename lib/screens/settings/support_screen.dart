import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:valorant_thunai/services/logger_service.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpFaqTitle)),
      body: const _SupportPageBody(),
    );
  }
}

class _SupportPageBody extends StatelessWidget {
  const _SupportPageBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFaqSection(
            l10n.faqLoginTroubleshootingTitle,
            l10n.faqLoginTroubleshootingContent,
          ),
          _buildFaqSection(
            l10n.faqSessionExpiredTitle,
            l10n.faqSessionExpiredContent,
          ),
          _buildFaqSection(
            l10n.faqRateLimitedTitle,
            l10n.faqRateLimitedContent,
          ),
          _buildFaqSection(
            l10n.faqAccountSecurityTitle,
            l10n.faqAccountSecurityContent,
          ),
          _buildFaqSection(
            l10n.faqAccountSafetyTitle,
            l10n.faqAccountSafetyContent,
          ),
          _buildFaqSection(l10n.faqFutureAppTitle, l10n.faqFutureAppContent),
          const Divider(height: 48),
          Text(
            l10n.diagnosticLogsSection,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.diagnosticLogsDescription,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final logs = LoggerService.getFullLogs();
              if (logs.isEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.noLogsAvailable)));
                return;
              }
              SharePlus.instance.share(
                ShareParams(
                  text: logs,
                  subject: l10n.shareLogsSubject,
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.share),
                const SizedBox(width: 8),
                Text(l10n.shareLogsWithDeveloper),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              l10n.thankYouUsingApp,
              style: const TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildFaqSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
