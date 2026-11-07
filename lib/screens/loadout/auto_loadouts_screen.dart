import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';
import 'package:valorant_thunai/models/auto_loadout_rule.dart';
import 'package:valorant_thunai/models/loadout_preset.dart';
import 'package:valorant_thunai/providers/auto_loadout_provider.dart';
import 'package:valorant_thunai/providers/preset_provider.dart';
import 'package:valorant_thunai/screens/loadout/loadout_presets_screen.dart';
import 'package:valorant_thunai/common/funny_loading_view.dart';
import 'package:valorant_thunai/screens/loadout/widgets/preset_preview_sheet.dart';

import 'widgets/rule_editor_sheet.dart';

class AutoLoadoutsScreen extends ConsumerStatefulWidget {
  const AutoLoadoutsScreen({super.key});

  @override
  ConsumerState<AutoLoadoutsScreen> createState() => _AutoLoadoutsScreenState();
}

class _AutoLoadoutsScreenState extends ConsumerState<AutoLoadoutsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isApplyingRule = false;
  bool _conflictPrefExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _conflictPreferenceLabel(
    AppLocalizations l10n,
    AutoLoadoutConflictPreference pref,
  ) {
    switch (pref) {
      case AutoLoadoutConflictPreference.preferAgent:
        return l10n.autoLoadoutConflictPreferenceSummaryAgent;
      case AutoLoadoutConflictPreference.preferMap:
        return l10n.autoLoadoutConflictPreferenceSummaryMap;
      case AutoLoadoutConflictPreference.ask:
        return l10n.autoLoadoutConflictPreferenceSummaryAsk;
    }
  }

  Future<void> _handleApplyRule(AutoLoadoutRule rule) async {
    setState(() => _isApplyingRule = true);
    try {
      await ref.read(autoLoadoutProvider.notifier).applyRulePreset(rule);
      if (!mounted) return;
      setState(() => _isApplyingRule = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Applied "${rule.presetName}" (${rule.targetName}) to Valorant!',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isApplyingRule = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to apply preset: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showTestRulesDialog(BuildContext context) async {
    final autoState = ref.read(autoLoadoutProvider).value;
    if (autoState == null) return;

    final mapNames = autoState.rules
        .where((r) => r.triggerType == AutoLoadoutTriggerType.map)
        .map((r) => r.targetName)
        .toSet()
        .toList();
    final agentNames = autoState.rules
        .where((r) => r.triggerType == AutoLoadoutTriggerType.agent)
        .map((r) => r.targetName)
        .toSet()
        .toList();

    if (mapNames.isEmpty && agentNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.autoLoadoutTestRulesEmpty ??
                'Create at least one map or agent rule first to test it.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) =>
          _TestRulesDialog(mapNames: mapNames, agentNames: agentNames),
    );
  }

  Future<void> _handleOpenRuleEditor({
    required AutoLoadoutTriggerType triggerType,
    AutoLoadoutRule? existingRule,
  }) async {
    final presetsAsync = ref.read(presetsProvider).value ?? [];
    if (presetsAsync.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No Presets Found'),
          content: const Text(
            'You need at least one saved Loadout Preset before mapping to Maps or Agents. Create one in the Loadout Presets screen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoadoutPresetsScreen(),
                  ),
                );
              },
              child: const Text('Go to Presets'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RuleEditorSheet(
        triggerType: triggerType,
        existingRule: existingRule,
        presets: presetsAsync,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final autoStateAsync = ref.watch(autoLoadoutProvider);
    final presetsAsync = ref.watch(presetsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Auto Loadouts',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'BETA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip:
                AppLocalizations.of(context)?.autoLoadoutTestRulesTooltip ??
                'Test Rules',
            icon: Icon(
              Icons.science_outlined,
              color: theme.colorScheme.primary,
            ),
            onPressed: () => _showTestRulesDialog(context),
          ),
          IconButton(
            tooltip: 'Manage Presets',
            icon: Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoadoutPresetsScreen(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          labelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.map_outlined), text: 'Map Loadouts'),
            Tab(icon: Icon(Icons.person_outline), text: 'Agent Loadouts'),
          ],
        ),
      ),
      body: autoStateAsync.when(
        loading: () => const Center(child: FunnyLoadingView()),
        error: (e, _) => Center(child: Text('Error loading auto loadouts: $e')),
        data: (autoState) {
          final mapRules = autoState.rules
              .where((r) => r.triggerType == AutoLoadoutTriggerType.map)
              .toList();
          final agentRules = autoState.rules
              .where((r) => r.triggerType == AutoLoadoutTriggerType.agent)
              .toList();

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.6,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: autoState.autoEquipEnabled
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surfaceContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              autoState.autoEquipEnabled
                                  ? Icons.bolt
                                  : Icons.bolt_outlined,
                              color: autoState.autoEquipEnabled
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              autoState.autoEquipEnabled
                                  ? (autoState.lastAppliedRuleSummary != null
                                        ? 'Auto-Sync • Last: ${autoState.lastAppliedRuleSummary}'
                                        : 'Auto-Sync in Match / Agent Select')
                                  : 'Auto-Sync disabled',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Switch.adaptive(
                            value: autoState.autoEquipEnabled,
                            onChanged: (val) {
                              ref
                                  .read(autoLoadoutProvider.notifier)
                                  .toggleAutoEquip(val);
                            },
                          ),
                        ],
                      ),
                    ),

                    InkWell(
                      onTap: () => setState(
                        () => _conflictPrefExpanded = !_conflictPrefExpanded,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.rule,
                              size: 15,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _conflictPrefExpanded
                                    ? l10n.autoLoadoutConflictPreferenceTitle
                                    : '${l10n.autoLoadoutConflictPreferenceTitle}: '
                                          '${_conflictPreferenceLabel(l10n, autoState.conflictPreference)}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              _conflictPrefExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox(width: double.infinity),
                      secondChild: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.autoLoadoutConflictPreferenceSubtitle,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SegmentedButton<AutoLoadoutConflictPreference>(
                              segments: [
                                ButtonSegment(
                                  value: AutoLoadoutConflictPreference.ask,
                                  label: Text(
                                    l10n.autoLoadoutConflictPreferenceAsk,
                                  ),
                                ),
                                ButtonSegment(
                                  value:
                                      AutoLoadoutConflictPreference.preferAgent,
                                  label: Text(
                                    l10n.autoLoadoutConflictPreferenceAgent,
                                  ),
                                ),
                                ButtonSegment(
                                  value:
                                      AutoLoadoutConflictPreference.preferMap,
                                  label: Text(
                                    l10n.autoLoadoutConflictPreferenceMap,
                                  ),
                                ),
                              ],
                              selected: {autoState.conflictPreference},
                              showSelectedIcon: false,
                              style: const ButtonStyle(
                                visualDensity: VisualDensity.compact,
                              ),
                              onSelectionChanged: (selection) {
                                ref
                                    .read(autoLoadoutProvider.notifier)
                                    .setConflictPreference(selection.first);
                              },
                            ),
                          ],
                        ),
                      ),
                      crossFadeState: _conflictPrefExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                      sizeCurve: Curves.easeInOut,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRulesList(
                      theme: theme,
                      triggerType: AutoLoadoutTriggerType.map,
                      rules: mapRules,
                      presetsAsync: presetsAsync,
                    ),

                    _buildRulesList(
                      theme: theme,
                      triggerType: AutoLoadoutTriggerType.agent,
                      rules: agentRules,
                      presetsAsync: presetsAsync,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final currentType = _tabController.index == 0
              ? AutoLoadoutTriggerType.map
              : AutoLoadoutTriggerType.agent;
          _handleOpenRuleEditor(triggerType: currentType);
        },
        icon: const Icon(Icons.add),
        label: Text(
          _tabController.index == 0 ? 'Add Map Rule' : 'Add Agent Rule',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildRulesList({
    required ThemeData theme,
    required AutoLoadoutTriggerType triggerType,
    required List<AutoLoadoutRule> rules,
    required AsyncValue<List<LoadoutPreset>> presetsAsync,
  }) {
    if (rules.isEmpty) {
      final isMap = triggerType == AutoLoadoutTriggerType.map;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isMap ? Icons.map_outlined : Icons.person_search_outlined,
                size: 64,
                color: theme.colorScheme.outlineVariant,
              ),
              const SizedBox(height: 16),
              Text(
                isMap ? 'No Map Loadouts Set' : 'No Agent Loadouts Set',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isMap
                    ? 'Assign custom skin presets to maps like Icebox, Ascent, or Haven. They will auto-apply when the game matches!'
                    : 'Assign custom skin presets to agents like Jett, Reyna, or Omen. They will auto-apply when you lock in agent select!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: () =>
                    _handleOpenRuleEditor(triggerType: triggerType),
                icon: const Icon(Icons.add),
                label: Text(isMap ? 'Create Map Rule' : 'Create Agent Rule'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: rules.length,
      itemBuilder: (context, index) {
        final rule = rules[index];
        return _buildRuleCard(theme, rule, presetsAsync);
      },
    );
  }

  Widget _buildRuleCard(
    ThemeData theme,
    AutoLoadoutRule rule,
    AsyncValue<List<LoadoutPreset>> presetsAsync,
  ) {
    final isMap = rule.triggerType == AutoLoadoutTriggerType.map;
    final presets = presetsAsync.value ?? [];
    final matchedPreset = presets.cast<LoadoutPreset?>().firstWhere(
      (p) =>
          p != null &&
          (p.id == rule.presetId ||
              p.name.toLowerCase() == rule.presetName.toLowerCase()),
      orElse: () => null,
    );
    final bool isPresetMissing = matchedPreset == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isPresetMissing
              ? theme.colorScheme.error.withValues(alpha: 0.5)
              : rule.isEnabled
              ? theme.colorScheme.outlineVariant.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 52,
                    height: 52,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child:
                        rule.targetIcon != null && rule.targetIcon!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: rule.targetIcon!,
                            fit: isMap ? BoxFit.cover : BoxFit.contain,
                            errorWidget: (_, _, _) => Icon(
                              isMap ? Icons.map : Icons.person,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        : Icon(
                            isMap ? Icons.map : Icons.person,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isMap
                                  ? theme.colorScheme.tertiaryContainer
                                  : theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isMap ? 'MAP' : 'AGENT',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: isMap
                                    ? theme.colorScheme.onTertiaryContainer
                                    : theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              rule.targetName,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (isPresetMissing)
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 13,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Preset deleted ("${rule.presetName}")',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.error,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 13,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                rule.presetName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                Switch.adaptive(
                  value: rule.isEnabled && !isPresetMissing,
                  onChanged: isPresetMissing
                      ? null
                      : (val) {
                          ref
                              .read(autoLoadoutProvider.notifier)
                              .toggleRuleEnabled(rule.id, val);
                        },
                ),

                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  onSelected: (action) {
                    if (action == 'edit') {
                      _handleOpenRuleEditor(
                        triggerType: rule.triggerType,
                        existingRule: rule,
                      );
                    } else if (action == 'delete') {
                      ref
                          .read(autoLoadoutProvider.notifier)
                          .deleteRule(rule.id);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Mapping'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            Row(
              children: [
                if (matchedPreset != null)
                  TextButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => PresetPreviewSheet(
                          preset: matchedPreset,
                          readOnly: true,
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const Text(
                      'Preview',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _handleOpenRuleEditor(
                      triggerType: rule.triggerType,
                      existingRule: rule,
                    ),
                    icon: Icon(
                      Icons.edit,
                      size: 15,
                      color: theme.colorScheme.error,
                    ),
                    label: Text(
                      'Remap',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                const Spacer(),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: (_isApplyingRule || isPresetMissing)
                      ? null
                      : () => _handleApplyRule(rule),
                  icon: const Icon(Icons.cloud_upload_outlined, size: 15),
                  label: const Text(
                    'Apply Now',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TestRulesDialog extends ConsumerStatefulWidget {
  final List<String> mapNames;
  final List<String> agentNames;

  const _TestRulesDialog({required this.mapNames, required this.agentNames});

  @override
  ConsumerState<_TestRulesDialog> createState() => _TestRulesDialogState();
}

class _TestRulesDialogState extends ConsumerState<_TestRulesDialog> {
  String? _selectedMap;
  String? _selectedAgent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final preview = ref
        .read(autoLoadoutProvider.notifier)
        .previewMatch(mapName: _selectedMap, agentName: _selectedAgent);
    final matchedRule = preview.rule;

    return AlertDialog(
      title: Text(l10n?.autoLoadoutTestRulesTitle ?? 'Test Auto Loadout Rules'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.autoLoadoutTestRulesDescription ?? 'Pick a map and/or agent to preview which rule would auto-apply.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (widget.agentNames.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _selectedAgent,
                decoration: InputDecoration(
                  labelText: l10n?.autoLoadoutTestRulesAgentLabel ?? 'Agent',
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(l10n?.autoLoadoutTestRulesNone ?? 'None'),
                  ),
                  ...widget.agentNames.map(
                    (name) => DropdownMenuItem(value: name, child: Text(name)),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedAgent = val),
              ),
            if (widget.agentNames.isNotEmpty) const SizedBox(height: 12),
            if (widget.mapNames.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _selectedMap,
                decoration: InputDecoration(
                  labelText: l10n?.autoLoadoutTestRulesMapLabel ?? 'Map',
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(l10n?.autoLoadoutTestRulesNone ?? 'None'),
                  ),
                  ...widget.mapNames.map(
                    (name) => DropdownMenuItem(value: name, child: Text(name)),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedMap = val),
              ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (matchedRule != null || preview.isConflict)
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                preview.isConflict
                    ? (l10n?.autoLoadoutTestRulesResultConflictAsk(
                            preview.conflictAgentRule!.presetName,
                            preview.conflictAgentRule!.targetName,
                            preview.conflictMapRule!.presetName,
                            preview.conflictMapRule!.targetName,
                          ) ??
                          'Two rules match — you\'d be asked to pick between '
                              '"${preview.conflictAgentRule!.presetName}" (${preview.conflictAgentRule!.targetName}) '
                              'and "${preview.conflictMapRule!.presetName}" (${preview.conflictMapRule!.targetName}).')
                    : matchedRule != null
                    ? (l10n?.autoLoadoutTestRulesResultMatch(
                            matchedRule.presetName,
                            matchedRule.targetName,
                          ) ??
                          'Would apply "${matchedRule.presetName}" (${matchedRule.targetName})')
                    : (l10n?.autoLoadoutTestRulesResultNoMatch ??
                          'No enabled rule matches this combination.'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: (matchedRule != null || preview.isConflict)
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n?.autoLoadoutTestRulesClose ?? 'Close'),
        ),
      ],
    );
  }
}
