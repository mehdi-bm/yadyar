import '../utils/digit_converter.dart';

class ShoppingItem {
  const ShoppingItem({
    this.id,
    required this.shoppingListId,
    required this.name,
    required this.category,
    this.isChecked = false,
    this.quantity,
    this.unit,
    this.price,
    this.note,
    this.isImportant = false,
    this.deletedAt,
  });

  final int? id;
  final int shoppingListId;
  final String name;
  final String category;
  final bool isChecked;

  /// مقدار به‌صورت متن ذخیره می‌شود (سازگاری با داده‌های قدیمی که ممکن است
  /// متن آزاد باشند)؛ برای محاسبه از [numericQuantity] استفاده کنید.
  final String? quantity;
  final String? unit;

  /// قیمت واحد به تومان (اختیاری).
  final double? price;
  final String? note;
  final bool isImportant;

  /// زمان انتقال به «حذف‌شده‌ها»؛ null یعنی قلم فعال است.
  final DateTime? deletedAt;

  /// مقدار عددی (با پشتیبانی از ارقام فارسی)؛ اگر متن قابل تبدیل نباشد null.
  double? get numericQuantity {
    final raw = quantity?.trim();
    if (raw == null || raw.isEmpty) return null;
    return double.tryParse(toWesternDigits(raw).replaceAll('٫', '.'));
  }

  /// جمع قیمت این قلم (قیمت واحد × مقدار؛ بدون مقدار، یک واحد حساب می‌شود).
  double? get lineTotal {
    final unitPrice = price;
    if (unitPrice == null) return null;
    return unitPrice * (numericQuantity ?? 1);
  }

  ShoppingItem copyWith({
    int? id,
    int? shoppingListId,
    String? name,
    String? category,
    bool? isChecked,
    String? quantity,
    String? unit,
    double? price,
    String? note,
    bool? isImportant,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      shoppingListId: shoppingListId ?? this.shoppingListId,
      name: name ?? this.name,
      category: category ?? this.category,
      isChecked: isChecked ?? this.isChecked,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      note: note ?? this.note,
      isImportant: isImportant ?? this.isImportant,
      deletedAt: deletedAt,
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
      'unit': unit,
      'price': price,
      'note': note,
      'isImportant': isImportant ? 1 : 0,
      'deletedAt': deletedAt?.toIso8601String(),
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
      unit: map['unit'] as String?,
      price: (map['price'] as num?)?.toDouble(),
      note: map['note'] as String?,
      isImportant: (map['isImportant'] as int? ?? 0) == 1,
      deletedAt: map['deletedAt'] == null
          ? null
          : DateTime.parse(map['deletedAt'] as String),
    );
  }
}
