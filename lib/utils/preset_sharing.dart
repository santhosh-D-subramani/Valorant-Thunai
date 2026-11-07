import 'dart:convert';

import 'package:valorant_thunai/models/loadout_preset.dart';

class PresetSharing {
  static const String _prefix = 'VALSHOP-PRESET-';

  static String encode(LoadoutPreset preset) {
    final json = jsonEncode(preset.toJson());
    return '$_prefix${base64Url.encode(utf8.encode(json))}';
  }

  static LoadoutPreset? decode(String code) {
    final trimmed = code.trim();
    final payload = trimmed.startsWith(_prefix)
        ? trimmed.substring(_prefix.length)
        : trimmed;
    try {
      final json = utf8.decode(base64Url.decode(base64Url.normalize(payload)));
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final parsed = LoadoutPreset.fromJson(decoded);
      if (parsed.guns.isEmpty) return null;
      return LoadoutPreset(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: parsed.name,
        createdAt: DateTime.now(),
        guns: parsed.guns,
        identity: parsed.identity,
        sprays: parsed.sprays,
        expressions: parsed.expressions,
      );
    } catch (_) {
      return null;
    }
  }

  static String uniqueImportName(String name, List<LoadoutPreset> existing) {
    final existingNames = existing
        .map((p) => p.name.trim().toLowerCase())
        .toSet();
    if (!existingNames.contains(name.trim().toLowerCase())) return name;

    var candidate = '$name (Imported)';
    var suffix = 2;
    while (existingNames.contains(candidate.trim().toLowerCase())) {
      candidate = '$name (Imported $suffix)';
      suffix++;
    }
    return candidate;
  }
}
