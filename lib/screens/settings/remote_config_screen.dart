import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorant_thunai/providers/display_settings_provider.dart';
import 'package:valorant_thunai/services/remote_config_service.dart';
import 'package:valorant_thunai/utils/format_utils.dart';

class RemoteConfigScreen extends ConsumerStatefulWidget {
  const RemoteConfigScreen({super.key});

  @override
  ConsumerState<RemoteConfigScreen> createState() => _RemoteConfigScreenState();
}

class _RemoteConfigScreenState extends ConsumerState<RemoteConfigScreen> {
  late final TextEditingController _urlController;
  bool _isTesting = false;
  String? _testStatusMessage;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    final service = ref.read(remoteConfigServiceProvider);
    _urlController = TextEditingController(text: service.configUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testCurrentUrl() async {
    setState(() {
      _isTesting = true;
      _testStatusMessage = null;
      _testSuccess = null;
    });

    final service = ref.read(remoteConfigServiceProvider);
    final result = await service.testUrl(_urlController.text);

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testSuccess = result.success;
        _testStatusMessage = result.message;
      });
    }
  }

  Future<void> _saveUrl() async {
    final service = ref.read(remoteConfigServiceProvider);
    await service.setConfigUrl(_urlController.text);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('GitHub Config URL saved.')));
    }
  }

  Future<void> _resetUrl() async {
    final service = ref.read(remoteConfigServiceProvider);
    await service.resetUrlToDefault();
    _urlController.text = service.configUrl;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reset URL to default repository config.'),
        ),
      );
    }
  }

  String _formatDateTime(DateTime? dt, DisplaySettings displaySettings) {
    if (dt == null) return 'Never';
    return FormatUtils.formatDateTime(dt, displaySettings);
  }

  String _getCacheExpiryLabel(RemoteConfigService service) {
    if (service.lastFetchTime == 0) return 'No cached data';
    final age = DateTime.now().millisecondsSinceEpoch - service.lastFetchTime;
    final remainingMillis =
        RemoteConfigService.cacheValidityDuration.inMilliseconds - age;
    if (remainingMillis <= 0) {
      return 'Cache is stale (older than 24h)';
    }
    final remainingHours = (remainingMillis / (1000 * 60 * 60)).floor();
    return 'Cache valid (~${remainingHours}h remaining)';
  }

  Future<void> _editStringValue(
    BuildContext context,
    RemoteConfigService service,
    String key,
  ) async {
    final currentValue = service.getString(key);
    final textController = TextEditingController(text: currentValue);

    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $key'),
        content: TextField(
          controller: textController,
          maxLines: key == 'app_notifications' ? 6 : 2,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Value for $key',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(textController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated != null && mounted) {
      await service.setUserEdit(key, updated);
    }
  }

  Widget _buildKeyTile({
    required BuildContext context,
    required RemoteConfigService service,
    required String key,
    required String title,
    required String subtitle,
    bool isBoolean = true,
  }) {
    final theme = Theme.of(context);
    final isUserEdited = service.hasUserEdit(key);
    final isFromRemote =
        !isUserEdited && service.cachedRemoteData.containsKey(key);

    Widget badge;
    if (isUserEdited) {
      badge = Chip(
        label: const Text('Custom Edit', style: TextStyle(fontSize: 11)),
        backgroundColor: theme.colorScheme.primaryContainer,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
        deleteIcon: const Icon(Icons.undo, size: 16),
        onDeleted: () => service.clearUserEdit(key),
      );
    } else if (isFromRemote) {
      badge = Chip(
        label: const Text('From GitHub', style: TextStyle(fontSize: 11)),
        backgroundColor: theme.colorScheme.secondaryContainer.withValues(
          alpha: 0.5,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
      );
    } else {
      badge = Chip(
        label: const Text('Default', style: TextStyle(fontSize: 11)),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
      );
    }

    if (isBoolean) {
      final value = service.getBool(key);
      return SwitchListTile(
        title: Row(
          children: [
            Expanded(child: Text(title)),
            const SizedBox(width: 8),
            badge,
          ],
        ),
        subtitle: Text(
          '$subtitle\nKey: $key',
          style: theme.textTheme.bodySmall,
        ),
        value: value,
        onChanged: (newValue) async {
          await service.setUserEdit(key, newValue);
        },
      );
    } else {
      final value = service.getString(key);
      return ListTile(
        title: Row(
          children: [
            Expanded(child: Text(title)),
            const SizedBox(width: 8),
            badge,
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$subtitle\nKey: $key', style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit value',
          onPressed: () => _editStringValue(context, service, key),
        ),
        onTap: () => _editStringValue(context, service, key),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = ref.watch(remoteConfigServiceProvider);
    final displaySettings = ref.watch(displaySettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote Configuration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh from URL',
            onPressed: () => service.refreshManually(context),
          ),
          if (service.hasAnyUserEdits)
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: 'Clear all custom edits',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Reset All Edits?'),
                    content: const Text(
                      'This will remove all your custom overrides and revert all keys to the fetched URL values.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Reset All'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await service.clearAllUserEdits();
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (service.hasStalePendingUpdate)
            Card(
              color: theme.colorScheme.tertiaryContainer,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'New Config Available from GitHub',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cache expired and updated values were retrieved. Since you have custom edits, choose whether to keep your edits or override them.',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () =>
                          service.promptStaleCacheUpdateIfAvailable(context),
                      child: const Text('Review & Apply Update'),
                    ),
                  ],
                ),
              ),
            ),

          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GitHub Raw JSON Source',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Specify the raw GitHub URL for remote configuration. Cached for 1 day.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: 'GitHub Raw URL',
                      hintText: 'https://raw.githubusercontent.com/...',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _urlController.clear(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        icon: _isTesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.network_check),
                        label: const Text('Test URL'),
                        onPressed: _isTesting ? null : _testCurrentUrl,
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Save URL'),
                        onPressed: _saveUrl,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reset URL'),
                        onPressed: _resetUrl,
                      ),
                    ],
                  ),
                  if (_testStatusMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _testSuccess == true
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _testSuccess == true
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            color: _testSuccess == true
                                ? Colors.green
                                : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _testStatusMessage!,
                              style: TextStyle(
                                color: _testSuccess == true
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 24),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Last fetched: ${_formatDateTime(service.lastFetchDate, displaySettings)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        service.isCacheStale
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        size: 16,
                        color: service.isCacheStale
                            ? Colors.orange
                            : Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getCacheExpiryLabel(service),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: service.isCacheStale
                              ? Colors.orange
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Row(
            children: [
              Text(
                'Configuration Parameters',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (service.hasAnyUserEdits)
                Text(
                  '${service.userEdits.length} custom edit(s)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Edit values visually. Edits persist until you manually refresh or apply a stale remote update.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                _buildKeyTile(
                  context: context,
                  service: service,
                  key: 'enable_update_check',
                  title: 'Enable Update Checks',
                  subtitle: 'Enables automatic check for newer app releases',
                ),
                const Divider(height: 1),
                _buildKeyTile(
                  context: context,
                  service: service,
                  key: 'is_force_update',
                  title: 'Force App Update',
                  subtitle: 'Prompts non-dismissible update dialog',
                ),
                const Divider(height: 1),
                _buildKeyTile(
                  context: context,
                  service: service,
                  key: 'latest_version',
                  title: 'Latest Target Version',
                  subtitle: 'Target version for update check comparisons',
                  isBoolean: false,
                ),
                const Divider(height: 1),
                _buildKeyTile(
                  context: context,
                  service: service,
                  key: 'message',
                  title: 'Update Message',
                  subtitle: 'Description displayed inside the update prompt',
                  isBoolean: false,
                ),
                const Divider(height: 1),

                _buildKeyTile(
                  context: context,
                  service: service,
                  key: 'app_notifications',
                  title: 'App Notifications JSON',
                  subtitle: 'JSON array of remote banners and notices',
                  isBoolean: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
