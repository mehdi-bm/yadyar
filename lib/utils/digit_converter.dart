const String _persianDigits = '۰۱۲۳۴۵۶۷۸۹';
const String _arabicDigits = '٠١٢٣٤٥٦٧٨٩';

/// ارقام فارسی یا عربی داخل رشته را به معادل لاتین تبدیل می‌کند؛ سایر
/// کاراکترها بدون تغییر باقی می‌مانند.
String toWesternDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    final persianIndex = _persianDigits.indexOf(ch);
    final arabicIndex = _arabicDigits.indexOf(ch);
    if (persianIndex != -1) {
      buffer.write(persianIndex);
    } else if (arabicIndex != -1) {
      buffer.write(arabicIndex);
    } else {
      buffer.write(ch);
    }
  }
  return buffer.toString();
}
