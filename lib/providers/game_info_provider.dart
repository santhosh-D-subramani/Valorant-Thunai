import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final gameInfoMapsProvider = FutureProvider<List<dynamic>>((ref) async {
  final response = await http.get(
    Uri.parse('https://valorant-api.com/v1/maps'),
  );
  if (response.statusCode == 200) {
    final List data = jsonDecode(response.body)['data'];
    return data
        .where((m) => (m['displayIcon'] ?? m['splash']) != null)
        .toList();
  }
  throw Exception('Failed to load maps');
});

final gameInfoAgentsProvider = FutureProvider<List<dynamic>>((ref) async {
  final response = await http.get(
    Uri.parse('https://valorant-api.com/v1/agents?isPlayableCharacter=true'),
  );
  if (response.statusCode == 200) {
    final List data = jsonDecode(response.body)['data'];
    return data;
  }
  throw Exception('Failed to load agents');
});

final gameInfoWeaponsProvider = FutureProvider<List<dynamic>>((ref) async {
  final response = await http.get(
    Uri.parse('https://valorant-api.com/v1/weapons'),
  );
  if (response.statusCode == 200) {
    final List data = jsonDecode(response.body)['data'];
    return data;
  }
  throw Exception('Failed to load weapons');
});

final gameInfoWeaponsByCategoryProvider =
    FutureProvider<Map<String, List<dynamic>>>((ref) async {
      final weapons = await ref.watch(gameInfoWeaponsProvider.future);
      final Map<String, List<dynamic>> grouped = {};
      for (final weapon in weapons) {
        final shopData = weapon['shopData'] as Map<String, dynamic>?;
        final category =
            shopData?['categoryText'] as String? ??
            (weapon['category'] as String? ?? 'Other').replaceFirst(
              'EEquippableCategory::',
              '',
            );
        grouped.putIfAbsent(category, () => []).add(weapon);
      }
      for (final list in grouped.values) {
        list.sort((a, b) {
          final ga = (a['shopData']?['gridPosition']?['row'] ?? 0) as num;
          final gb = (b['shopData']?['gridPosition']?['row'] ?? 0) as num;
          return ga.compareTo(gb);
        });
      }
      return grouped;
    });
