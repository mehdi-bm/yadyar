import 'package:flutter/material.dart';

import '../../../models/shopping_category.dart';
import '../../../widgets/palette_color_picker.dart';

export '../../../widgets/palette_color_picker.dart';

/// آیکون‌های قابل انتخاب برای دسته‌ها. کلید در پایگاه‌داده ذخیره می‌شود؛
/// IconData ثابت (const) لازم است تا tree-shaking آیکون‌ها در نسخه release کار کند.
const Map<String, IconData> shoppingCategoryIcons = {
  'produce': Icons.eco_outlined,
  'dairy': Icons.local_drink_outlined,
  'meat': Icons.set_meal_outlined,
  'bakery': Icons.bakery_dining_outlined,
  'hygiene': Icons.soap_outlined,
  'home': Icons.home_outlined,
  'drink': Icons.local_cafe_outlined,
  'other': Icons.category_outlined,
  'cart': Icons.shopping_basket_outlined,
  'snack': Icons.cookie_outlined,
  'frozen': Icons.ac_unit,
  'spice': Icons.grass_outlined,
  'clean': Icons.cleaning_services_outlined,
  'pharmacy': Icons.medication_outlined,
  'baby': Icons.child_friendly_outlined,
  'pet': Icons.pets_outlined,
  'clothes': Icons.checkroom_outlined,
  'electronics': Icons.devices_other_outlined,
  'stationery': Icons.edit_note,
  'gift': Icons.card_giftcard_outlined,
};

IconData shoppingCategoryIcon(String? iconKey) =>
    shoppingCategoryIcons[iconKey] ?? Icons.shopping_basket_outlined;

/// پالت رنگ خرید همان پالت مشترک اپ است.
const List<int> shoppingPalette = appColorPalette;

/// آیکون دایره‌ای رنگی یک دسته.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({super.key, required this.category, this.size = 36});

  final ShoppingCategory? category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Color(
      category?.colorValue ?? ShoppingCategory.defaultColorValue,
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        shoppingCategoryIcon(category?.iconKey),
        color: color,
        size: size * 0.55,
      ),
    );
  }
}
