/// دسته‌بندی اقلام خرید؛ کاربر می‌تواند دسته جدید بسازد، نام/آیکون/رنگ آن را
/// تغییر دهد و ترتیب نمایش دسته‌ها را عوض کند.
///
/// آیتم‌ها دسته را با «نام» ذخیره می‌کنند (ستون متنی category)، پس تغییر نام یک
/// دسته باید در آیتم‌ها هم اعمال شود؛ این کار در ریپازیتوری انجام می‌شود.
class ShoppingCategory {
  const ShoppingCategory({
    this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    this.sortOrder = 0,
  });

  /// دسته پیش‌فرض که قابل حذف یا تغییر نام نیست؛ آیتم‌های یک دسته حذف‌شده
  /// به این دسته منتقل می‌شوند.
  static const String fallbackName = 'سایر';

  static const String defaultIconKey = 'cart';
  static const int defaultColorValue = 0xFF78909C;

  /// دسته‌های اولیه‌ای که روی نصب جدید (و هنگام ارتقای پایگاه‌داده) ساخته می‌شوند.
  static const List<ShoppingCategory> defaults = [
    ShoppingCategory(
      name: 'میوه و سبزیجات',
      iconKey: 'produce',
      colorValue: 0xFF43A047,
    ),
    ShoppingCategory(name: 'لبنیات', iconKey: 'dairy', colorValue: 0xFF42A5F5),
    ShoppingCategory(
      name: 'گوشت و پروتئین',
      iconKey: 'meat',
      colorValue: 0xFFE53935,
    ),
    ShoppingCategory(
      name: 'نان و غلات',
      iconKey: 'bakery',
      colorValue: 0xFFFFA726,
    ),
    ShoppingCategory(
      name: 'بهداشتی',
      iconKey: 'hygiene',
      colorValue: 0xFF26C6DA,
    ),
    ShoppingCategory(name: 'خانه', iconKey: 'home', colorValue: 0xFF8D6E63),
    ShoppingCategory(name: 'نوشیدنی', iconKey: 'drink', colorValue: 0xFF7E57C2),
    ShoppingCategory(
      name: fallbackName,
      iconKey: 'other',
      colorValue: defaultColorValue,
    ),
  ];

  final int? id;
  final String name;
  final String iconKey;
  final int colorValue;
  final int sortOrder;

  bool get isFallback => name == fallbackName;

  ShoppingCategory copyWith({
    int? id,
    String? name,
    String? iconKey,
    int? colorValue,
    int? sortOrder,
  }) {
    return ShoppingCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'iconKey': iconKey,
      'colorValue': colorValue,
      'sortOrder': sortOrder,
    };
  }

  factory ShoppingCategory.fromMap(Map<String, Object?> map) {
    return ShoppingCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      iconKey: map['iconKey'] as String? ?? defaultIconKey,
      colorValue: map['colorValue'] as int? ?? defaultColorValue,
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }
}
