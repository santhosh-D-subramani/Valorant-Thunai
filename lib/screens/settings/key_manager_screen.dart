import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_thunai/screens/settings/remote_config_screen.dart';
import 'package:valorant_thunai/services/valorant_api.dart';

class KeyManagerScreen extends StatefulWidget {
  const KeyManagerScreen({super.key});

  @override
  State<KeyManagerScreen> createState() => _KeyManagerScreenState();
}

class _KeyManagerScreenState extends State<KeyManagerScreen> {
  final _henrikController = TextEditingController();
  final _clientVersionController = TextEditingController();

  bool _isHenrikVisible = false;
  bool _isClientVersionVisible = false;

  bool _isTestingHenrik = false;
  String? _henrikTestResult;
  bool? _henrikTestSuccess;

  bool _hasSavedHenrikKey = false;
  bool _hasSavedClientVersion = false;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  @override
  void dispose() {
    _henrikController.dispose();
    _clientVersionController.dispose();
    super.dispose();
  }

  Future<void> _loadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final customHenrik = prefs.getString(ValorantApi.prefHenrikApiKey);
    final customVersion = prefs.getString('custom_riot_client_version');

    setState(() {
      if (customHenrik != null && customHenrik.isNotEmpty) {
        _henrikController.text = customHenrik;
        _hasSavedHenrikKey = true;
      } else if (ValorantApi.henrikApiKey.isNotEmpty) {
        _henrikController.text = ValorantApi.henrikApiKey;
      }

      if (customVersion != null && customVersion.isNotEmpty) {
        _clientVersionController.text = customVersion;
        _hasSavedClientVersion = true;
      }
    });
  }

  Future<void> _saveHenrikKey() async {
    final key = _henrikController.text.trim();
    await ValorantApi.setCustomApiKey(key.isEmpty ? null : key);
    setState(() {
      _hasSavedHenrikKey = key.isNotEmpty;
      _henrikTestResult = null;
      _henrikTestSuccess = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            key.isEmpty
                ? 'HenrikDev API key cleared (using direct Riot endpoints)'
                : 'HenrikDev API key saved',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _testHenrikKey() async {
    final key = _henrikController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _henrikTestResult = 'Please enter an API key to test';
        _henrikTestSuccess = false;
      });
      return;
    }

    setState(() {
      _isTestingHenrik = true;
      _henrikTestResult = null;
      _henrikTestSuccess = null;
    });

    final result = await ValorantApi.testHenrikApiKey(key);

    if (mounted) {
      setState(() {
        _isTestingHenrik = false;
        _henrikTestResult = result.message;
        _henrikTestSuccess = result.success;
      });
    }
  }

  Future<void> _pasteHenrikFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _henrikController.text = data.text!.trim();
      });
    }
  }

  Future<void> _saveClientVersion() async {
    final version = _clientVersionController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    if (version.isEmpty) {
      await prefs.remove('custom_riot_client_version');
      setState(() {
        _hasSavedClientVersion = false;
      });
    } else {
      await prefs.setString('custom_riot_client_version', version);
      setState(() {
        _hasSavedClientVersion = true;
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            version.isEmpty
                ? 'Client version override cleared'
                : 'Client version override saved',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('API Keys & Credentials'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Local Credential Storage',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'All API keys and tokens are stored locally on your device. Fields are masked by default to protect your credentials from shoulder-surfing.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.key_rounded,
                            size: 20,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'HenrikDev API Key',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'External match history & unofficial player lookup',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _hasSavedHenrikKey
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _hasSavedHenrikKey
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.info_outline_rounded,
                                size: 14,
                                color: _hasSavedHenrikKey
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _hasSavedHenrikKey
                                    ? 'Custom Key Active'
                                    : 'Not Configured (Using Riot Endpoints)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _hasSavedHenrikKey
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _henrikController,
                      obscureText: !_isHenrikVisible,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'API Key',
                        hintText: 'HDEV-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.password_rounded),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                _isHenrikVisible
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                              ),
                              tooltip: _isHenrikVisible
                                  ? 'Hide API Key'
                                  : 'Unhide API Key',
                              onPressed: () {
                                setState(() {
                                  _isHenrikVisible = !_isHenrikVisible;
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.paste_rounded),
                              tooltip: 'Paste from clipboard',
                              onPressed: _pasteHenrikFromClipboard,
                            ),
                            if (_henrikController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                tooltip: 'Clear',
                                onPressed: () {
                                  setState(() {
                                    _henrikController.clear();
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_henrikTestResult != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _henrikTestSuccess == true
                              ? colorScheme.primaryContainer.withValues(
                                  alpha: 0.5,
                                )
                              : colorScheme.errorContainer.withValues(
                                  alpha: 0.5,
                                ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _henrikTestSuccess == true
                                ? colorScheme.primary
                                : colorScheme.error,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _henrikTestSuccess == true
                                  ? Icons.check_circle_rounded
                                  : Icons.error_outline_rounded,
                              size: 16,
                              color: _henrikTestSuccess == true
                                  ? colorScheme.primary
                                  : colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _henrikTestResult!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _henrikTestSuccess == true
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: _isTestingHenrik
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.speed_rounded, size: 18),
                            label: const Text('Test Key'),
                            onPressed: _isTestingHenrik ? null : _testHenrikKey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.save_rounded, size: 18),
                            label: const Text('Save Key'),
                            onPressed: _saveHenrikKey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            size: 20,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Riot Client Version Override',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Optional header override for X-Riot-ClientVersion',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _hasSavedClientVersion
                                ? colorScheme.secondaryContainer
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _hasSavedClientVersion
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.info_outline_rounded,
                                size: 14,
                                color: _hasSavedClientVersion
                                    ? colorScheme.onSecondaryContainer
                                    : colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _hasSavedClientVersion
                                    ? 'Custom Override Active'
                                    : 'Using Auto-Resolved Version',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _hasSavedClientVersion
                                      ? colorScheme.onSecondaryContainer
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _clientVersionController,
                      obscureText: !_isClientVersionVisible,
                      decoration: InputDecoration(
                        labelText: 'Client Version Override',
                        hintText: 'e.g. release-13.09-shipping-18-5804228',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isClientVersionVisible
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                          onPressed: () {
                            setState(() {
                              _isClientVersionVisible =
                                  !_isClientVersionVisible;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: const Text('Save Override'),
                        onPressed: _saveClientVersion,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.cloud_sync_outlined,
                    size: 20,
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
                title: const Text('GitHub Remote Config URL'),
                subtitle: const Text(
                  'Configure custom raw JSON configuration source',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const RemoteConfigScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
