import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'digit_converter.dart';

final NumberFormat _amountFormat = NumberFormat.decimalPattern('fa');

String formatTooman(num amount) => '${_amountFormat.format(amount)} تومان';

/// همان مبلغ گروه‌بندی‌شده با جداکننده هزارگان، بدون واحد «تومان» — برای
/// نمایش داخل فیلدهای قابل ویرایش.
String formatAmountInput(num amount) => _amountFormat.format(amount);

/// رشته فرمت‌شده با جداکننده هزارگان (ارقام فارسی یا غربی) را به عدد صحیح
/// خام تبدیل می‌کند؛ اگر هیچ رقمی نباشد null برمی‌گرداند.
int? parseFormattedAmount(String input) {
  final normalized = toWesternDigits(
    input,
  ).replaceAll('٫', '.').replaceAll(RegExp(r'[^\d.]'), '');
  if (normalized.isEmpty || normalized == '.') return null;
  final value = double.tryParse(normalized);
  if (value == null) return null;
  return value.round();
}

/// جداکننده هزارگان را هنگام تایپ به‌صورت زنده روی مبلغ اعمال می‌کند.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final amount = parseFormattedAmount(newValue.text);
    if (amount == null) {
      return const TextEditingValue();
    }
    final formatted = _amountFormat.format(amount);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
