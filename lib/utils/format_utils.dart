import 'package:valorant_thunai/providers/display_settings_provider.dart';

class FormatUtils {
  static const Map<String, String> _unlistedAgentWeaponSlots = {
    '856d9a7e-4b06-dc37-15dc-9d809c37cb90': 'Ability1',
  };

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  static String formatDurationMillis(int? millis) {
    if (millis == null) return '0m 00s';
    return formatDuration(Duration(milliseconds: millis));
  }

  static String formatRoundClock(int? millis) {
    if (millis == null) return '00:00';
    final totalSeconds = (millis / 1000).floor();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static String formatDate(DateTime date, DisplaySettings settings) {
    final local = date.toLocal();
    switch (settings.dateFormat) {
      case AppDateFormat.dayMonthYear:
        return '${local.day.toString().padLeft(2, '0')} ${_months[local.month - 1]} '
            '${(local.year % 100).toString().padLeft(2, '0')}';
      case AppDateFormat.monthDayShortYear:
        return '${_months[local.month - 1]} ${local.day.toString().padLeft(2, '0')}, ${local.year}';
      case AppDateFormat.isoYearMonthDay:
        return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    }
  }

  static String formatTime(DateTime date, DisplaySettings settings) {
    final local = date.toLocal();
    if (settings.timeFormat == AppTimeFormat.h24) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    final hour12 = local.hour > 12
        ? local.hour - 12
        : (local.hour == 0 ? 12 : local.hour);
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${hour12.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} $suffix';
  }

  static String formatDateTime(
    DateTime date,
    DisplaySettings settings, {
    String separator = ' • ',
  }) {
    return '${formatDate(date, settings)}$separator${formatTime(date, settings)}';
  }

  static String formatNumber(num value, DisplaySettings settings) {
    final intValue = value.round();
    if (settings.numberFormat == AppNumberFormat.plain) {
      return intValue.toString();
    }
    final digits = intValue.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return (intValue < 0 ? '-' : '') + buffer.toString();
  }

  static String resolveWeaponLabel(
    Map<String, String> weaponNamesByUuid,
    Map<String, dynamic>? finishingDamage,
  ) {
    if (finishingDamage == null) return '';
    final damageType = finishingDamage['damageType']?.toString() ?? '';
    final damageItem = finishingDamage['damageItem']?.toString() ?? '';
    if (damageItem.isEmpty || damageItem.toLowerCase() == 'unknown') {
      return damageType;
    }
    return weaponNamesByUuid[damageItem.toLowerCase()] ?? damageType;
  }

  static KillWeaponInfo resolveKillWeapon({
    required Map<String, dynamic>? finishingDamage,
    required Map<String, String> weaponNamesByUuid,
    required Map<String, String> weaponIconsByUuid,
    required Map<String, dynamic>? killerAgentData,
  }) {
    if (finishingDamage == null) {
      return const KillWeaponInfo(
        label: '',
        iconUrl: null,
        isWeaponIcon: false,
      );
    }
    final damageType = finishingDamage['damageType']?.toString() ?? '';
    final damageItem = finishingDamage['damageItem']?.toString() ?? '';

    final abilities = (killerAgentData?['abilities'] as List?) ?? const [];
    for (final ability in abilities) {
      if (ability is Map &&
          ability['slot'] != null &&
          ability['slot'].toString().toLowerCase() ==
              damageItem.toLowerCase()) {
        return KillWeaponInfo(
          label: ability['displayName']?.toString() ?? damageItem,
          iconUrl: ability['displayIcon']?.toString(),
          isWeaponIcon: false,
        );
      }
    }

    if (damageType.toLowerCase() == 'bomb') {
      return const KillWeaponInfo(
        label: 'Spike',
        iconUrl: null,
        isWeaponIcon: false,
      );
    }

    if (damageItem.isNotEmpty && damageItem.toLowerCase() != 'unknown') {
      final uuid = damageItem.toLowerCase();
      final weaponName = weaponNamesByUuid[uuid];
      if (weaponName != null) {
        return KillWeaponInfo(
          label: weaponName,
          iconUrl: weaponIconsByUuid[uuid],
          isWeaponIcon: true,
        );
      }

      final slot = _unlistedAgentWeaponSlots[uuid];
      if (slot != null) {
        for (final ability in abilities) {
          if (ability is Map && ability['slot']?.toString() == slot) {
            return KillWeaponInfo(
              label: ability['displayName']?.toString() ?? damageType,
              iconUrl: ability['displayIcon']?.toString(),
              isWeaponIcon: false,
            );
          }
        }
      }
    }

    return KillWeaponInfo(
      label: damageItem.isNotEmpty ? damageItem : damageType,
      iconUrl: null,
      isWeaponIcon: false,
    );
  }
}

class KillWeaponInfo {
  final String label;
  final String? iconUrl;
  final bool isWeaponIcon;
  const KillWeaponInfo({
    required this.label,
    required this.iconUrl,
    required this.isWeaponIcon,
  });
}
