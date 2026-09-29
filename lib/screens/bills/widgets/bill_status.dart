import 'package:flutter/material.dart';

import '../../../models/subscription.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/currency_formatter.dart';

/// وضعیت یک قبض نسبت به امروز. «نزدیک» یعنی حداکثر [dueSoonDays] روز مانده.
enum BillStatus { paid, overdue, dueToday, dueSoon, upcoming }

const int dueSoonDays = 7;

// UTC: فاصله روزها با تغییر ساعت تابستانی (روز ۲۳/۲۵ ساعته) اشتباه نمی‌شود.
DateTime _dateOnly(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

/// تعداد روز تا سررسید (منفی یعنی گذشته؛ صفر یعنی امروز).
int daysUntilDue(Subscription subscription, {DateTime? now}) => _dateOnly(
  subscription.dueDate,
).difference(_dateOnly(now ?? DateTime.now())).inDays;

BillStatus billStatusOf(Subscription subscription, {DateTime? now}) {
  if (subscription.isPaid) return BillStatus.paid;
  final days = daysUntilDue(subscription, now: now);
  if (days < 0) return BillStatus.overdue;
  if (days == 0) return BillStatus.dueToday;
  if (days <= dueSoonDays) return BillStatus.dueSoon;
  return BillStatus.upcoming;
}

String billStatusLabel(BillStatus status) {
  switch (status) {
    case BillStatus.paid:
      return 'پرداخت‌شده';
    case BillStatus.overdue:
      return 'عقب‌افتاده';
    case BillStatus.dueToday:
      return 'سررسید امروز';
    case BillStatus.dueSoon:
      return 'سررسید نزدیک';
    case BillStatus.upcoming:
      return 'در انتظار';
  }
}

Color billStatusColor(BuildContext context, BillStatus status) {
  switch (status) {
    case BillStatus.paid:
      return context.statusColors.success;
    case BillStatus.dueToday:
    case BillStatus.dueSoon:
      return context.statusColors.warning;
    case BillStatus.overdue:
      return context.statusColors.error;
    case BillStatus.upcoming:
      return Theme.of(context).colorScheme.primary;
  }
}

/// شمارش معکوس خوانا مثل «۳ روز مانده»، «امروز»، «۲ روز گذشته»؛ برای قبض
/// پرداخت‌شده (تمام‌شده) null.
String? dueCountdownLabel(Subscription subscription, {DateTime? now}) {
  if (subscription.isPaid) return null;
  final days = daysUntilDue(subscription, now: now);
  if (days == 0) return 'امروز';
  if (days == 1) return 'فردا';
  if (days == -1) return 'دیروز';
  if (days < 0) return '${formatNumber(-days)} روز گذشته';
  return '${formatNumber(days)} روز مانده';
}
