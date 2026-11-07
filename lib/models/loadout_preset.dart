class GunPresetItem {
  final String id;
  final String skinId;
  final String skinLevelId;
  final String chromaId;
  final String? charmId;
  final String? charmLevelId;
  final String? charmInstanceId;

  GunPresetItem({
    required this.id,
    required this.skinId,
    required this.skinLevelId,
    required this.chromaId,
    this.charmId,
    this.charmLevelId,
    this.charmInstanceId,
  });

  Map<String, dynamic> toJson() => {
    'ID': id,
    'SkinID': skinId,
    'SkinLevelID': skinLevelId,
    'ChromaID': chromaId,
    if (charmId != null) 'CharmID': charmId,
    if (charmLevelId != null) 'CharmLevelID': charmLevelId,
    if (charmInstanceId != null) 'CharmInstanceID': charmInstanceId,
  };

  factory GunPresetItem.fromJson(Map<String, dynamic> json) => GunPresetItem(
    id: json['ID'] ?? json['id'] ?? '',
    skinId: json['SkinID'] ?? json['skinId'] ?? '',
    skinLevelId: json['SkinLevelID'] ?? json['skinLevelId'] ?? '',
    chromaId: json['ChromaID'] ?? json['chromaId'] ?? '',
    charmId: json['CharmID'] ?? json['charmId'],
    charmLevelId: json['CharmLevelID'] ?? json['charmLevelId'],
    charmInstanceId: json['CharmInstanceID'] ?? json['charmInstanceId'],
  );
}

class LoadoutPreset {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<GunPresetItem> guns;
  final Map<String, dynamic>? identity;
  final List<dynamic>? sprays;
  final List<dynamic>? expressions;

  LoadoutPreset({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.guns,
    this.identity,
    this.sprays,
    this.expressions,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'guns': guns.map((g) => g.toJson()).toList(),
    if (identity != null) 'identity': identity,
    if (sprays != null) 'sprays': sprays,
    if (expressions != null) 'expressions': expressions,
  };

  factory LoadoutPreset.fromJson(Map<String, dynamic> json) => LoadoutPreset(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'Custom Preset',
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
        : DateTime.now(),
    guns:
        (json['guns'] as List<dynamic>?)
            ?.map((g) => GunPresetItem.fromJson(Map<String, dynamic>.from(g)))
            .toList() ??
        [],
    identity: json['identity'] != null
        ? Map<String, dynamic>.from(json['identity'])
        : null,
    sprays: json['sprays'] as List<dynamic>?,
    expressions: json['expressions'] as List<dynamic>?,
  );

  factory LoadoutPreset.fromPlayerLoadout({
    required String name,
    required Map<String, dynamic> loadout,
  }) {
    final gunsList = (loadout['Guns'] as List<dynamic>?) ?? [];
    final guns = gunsList
        .map((g) => GunPresetItem.fromJson(Map<String, dynamic>.from(g)))
        .toList();

    return LoadoutPreset(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      createdAt: DateTime.now(),
      guns: guns,
      identity: loadout['Identity'] != null
          ? Map<String, dynamic>.from(loadout['Identity'])
          : null,
      sprays: loadout['Sprays'] as List<dynamic>?,
      expressions: loadout['Expressions'] as List<dynamic>?,
    );
  }

  Map<String, dynamic> toRiotLoadout(Map<String, dynamic> currentLoadout) {
    final map = Map<String, dynamic>.from(currentLoadout);
    if (guns.isNotEmpty) {
      map['Guns'] = guns.map((g) => g.toJson()).toList();
    }
    if (identity != null) {
      final mergedIdentity = Map<String, dynamic>.from(
        currentLoadout['Identity'] as Map? ?? {},
      )..addAll(identity!);
      map['Identity'] = mergedIdentity;
    }
    if (sprays != null) {
      map['Sprays'] = sprays;
    }
    if (expressions != null) {
      map['Expressions'] = expressions;
    }
    return map;
  }
}
