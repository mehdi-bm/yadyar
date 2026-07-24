class ShoppingItem {
  const ShoppingItem({
    this.id,
    required this.shoppingListId,
    required this.name,
    required this.category,
    this.isChecked = false,
    this.quantity,
  });

  final int? id;
  final int shoppingListId;
  final String name;
  final String category;
  final bool isChecked;
  final String? quantity;

  ShoppingItem copyWith({
    int? id,
    int? shoppingListId,
    String? name,
    String? category,
    bool? isChecked,
    String? quantity,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      shoppingListId: shoppingListId ?? this.shoppingListId,
      name: name ?? this.name,
      category: category ?? this.category,
      isChecked: isChecked ?? this.isChecked,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'shoppingListId': shoppingListId,
      'name': name,
      'category': category,
      'isChecked': isChecked ? 1 : 0,
      'quantity': quantity,
    };
  }

  factory ShoppingItem.fromMap(Map<String, Object?> map) {
    return ShoppingItem(
      id: map['id'] as int?,
      shoppingListId: map['shoppingListId'] as int,
      name: map['name'] as String,
      category: map['category'] as String,
      isChecked: (map['isChecked'] as int) == 1,
      quantity: map['quantity'] as String?,
    );
  }
}
