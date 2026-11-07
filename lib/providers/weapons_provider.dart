import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final weaponsProvider = FutureProvider<List<dynamic>>((ref) async {
  final response = await http.get(
    Uri.parse('https://valorant-api.com/v1/weapons'),
  );
  if (response.statusCode == 200) {
    return jsonDecode(response.body)['data'];
  } else {
    throw Exception('Failed to load weapons');
  }
});
final allBuddiesProvider = FutureProvider<List<dynamic>>((ref) async {
  final response = await http.get(
    Uri.parse('https://valorant-api.com/v1/buddies'),
  );
  if (response.statusCode == 200) {
    return jsonDecode(response.body)['data'];
  } else {
    throw Exception('Failed to load buddies');
  }
});

final allSpraysProvider = FutureProvider<List<dynamic>>((ref) async {
  final response = await http.get(
    Uri.parse('https://valorant-api.com/v1/sprays'),
  );
  if (response.statusCode == 200) {
    return jsonDecode(response.body)['data'];
  } else {
    throw Exception('Failed to load sprays');
  }
});

final allTitlesProvider = FutureProvider<List<dynamic>>((ref) async {
  final response = await http.get(
    Uri.parse('https://valorant-api.com/v1/playertitles'),
  );
  if (response.statusCode == 200) {
    return jsonDecode(response.body)['data'];
  } else {
    throw Exception('Failed to load titles');
  }
});

final allCardsProvider = FutureProvider<List<dynamic>>((ref) async {
  final response = await http.get(
    Uri.parse('https://valorant-api.com/v1/playercards'),
  );
  if (response.statusCode == 200) {
    return jsonDecode(response.body)['data'];
  } else {
    throw Exception('Failed to load player cards');
  }
});

final allFlexesProvider = FutureProvider<List<dynamic>>((ref) async {
  final response = await http.get(
    Uri.parse('https://valorant-api.com/v1/flex'),
  );
  if (response.statusCode == 200) {
    return jsonDecode(response.body)['data'];
  } else {
    throw Exception('Failed to load flex items');
  }
});
