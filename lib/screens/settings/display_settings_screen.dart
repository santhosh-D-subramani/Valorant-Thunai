import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';
import 'package:valorant_thunai/providers/display_settings_provider.dart';
import 'package:valorant_thunai/utils/format_utils.dart';

class DisplaySettingsScreen extends ConsumerWidget {
  const DisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(displaySettingsProvider);
    final notifier = ref.read(displaySettingsProvider.notifier);
    final previewDate = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.displaySettingsTitle), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(text: l10n.dateFormatSectionTitle),
          _OptionTile<AppDateFormat>(
            label: FormatUtils.formatDate(
              previewDate,
              settings.copyWith(dateFormat: AppDateFormat.dayMonthYear),
            ),
            value: AppDateFormat.dayMonthYear,
            groupValue: settings.dateFormat,
            onChanged: notifier.setDateFormat,
          ),
          _OptionTile<AppDateFormat>(
            label: FormatUtils.formatDate(
              previewDate,
              settings.copyWith(dateFormat: AppDateFormat.monthDayShortYear),
            ),
            value: AppDateFormat.monthDayShortYear,
            groupValue: settings.dateFormat,
            onChanged: notifier.setDateFormat,
          ),
          _OptionTile<AppDateFormat>(
            label: FormatUtils.formatDate(
              previewDate,
              settings.copyWith(dateFormat: AppDateFormat.isoYearMonthDay),
            ),
            value: AppDateFormat.isoYearMonthDay,
            groupValue: settings.dateFormat,
            onChanged: notifier.setDateFormat,
          ),

          const Divider(height: 32),
          _SectionHeader(text: l10n.timeFormatSectionTitle),
          _OptionTile<AppTimeFormat>(
            label: FormatUtils.formatTime(
              previewDate,
              settings.copyWith(timeFormat: AppTimeFormat.h12),
            ),
            value: AppTimeFormat.h12,
            groupValue: settings.timeFormat,
            onChanged: notifier.setTimeFormat,
          ),
          _OptionTile<AppTimeFormat>(
            label: FormatUtils.formatTime(
              previewDate,
              settings.copyWith(timeFormat: AppTimeFormat.h24),
            ),
            value: AppTimeFormat.h24,
            groupValue: settings.timeFormat,
            onChanged: notifier.setTimeFormat,
          ),

          const Divider(height: 32),
          _SectionHeader(text: l10n.numberFormatSectionTitle),
          _OptionTile<AppNumberFormat>(
            label: FormatUtils.formatNumber(
              9500,
              settings.copyWith(numberFormat: AppNumberFormat.grouped),
            ),
            value: AppNumberFormat.grouped,
            groupValue: settings.numberFormat,
            onChanged: notifier.setNumberFormat,
          ),
          _OptionTile<AppNumberFormat>(
            label: FormatUtils.formatNumber(
              9500,
              settings.copyWith(numberFormat: AppNumberFormat.plain),
            ),
            value: AppNumberFormat.plain,
            groupValue: settings.numberFormat,
            onChanged: notifier.setNumberFormat,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _OptionTile<T> extends StatelessWidget {
  final String label;
  final T value;
  final T groupValue;
  final ValueChanged<T> onChanged;

  const _OptionTile({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return ListTile(
      title: Text(label),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      onTap: () => onChanged(value),
    );
  }
}
