class ShoppingList {
  const ShoppingList({
    this.id,
    required this.name,
    required this.createdAt,
    this.colorValue,
  });

  final int? id;
  final String name;
  final DateTime createdAt;

  /// رنگ دلخواه لیست (ARGB)؛ null یعنی رنگ اصلی تم.
  final int? colorValue;

  ShoppingList copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    int? colorValue,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'colorValue': colorValue,
    };
  }

  factory ShoppingList.fromMap(Map<String, Object?> map) {
    return ShoppingList(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      colorValue: map['colorValue'] as int?,
    );
  }
}
