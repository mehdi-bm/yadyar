import 'package:shamsi_date/shamsi_date.dart';

String formatJalaliDate(DateTime dateTime) {
  final jalali = Jalali.fromDateTime(dateTime);
  final y = jalali.year.toString().padLeft(4, '0');
  final m = jalali.month.toString().padLeft(2, '0');
  final d = jalali.day.toString().padLeft(2, '0');
  return '$y/$m/$d';
}

String formatJalaliDateTime(DateTime dateTime) {
  final h = dateTime.hour.toString().padLeft(2, '0');
  final min = dateTime.minute.toString().padLeft(2, '0');
  return '${formatJalaliDate(dateTime)} - $h:$min';
}

const List<String> _jalaliMonthNames = [
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];

const List<String> _jalaliWeekDayNames = [
  'شنبه',
  'یک‌شنبه',
  'دوشنبه',
  'سه‌شنبه',
  'چهارشنبه',
  'پنج‌شنبه',
  'جمعه',
];

/// تاریخ شمسی به‌صورت خوانا با نام روز هفته و ماه، مثل «شنبه، ۵ شهریور».
String formatJalaliLong(DateTime dateTime) {
  final jalali = Jalali.fromDateTime(dateTime);
  final weekDay = _jalaliWeekDayNames[jalali.weekDay - 1];
  final month = _jalaliMonthNames[jalali.month - 1];
  return '$weekDay، ${jalali.day} $month';
}

/// ارقام لاتین داخل متن را به ارقام فارسی تبدیل می‌کند.
String _persianize(String text) {
  const digits = '۰۱۲۳۴۵۶۷۸۹';
  return text.replaceAllMapped(
    RegExp('[0-9]'),
    (match) => digits[int.parse(match[0]!)],
  );
}

/// فاصله تا یک زمان آینده به‌صورت خوانا، مثل «۱۵ دقیقه دیگر»، «۳ ساعت دیگر»،
/// «فردا ۰۹:۳۰» یا «۴ روز دیگر»؛ برای زمان گذشته «گذشته».
String relativeFutureLabel(DateTime target, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = target.difference(reference);
  if (diff.isNegative) return 'گذشته';
  if (diff.inMinutes < 1) return 'همین حالا';
  if (diff.inMinutes < 60) return _persianize('${diff.inMinutes} دقیقه دیگر');
  // UTC: فاصله روزها با تغییر ساعت تابستانی اشتباه نمی‌شود.
  final dayDiff = DateTime.utc(target.year, target.month, target.day)
      .difference(DateTime.utc(reference.year, reference.month, reference.day))
      .inDays;
  if (dayDiff == 0) return _persianize('${diff.inHours} ساعت دیگر');
  if (dayDiff == 1) {
    final hh = target.hour.toString().padLeft(2, '0');
    final mm = target.minute.toString().padLeft(2, '0');
    return _persianize('فردا $hh:$mm');
  }
  return _persianize('$dayDiff روز دیگر');
}
