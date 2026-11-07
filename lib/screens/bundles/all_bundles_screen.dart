import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:valorant_thunai/screens/bundles/bundle_detail_screen.dart';
import 'package:valorant_thunai/providers/bundle_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/utils/cache_managers.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class AllPage extends ConsumerWidget {
  const AllPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundlesAsync = ref.watch(bundlesProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.allBundlesTitle)),
      body: SafeArea(
        child: bundlesAsync.when(
          loading: () => const Center(child: FunnyLoadingView()),
          error: (e, _) => Center(child: Text(l10n.errorMessage(e.toString()))),
          data: (bundles) {
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: bundles.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemBuilder: (context, index) {
                final bundle = bundles[index];

                final image =
                    bundle['displayIcon'] ?? bundle['verticalPromoImage'] ?? '';

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BundleDetailPage(uuid: bundle['uuid']),
                      ),
                    );
                  },
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: image,
                                cacheManager:
                                    CustomCacheManagers.bundleCacheManager,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) =>
                                    const Icon(Icons.image),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            bundle['displayName'] ?? l10n.noName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bundle['description'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

typedef AllBundlesScreen = AllPage;
