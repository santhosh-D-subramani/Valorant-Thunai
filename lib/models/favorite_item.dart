class FavoriteItem {
  final String id;
  final DateTime originalDate;
  final DateTime updatedDate;
  final bool isFavorite;

  FavoriteItem({
    required this.id,
    required this.originalDate,
    required this.updatedDate,
    required this.isFavorite,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalDate': originalDate.toIso8601String(),
      'updatedDate': updatedDate.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      id: json['id'] as String,
      originalDate: DateTime.parse(json['originalDate'] as String),
      updatedDate: DateTime.parse(json['updatedDate'] as String),
      isFavorite: json['isFavorite'] as bool,
    );
  }

  FavoriteItem copyWith({
    String? id,
    DateTime? originalDate,
    DateTime? updatedDate,
    bool? isFavorite,
  }) {
    return FavoriteItem(
      id: id ?? this.id,
      originalDate: originalDate ?? this.originalDate,
      updatedDate: updatedDate ?? this.updatedDate,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
