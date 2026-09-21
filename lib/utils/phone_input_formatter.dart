import 'package:flutter/services.dart';

import 'digit_converter.dart';

final RegExp _allowedPhoneChar = RegExp(r'[0-9۰-۹٠-٩+\-() ]');

/// ارقام فارسی/عربی واردشده در فیلد تلفن را زنده به لاتین تبدیل می‌کند و
/// کاراکترهای غیرمجاز را حذف می‌کند؛ جهت فیلد LTR باقی می‌ماند.
class PhoneNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = newValue.text.runes
        .map(String.fromCharCode)
        .where(_allowedPhoneChar.hasMatch)
        .join();
    final converted = toWesternDigits(filtered);
    return TextEditingValue(
      text: converted,
      selection: TextSelection.collapsed(offset: converted.length),
    );
  }
}

/// تعداد ارقام واقعی شماره (بدون +، فاصله، خط تیره یا پرانتز) را می‌شمارد.
int phoneDigitCount(String value) =>
    toWesternDigits(value).replaceAll(RegExp(r'[^0-9]'), '').length;
