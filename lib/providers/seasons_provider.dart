import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/services/valorant_api.dart';

final seasonsProvider = FutureProvider<List<dynamic>>((ref) async {
  return ValorantApi.getSeasons();
});

final actLabelsBySeasonIdProvider = FutureProvider<Map<String, String>>((
  ref,
) async {
  final seasons = await ref.watch(seasonsProvider.future);

  final byUuid = <String, Map<String, dynamic>>{
    for (final s in seasons)
      (s['uuid']?.toString() ?? ''): (s as Map<String, dynamic>),
  };

  final labels = <String, String>{};
  for (final s in seasons) {
    final type = s['type']?.toString() ?? '';
    if (!type.contains('Act')) continue;
    final uuid = s['uuid']?.toString();
    if (uuid == null) continue;
    final actName = s['displayName']?.toString() ?? '';
    final parentUuid = s['parentUuid']?.toString();
    final episode = parentUuid != null ? byUuid[parentUuid] : null;
    final episodeName = episode?['displayName']?.toString();
    labels[uuid] = (episodeName != null && episodeName.isNotEmpty)
        ? '$episodeName — $actName'
        : actName;
  }
  return labels;
});
