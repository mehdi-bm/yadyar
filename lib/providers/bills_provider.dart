import 'package:flutter/foundation.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../models/subscription.dart';
import '../models/subscription_payment.dart';
import '../repositories/subscription_repository.dart';

class MonthlyExpense {
  const MonthlyExpense({required this.label, required this.total});

  final String label;
  final double total;
}

class BillsProvider extends ChangeNotifier {
  BillsProvider({SubscriptionRepository? subscriptionRepository})
    : _subscriptionRepository = subscriptionRepository ?? SubscriptionRepository();

  final SubscriptionRepository _subscriptionRepository;

  List<Subscription> _subscriptions = [];
  List<SubscriptionPayment> _payments = [];
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  /// مرتب بر اساس نزدیک‌ترین سررسید (ترتیب پیش‌فرض از خود Repository).
  List<Subscription> get subscriptions => List.unmodifiable(_subscriptions);

  /// مجموع هزینه پرداخت‌شده در هر یک از ۶ ماه شمسی اخیر (شامل ماه جاری).
  List<MonthlyExpense> get monthlyExpenses {
    final currentMonth = Jalali.fromDateTime(DateTime.now());
    final months = List.generate(6, (i) => _addJalaliMonths(currentMonth, i - 5));

    return months.map((month) {
      final total = _payments
          .where((payment) {
            final paidMonth = Jalali.fromDateTime(payment.paidDate);
            return paidMonth.year == month.year && paidMonth.month == month.month;
          })
          .fold<double>(0, (sum, payment) => sum + payment.amount);
      return MonthlyExpense(label: month.formatter.mN, total: total);
    }).toList();
  }

  Jalali _addJalaliMonths(Jalali date, int delta) {
    var year = date.year;
    var month = date.month + delta;
    while (month < 1) {
      month += 12;
      year -= 1;
    }
    while (month > 12) {
      month -= 12;
      year += 1;
    }
    return Jalali(year, month, 1);
  }

  Future<void> loadSubscriptions() async {
    _isLoading = true;
    notifyListeners();
    _subscriptions = await _subscriptionRepository.getAll();
    _payments = await _subscriptionRepository.getAllPayments();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addSubscription(Subscription subscription) async {
    await _subscriptionRepository.insert(subscription);
    await loadSubscriptions();
  }

  Future<void> updateSubscription(Subscription subscription) async {
    await _subscriptionRepository.update(subscription);
    await loadSubscriptions();
  }

  Future<void> deleteSubscription(int id) async {
    await _subscriptionRepository.delete(id);
    await loadSubscriptions();
  }

  /// ثبت پرداخت جدید در تاریخچه و به‌روزرسانی وضعیت. اگر تکرارشونده باشد،
  /// سررسید به چرخه بعد منتقل و isPaid برای دوره جدید false می‌شود؛ اگر
  /// یک‌بار مصرف باشد، برای همیشه «پرداخت‌شده» می‌ماند.
  Future<void> markAsPaid(Subscription subscription) async {
    final now = DateTime.now();
    await _subscriptionRepository.insertPayment(
      SubscriptionPayment(subscriptionId: subscription.id!, paidDate: now, amount: subscription.amount),
    );

    final isRecurring = subscription.repeatType != SubscriptionRepeatType.once;
    final updated = subscription.copyWith(
      lastPaidDate: now,
      isPaid: !isRecurring,
      dueDate: isRecurring
          ? _nextDueDate(subscription.dueDate, subscription.repeatType)
          : subscription.dueDate,
    );
    await _subscriptionRepository.update(updated);
    await loadSubscriptions();
  }

  DateTime _nextDueDate(DateTime current, SubscriptionRepeatType repeatType) {
    switch (repeatType) {
      case SubscriptionRepeatType.monthly:
        return DateTime(current.year, current.month + 1, current.day, current.hour, current.minute);
      case SubscriptionRepeatType.yearly:
        return DateTime(current.year + 1, current.month, current.day, current.hour, current.minute);
      case SubscriptionRepeatType.once:
        return current;
    }
  }

  Future<List<SubscriptionPayment>> getPaymentHistory(int subscriptionId) {
    return _subscriptionRepository.getPaymentsBySubscriptionId(subscriptionId);
  }
}
