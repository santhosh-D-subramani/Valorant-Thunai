import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/models/auto_loadout_rule.dart';
import 'package:valorant_thunai/models/loadout_preset.dart';
import 'package:valorant_thunai/providers/auto_loadout_provider.dart';
import 'package:valorant_thunai/providers/profile_provider.dart';
import 'package:valorant_thunai/screens/loadout/widgets/preset_preview_sheet.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';

class RuleEditorSheet extends ConsumerStatefulWidget {
  final AutoLoadoutTriggerType triggerType;
  final AutoLoadoutRule? existingRule;
  final List<LoadoutPreset> presets;

  const RuleEditorSheet({
    super.key,
    required this.triggerType,
    this.existingRule,
    required this.presets,
  });

  @override
  ConsumerState<RuleEditorSheet> createState() => _RuleEditorSheetState();
}

class _RuleEditorSheetState extends ConsumerState<RuleEditorSheet> {
  String? _selectedTargetId;
  String? _selectedTargetName;
  String? _selectedTargetIcon;
  String? _selectedPresetId;
  String? _selectedPresetName;

  @override
  void initState() {
    super.initState();
    if (widget.existingRule != null) {
      _selectedTargetId = widget.existingRule!.targetId;
      _selectedTargetName = widget.existingRule!.targetName;
      _selectedTargetIcon = widget.existingRule!.targetIcon;
      _selectedPresetId = widget.existingRule!.presetId;
      _selectedPresetName = widget.existingRule!.presetName;
    } else {
      if (widget.presets.isNotEmpty) {
        _selectedPresetId = widget.presets.first.id;
        _selectedPresetName = widget.presets.first.name;
      }
    }
  }

  void _handleSave() {
    if (_selectedTargetId == null || _selectedTargetName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a target map or agent')),
      );
      return;
    }

    if (_selectedPresetId == null || _selectedPresetName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a loadout preset')),
      );
      return;
    }

    final rule = AutoLoadoutRule(
      id:
          widget.existingRule?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      triggerType: widget.triggerType,
      targetId: _selectedTargetId!,
      targetName: _selectedTargetName!,
      targetIcon: _selectedTargetIcon,
      presetId: _selectedPresetId!,
      presetName: _selectedPresetName!,
      isEnabled: widget.existingRule?.isEnabled ?? true,
    );

    ref.read(autoLoadoutProvider.notifier).saveRule(rule);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMap = widget.triggerType == AutoLoadoutTriggerType.map;
    final mapsAsync = ref.watch(mapsMapProvider);
    final agentsAsync = ref.watch(agentsMapProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.existingRule != null
                            ? 'Edit ${isMap ? 'Map' : 'Agent'} Rule'
                            : 'New ${isMap ? 'Map' : 'Agent'} Auto Loadout',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose ${isMap ? 'a map' : 'an agent'} and pair it with your preset',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'STEP 1',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SELECT PRESET TO EQUIP',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                ...widget.presets.map((preset) {
                  final isSelected = _selectedPresetId == preset.id;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    color: isSelected
                        ? theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.5,
                          )
                        : theme.colorScheme.surfaceContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant.withValues(
                                alpha: 0.4,
                              ),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() {
                          _selectedPresetId = preset.id;
                          _selectedPresetName = preset.name;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                preset.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? theme.colorScheme.onPrimaryContainer
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                Icons.visibility_outlined,
                                size: 18,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              tooltip: 'Inspect Preset',
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => PresetPreviewSheet(
                                    preset: preset,
                                    readOnly: true,
                                  ),
                                );
                              },
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isMap
                            ? theme.colorScheme.tertiaryContainer
                            : theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'STEP 2',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isMap
                              ? theme.colorScheme.onTertiaryContainer
                              : theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isMap
                          ? 'SELECT MAP TO TRIGGER ON'
                          : 'SELECT AGENT TO TRIGGER ON',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (isMap)
                  mapsAsync.when(
                    loading: () => const Center(child: FunnyLoadingView()),
                    error: (e, _) => Text('Error loading maps: $e'),
                    data: (mapsDict) {
                      final uniqueMaps = <String, Map<String, dynamic>>{};
                      for (var entry in mapsDict.entries) {
                        final val = entry.value as Map<String, dynamic>;
                        final name = val['displayName'] as String? ?? '';
                        final splash =
                            val['splash'] as String? ??
                            val['listViewIcon'] as String? ??
                            '';
                        if (name.isNotEmpty &&
                            !name.contains('Basic Training') &&
                            !name.contains('The Range')) {
                          uniqueMaps[name] = {
                            'id': val['mapUrl'] ?? val['uuid'] ?? name,
                            'name': name,
                            'icon': splash,
                          };
                        }
                      }
                      final mapList = uniqueMaps.values.toList()
                        ..sort((a, b) => a['name'].compareTo(b['name']));

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.6,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                        itemCount: mapList.length,
                        itemBuilder: (context, index) {
                          final item = mapList[index];
                          final isSelected =
                              _selectedTargetName == item['name'];

                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              setState(() {
                                _selectedTargetId = item['id'];
                                _selectedTargetName = item['name'];
                                _selectedTargetIcon = item['icon'];
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outlineVariant
                                            .withValues(alpha: 0.4),
                                  width: isSelected ? 2.5 : 1,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if ((item['icon'] as String).isNotEmpty)
                                    CachedNetworkImage(
                                      imageUrl: item['icon'],
                                      fit: BoxFit.cover,
                                      errorWidget: (_, _, _) => Container(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                      ),
                                    ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.8),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    right: 8,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item['name'],
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  )
                else
                  agentsAsync.when(
                    loading: () => const Center(child: FunnyLoadingView()),
                    error: (e, _) => Text('Error loading agents: $e'),
                    data: (agentsDict) {
                      final uniqueAgents = <String, Map<String, dynamic>>{};
                      for (var entry in agentsDict.entries) {
                        final val = entry.value as Map<String, dynamic>;
                        final name = val['displayName'] as String? ?? '';
                        final icon = val['displayIcon'] as String? ?? '';
                        final isPlayable = val['isPlayableCharacter'] ?? true;
                        if (name.isNotEmpty && isPlayable) {
                          uniqueAgents[name] = {
                            'id': val['uuid'] ?? name,
                            'name': name,
                            'icon': icon,
                          };
                        }
                      }
                      final agentList = uniqueAgents.values.toList()
                        ..sort((a, b) => a['name'].compareTo(b['name']));

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.9,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: agentList.length,
                        itemBuilder: (context, index) {
                          final item = agentList[index];
                          final isSelected =
                              _selectedTargetName == item['name'];

                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              setState(() {
                                _selectedTargetId = item['id'];
                                _selectedTargetName = item['name'];
                                _selectedTargetIcon = item['icon'];
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primaryContainer
                                          .withValues(alpha: 0.6)
                                    : theme.colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outlineVariant
                                            .withValues(alpha: 0.4),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: (item['icon'] as String).isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: item['icon'],
                                            fit: BoxFit.contain,
                                            errorWidget: (_, _, _) =>
                                                const Icon(Icons.person),
                                          )
                                        : const Icon(Icons.person),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['name'],
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? theme.colorScheme.onPrimaryContainer
                                          : theme.colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _handleSave,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text(
                      'Save Mapping',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
