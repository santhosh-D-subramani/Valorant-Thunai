import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/utils/cache_managers.dart';
import 'package:valorant_thunai/services/video_cache_manager.dart';
import 'package:valorant_thunai/services/valorant_api.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class CacheManagerPage extends ConsumerStatefulWidget {
  const CacheManagerPage({super.key});

  @override
  ConsumerState<CacheManagerPage> createState() => _CacheManagerPageState();
}

class _CacheManagerPageState extends ConsumerState<CacheManagerPage> {
  double _rankCacheSize = 0.0;
  double _bundleCacheSize = 0.0;
  double _dailyStoreCacheSize = 0.0;
  double _loadoutPresetCacheSize = 0.0;
  double _videoCacheSize = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCacheSizes();
  }

  Future<void> _loadCacheSizes() async {
    setState(() {
      _isLoading = true;
    });

    final rankSize = await CustomCacheManagers.getCacheSizeInMB(
      CustomCacheManagers.tierImageCacheKey,
    );
    final bundleSize = await CustomCacheManagers.getCacheSizeInMB(
      CustomCacheManagers.bundleCacheKey,
    );
    final dailyStoreSize = await CustomCacheManagers.getCacheSizeInMB(
      CustomCacheManagers.dailyStoreCacheKey,
    );
    final loadoutPresetSize = await CustomCacheManagers.getCacheSizeInMB(
      CustomCacheManagers.loadoutPresetCacheKey,
    );
    final videoSize = await VideoCacheManager.getCacheSizeInMB();

    if (mounted) {
      setState(() {
        _rankCacheSize = rankSize;
        _bundleCacheSize = bundleSize;
        _dailyStoreCacheSize = dailyStoreSize;
        _loadoutPresetCacheSize = loadoutPresetSize;
        _videoCacheSize = videoSize;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmClearCache({
    required String title,
    required Future<void> Function() onClear,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearCacheDialogTitle(title)),
        content: Text(
          l10n.clearCacheDialogContent(title),
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Colors.grey),
            ),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text(
              l10n.clearButton,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });
      await onClear();
      await _loadCacheSizes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cacheClearedSuccess(title))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cacheManagerTitle)),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildSectionGroup(
                    context,
                    title: l10n.cacheInfoSectionHeader,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          l10n.cacheInfoDescription,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildSectionGroup(
                    context,
                    title: l10n.managedCachesSectionHeader,
                    children: [
                      _buildCacheTile(
                        title: l10n.rankIconsCacheTitle,
                        subtitle: l10n.rankIconsCacheSubtitle,
                        sizeInMB: _rankCacheSize,
                        onClear: () => _confirmClearCache(
                          title: l10n.rankIconsCacheTitle,
                          onClear: () => CustomCacheManagers.clearCache(
                            CustomCacheManagers.tierImageCacheManager,
                            CustomCacheManagers.tierImageCacheKey,
                          ),
                        ),
                      ),
                      _buildCacheTile(
                        title: l10n.bundleImagesCacheTitle,
                        subtitle: l10n.bundleImagesCacheSubtitle,
                        sizeInMB: _bundleCacheSize,
                        onClear: () => _confirmClearCache(
                          title: l10n.bundleImagesCacheTitle,
                          onClear: () => CustomCacheManagers.clearCache(
                            CustomCacheManagers.bundleCacheManager,
                            CustomCacheManagers.bundleCacheKey,
                          ),
                        ),
                      ),
                      _buildCacheTile(
                        title: l10n.dailyStoreImagesCacheTitle,
                        subtitle: l10n.dailyStoreImagesCacheSubtitle,
                        sizeInMB: _dailyStoreCacheSize,
                        onClear: () => _confirmClearCache(
                          title: l10n.dailyStoreImagesCacheTitle,
                          onClear: () => CustomCacheManagers.clearCache(
                            CustomCacheManagers.dailyStoreCacheManager,
                            CustomCacheManagers.dailyStoreCacheKey,
                          ),
                        ),
                      ),
                      _buildCacheTile(
                        title: l10n.loadoutPresetImagesCacheTitle,
                        subtitle: l10n.loadoutPresetImagesCacheSubtitle,
                        sizeInMB: _loadoutPresetCacheSize,
                        onClear: () => _confirmClearCache(
                          title: l10n.loadoutPresetImagesCacheTitle,
                          onClear: () => CustomCacheManagers.clearCache(
                            CustomCacheManagers.loadoutPresetCacheManager,
                            CustomCacheManagers.loadoutPresetCacheKey,
                          ),
                        ),
                      ),
                      _buildCacheTile(
                        title: l10n.videoPreviewCacheTitle,
                        subtitle: l10n.videoPreviewCacheSubtitle,
                        sizeInMB: _videoCacheSize,
                        onClear: () => _confirmClearCache(
                          title: l10n.videoPreviewCacheTitle,
                          onClear: () => VideoCacheManager.clearCache(),
                        ),
                      ),
                      _buildCacheTile(
                        title: l10n.storeTextCacheTitle,
                        subtitle: l10n.storeTextCacheSubtitle,
                        sizeInMB: 0.05,
                        isTextCache: true,
                        onClear: () => _confirmClearCache(
                          title: l10n.storeTextCacheTitle,
                          onClear: () =>
                              ref.read(valorantApiProvider).clearShopCache(),
                        ),
                      ),
                      _buildCacheTile(
                        title: l10n.friendNamesCacheTitle,
                        subtitle: l10n.friendNamesCacheSubtitle,
                        sizeInMB: 0.05,
                        isTextCache: true,
                        onClear: () => _confirmClearCache(
                          title: l10n.friendNamesCacheTitle,
                          onClear: () => ref
                              .read(valorantApiProvider)
                              .clearFriendNameCache(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionGroup(
    BuildContext context, {
    String? title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 6),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              child: Column(
                children: children.asMap().entries.map((entry) {
                  final index = entry.key;
                  final child = entry.value;
                  final isLast = index == children.length - 1;
                  return Column(
                    children: [
                      child,
                      if (!isLast)
                        Divider(
                          height: 1,
                          thickness: 1,
                          indent: 16,
                          color: Colors.grey.withValues(alpha: 0.1),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheTile({
    required String title,
    required String subtitle,
    required double sizeInMB,
    required VoidCallback onClear,
    bool isTextCache = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isTextCache
                  ? '~0.05 MB (SharedPreferences)'
                  : '${sizeInMB.toStringAsFixed(2)} MB',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      trailing: TextButton(
        onPressed: onClear,
        child: const Text(
          'Clear',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
