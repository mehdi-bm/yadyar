import 'package:flutter/material.dart';

import '../../../constants/app_constants.dart';
import '../../../models/subscription.dart';

enum BillStatus { paid, dueSoon, overdue }

BillStatus billStatusOf(Subscription subscription) {
  if (subscription.isPaid) return BillStatus.paid;

  final today = DateTime.now();
  final todayOnly = DateTime(today.year, today.month, today.day);
  final dueDateOnly = DateTime(
    subscription.dueDate.year,
    subscription.dueDate.month,
    subscription.dueDate.day,
  );

  return dueDateOnly.isBefore(todayOnly) ? BillStatus.overdue : BillStatus.dueSoon;
}

String billStatusLabel(BillStatus status) {
  switch (status) {
    case BillStatus.paid:
      return 'پرداخت‌شده';
    case BillStatus.dueSoon:
      return 'سررسید نزدیک';
    case BillStatus.overdue:
      return 'عقب‌افتاده';
  }
}

Color billStatusColor(BillStatus status) {
  switch (status) {
    case BillStatus.paid:
      return AppConstants.successColor;
    case BillStatus.dueSoon:
      return AppConstants.secondaryColor;
    case BillStatus.overdue:
      return AppConstants.errorColor;
  }
}
