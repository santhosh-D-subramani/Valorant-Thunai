enum AutoLoadoutTriggerType { map, agent }

enum AutoLoadoutConflictPreference { ask, preferAgent, preferMap }

class AutoLoadoutRule {
  final String id;
  final AutoLoadoutTriggerType triggerType;
  final String targetId;
  final String targetName;
  final String? targetIcon;
  final String presetId;
  final String presetName;
  final bool isEnabled;

  AutoLoadoutRule({
    required this.id,
    required this.triggerType,
    required this.targetId,
    required this.targetName,
    this.targetIcon,
    required this.presetId,
    required this.presetName,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'triggerType': triggerType.name,
    'targetId': targetId,
    'targetName': targetName,
    if (targetIcon != null) 'targetIcon': targetIcon,
    'presetId': presetId,
    'presetName': presetName,
    'isEnabled': isEnabled,
  };

  factory AutoLoadoutRule.fromJson(Map<String, dynamic> json) =>
      AutoLoadoutRule(
        id: json['id'] as String? ?? '',
        triggerType: json['triggerType'] == 'agent'
            ? AutoLoadoutTriggerType.agent
            : AutoLoadoutTriggerType.map,
        targetId: json['targetId'] as String? ?? '',
        targetName: json['targetName'] as String? ?? '',
        targetIcon: json['targetIcon'] as String?,
        presetId: json['presetId'] as String? ?? '',
        presetName: json['presetName'] as String? ?? '',
        isEnabled: json['isEnabled'] as bool? ?? true,
      );

  AutoLoadoutRule copyWith({
    String? id,
    AutoLoadoutTriggerType? triggerType,
    String? targetId,
    String? targetName,
    String? targetIcon,
    String? presetId,
    String? presetName,
    bool? isEnabled,
  }) {
    return AutoLoadoutRule(
      id: id ?? this.id,
      triggerType: triggerType ?? this.triggerType,
      targetId: targetId ?? this.targetId,
      targetName: targetName ?? this.targetName,
      targetIcon: targetIcon ?? this.targetIcon,
      presetId: presetId ?? this.presetId,
      presetName: presetName ?? this.presetName,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

class AutoLoadoutConflict {
  final String? matchId;
  final AutoLoadoutRule agentRule;
  final String agentPresetName;
  final AutoLoadoutRule mapRule;
  final String mapPresetName;

  const AutoLoadoutConflict({
    required this.matchId,
    required this.agentRule,
    required this.agentPresetName,
    required this.mapRule,
    required this.mapPresetName,
  });
}

class AutoLoadoutPreviewResult {
  final AutoLoadoutRule? rule;
  final AutoLoadoutRule? conflictAgentRule;
  final AutoLoadoutRule? conflictMapRule;

  const AutoLoadoutPreviewResult({
    this.rule,
    this.conflictAgentRule,
    this.conflictMapRule,
  });

  bool get isConflict => conflictAgentRule != null && conflictMapRule != null;
}
