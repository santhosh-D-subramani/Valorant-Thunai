import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  final PackageInfo packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.version;
});
