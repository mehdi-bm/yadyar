import '../models/shopping_item.dart';
import 'currency_formatter.dart';

/// متن «مقدار + واحد» یک قلم خرید برای نمایش (مثلاً «۲ کیلوگرم»)؛ اگر نه
/// مقداری ثبت شده باشد و نه واحدی، null.
String? describeQuantity(ShoppingItem item) {
  final unit = item.unit?.trim();
  final hasUnit = unit != null && unit.isNotEmpty;
  final numeric = item.numericQuantity;
  final raw = item.quantity?.trim();
  final amount = numeric != null
      ? formatNumber(numeric)
      : (raw == null || raw.isEmpty ? null : raw);
  if (amount == null) return hasUnit ? unit : null;
  return hasUnit ? '$amount $unit' : amount;
}
