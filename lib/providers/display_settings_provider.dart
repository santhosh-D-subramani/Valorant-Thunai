import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppDateFormat { dayMonthYear, monthDayShortYear, isoYearMonthDay }

enum AppTimeFormat { h12, h24 }

enum AppNumberFormat { plain, grouped }

class DisplaySettings {
  final AppDateFormat dateFormat;
  final AppTimeFormat timeFormat;
  final AppNumberFormat numberFormat;

  const DisplaySettings({
    this.dateFormat = AppDateFormat.dayMonthYear,
    this.timeFormat = AppTimeFormat.h12,
    this.numberFormat = AppNumberFormat.grouped,
  });

  DisplaySettings copyWith({
    AppDateFormat? dateFormat,
    AppTimeFormat? timeFormat,
    AppNumberFormat? numberFormat,
  }) {
    return DisplaySettings(
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
      numberFormat: numberFormat ?? this.numberFormat,
    );
  }
}

class DisplaySettingsNotifier extends StateNotifier<DisplaySettings> {
  static const _keyDateFormat = 'display_settings_date_format';
  static const _keyTimeFormat = 'display_settings_time_format';
  static const _keyNumberFormat = 'display_settings_number_format';

  DisplaySettingsNotifier() : super(const DisplaySettings()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateIndex = prefs.getInt(_keyDateFormat);
      final timeIndex = prefs.getInt(_keyTimeFormat);
      final numberIndex = prefs.getInt(_keyNumberFormat);
      state = DisplaySettings(
        dateFormat: dateIndex != null && dateIndex < AppDateFormat.values.length
            ? AppDateFormat.values[dateIndex]
            : state.dateFormat,
        timeFormat: timeIndex != null && timeIndex < AppTimeFormat.values.length
            ? AppTimeFormat.values[timeIndex]
            : state.timeFormat,
        numberFormat:
            numberIndex != null && numberIndex < AppNumberFormat.values.length
            ? AppNumberFormat.values[numberIndex]
            : state.numberFormat,
      );
    } catch (_) {}
  }

  Future<void> setDateFormat(AppDateFormat format) async {
    state = state.copyWith(dateFormat: format);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDateFormat, format.index);
  }

  Future<void> setTimeFormat(AppTimeFormat format) async {
    state = state.copyWith(timeFormat: format);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTimeFormat, format.index);
  }

  Future<void> setNumberFormat(AppNumberFormat format) async {
    state = state.copyWith(numberFormat: format);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyNumberFormat, format.index);
  }
}

final displaySettingsProvider =
    StateNotifierProvider<DisplaySettingsNotifier, DisplaySettings>(
      (ref) => DisplaySettingsNotifier(),
    );
