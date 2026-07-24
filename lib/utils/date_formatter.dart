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
