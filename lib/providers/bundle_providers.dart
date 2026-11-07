import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/services/valorant_api.dart';

final bundlesProvider = FutureProvider<List<dynamic>>((ref) async {
  return ValorantApi.getBundles();
});

final bundleDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, uuid) async {
      return ValorantApi.getBundleByUuid(uuid);
    });
