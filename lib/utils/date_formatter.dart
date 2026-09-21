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
