import 'package:flutter/foundation.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../models/subscription.dart';
import '../models/subscription_payment.dart';
import '../repositories/subscription_repository.dart';
import '../screens/bills/widgets/bill_status.dart';
import '../services/notification_service.dart';

class MonthlyExpense {
  const MonthlyExpense({
    required this.label,
    required this.total,
    this.isCurrent = false,
  });

  final String label;
  final double total;

  /// ماه جاری (برای برجسته‌کردن در نمودار).
  final bool isCurrent;
}

/// سهم هر دسته از پرداخت‌های بازه اخیر (برای نمودار دایره‌ای).
class CategoryExpense {
  const CategoryExpense({required this.category, required this.total});

  final String category;
  final double total;
}

/// خلاصه مالی بخش قبض‌ها برای کارت بالای صفحه و داشبورد.
class BillsSummary {
  const BillsSummary({
    required this.dueThisMonth,
    required this.paidThisMonth,
    required this.monthlyCommitment,
    required this.overdueCount,
    required this.dueSoonCount,
  });

  /// جمع قبض‌های پرداخت‌نشده‌ای که سررسیدشان تا پایان ماه شمسی جاری است
  /// (شامل عقب‌افتاده‌ها).
  final double dueThisMonth;

  /// جمع پرداخت‌های ثبت‌شده در ماه شمسی جاری.
  final double paidThisMonth;

  /// معادل ماهانه همه تعهدهای تکرارشونده فعال (ماهانه + سالانه÷۱۲).
  final double monthlyCommitment;
  final int overdueCount;

  /// قبض‌های امروز یا حداکثر [dueSoonDays] روز آینده.
  final int dueSoonCount;
}

/// فیلترهای لیست قبض‌ها.
enum BillFilter { all, overdue, dueSoon, upcoming, finished }

const Map<BillFilter, String> billFilterLabels = {
  BillFilter.all: 'همه',
  BillFilter.overdue: 'عقب‌افتاده',
  BillFilter.dueSoon: 'این هفته',
  BillFilter.upcoming: 'آینده',
  BillFilter.finished: 'تمام‌شده',
};

/// اطلاعات لازم برای بازگرداندن یک پرداخت (دکمه «بازگردانی»).
class PaymentUndo {
  const PaymentUndo({required this.before, required this.paymentId});

  final Subscription before;
  final int paymentId;
}

class BillsProvider extends ChangeNotifier {
  BillsProvider({
    SubscriptionRepository? subscriptionRepository,
    NotificationService? notificationService,
  }) : _subscriptionRepository =
           subscriptionRepository ?? SubscriptionRepository(),
       _notificationService =
           notificationService ?? NotificationService.instance;

  final SubscriptionRepository _subscriptionRepository;
  final NotificationService _notificationService;

  List<Subscription> _subscriptions = [];
  List<SubscriptionPayment> _payments = [];
  bool _isLoading = false;
  BillFilter _filter = BillFilter.all;
  String _searchQuery = '';

  bool get isLoading => _isLoading;
  BillFilter get filter => _filter;
  String get searchQuery => _searchQuery;

  /// مرتب بر اساس نزدیک‌ترین سررسید (ترتیب پیش‌فرض از خود Repository).
  List<Subscription> get subscriptions => List.unmodifiable(_subscriptions);

  /// لیست نمایشی: فیلتر و جستجو اعمال‌شده؛ عقب‌افتاده‌ها اول، بعد به ترتیب
  /// سررسید، و تمام‌شده‌ها در انتها.
  List<Subscription> get visibleSubscriptions {
    final query = _searchQuery.trim().toLowerCase();
    final result = _subscriptions.where((subscription) {
      if (!_matchesFilter(subscription, _filter)) return false;
      if (query.isEmpty) return true;
      return subscription.title.toLowerCase().contains(query) ||
          subscription.category.toLowerCase().contains(query) ||
          (subscription.billIdentifier?.contains(query) ?? false) ||
          (subscription.note?.toLowerCase().contains(query) ?? false);
    }).toList();
    result.sort((a, b) {
      if (a.isPaid != b.isPaid) return a.isPaid ? 1 : -1;
      return a.dueDate.compareTo(b.dueDate);
    });
    return result;
  }

  int countFor(BillFilter filter) =>
      _subscriptions.where((s) => _matchesFilter(s, filter)).length;

  bool _matchesFilter(Subscription subscription, BillFilter filter) {
    final status = billStatusOf(subscription);
    switch (filter) {
      case BillFilter.all:
        return true;
      case BillFilter.overdue:
        return status == BillStatus.overdue;
      case BillFilter.dueSoon:
        return status == BillStatus.dueToday || status == BillStatus.dueSoon;
      case BillFilter.upcoming:
        return status == BillStatus.upcoming;
      case BillFilter.finished:
        return status == BillStatus.paid;
    }
  }

  void setFilter(BillFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (query == _searchQuery) return;
    _searchQuery = query;
    notifyListeners();
  }

  BillsSummary get summary {
    final now = DateTime.now();
    final currentMonth = Jalali.fromDateTime(now);
    final nextMonthStart = _addJalaliMonths(currentMonth, 1).toDateTime();

    var dueThisMonth = 0.0;
    var monthlyCommitment = 0.0;
    var overdue = 0;
    var dueSoon = 0;
    for (final subscription in _subscriptions) {
      final status = billStatusOf(subscription, now: now);
      if (status == BillStatus.overdue) overdue++;
      if (status == BillStatus.dueToday || status == BillStatus.dueSoon) {
        dueSoon++;
      }
      if (!subscription.isPaid &&
          subscription.dueDate.isBefore(nextMonthStart)) {
        dueThisMonth += subscription.amount;
      }
      if (!subscription.isPaid) {
        switch (subscription.repeatType) {
          case SubscriptionRepeatType.monthly:
            monthlyCommitment += subscription.amount;
          case SubscriptionRepeatType.yearly:
            monthlyCommitment += subscription.amount / 12;
          case SubscriptionRepeatType.once:
            break;
        }
      }
    }
    final paidThisMonth = _payments
        .where((payment) => _sameJalaliMonth(payment.paidDate, currentMonth))
        .fold<double>(0, (sum, payment) => sum + payment.amount);

    return BillsSummary(
      dueThisMonth: dueThisMonth,
      paidThisMonth: paidThisMonth,
      monthlyCommitment: monthlyCommitment,
      overdueCount: overdue,
      dueSoonCount: dueSoon,
    );
  }

  /// مجموع هزینه پرداخت‌شده در هر یک از ۶ ماه شمسی اخیر (شامل ماه جاری).
  List<MonthlyExpense> get monthlyExpenses {
    final currentMonth = Jalali.fromDateTime(DateTime.now());
    final months = List.generate(
      6,
      (i) => _addJalaliMonths(currentMonth, i - 5),
    );

    return [
      for (var i = 0; i < months.length; i++)
        MonthlyExpense(
          label: months[i].formatter.mN,
          total: _payments
              .where((payment) => _sameJalaliMonth(payment.paidDate, months[i]))
              .fold<double>(0, (sum, payment) => sum + payment.amount),
          isCurrent: i == months.length - 1,
        ),
    ];
  }

  /// سهم هر دسته از پرداخت‌های ۶ ماه اخیر، بزرگ‌ترین اول.
  List<CategoryExpense> get categoryExpenses {
    final start = _addJalaliMonths(
      Jalali.fromDateTime(DateTime.now()),
      -5,
    ).toDateTime();
    final categoryById = {
      for (final subscription in _subscriptions)
        subscription.id: subscription.category,
    };
    final totals = <String, double>{};
    for (final payment in _payments) {
      if (payment.paidDate.isBefore(start)) continue;
      final category = categoryById[payment.subscriptionId] ?? 'سایر';
      totals[category] = (totals[category] ?? 0) + payment.amount;
    }
    final result = [
      for (final entry in totals.entries)
        CategoryExpense(category: entry.key, total: entry.value),
    ]..sort((a, b) => b.total.compareTo(a.total));
    return result;
  }

  bool _sameJalaliMonth(DateTime date, Jalali month) {
    final jalali = Jalali.fromDateTime(date);
    return jalali.year == month.year && jalali.month == month.month;
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
    await _reload();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _reload() async {
    _subscriptions = await _subscriptionRepository.getAll();
    _payments = await _subscriptionRepository.getAllPayments();
    notifyListeners();
  }

  Future<void> addSubscription(Subscription subscription) async {
    final id = await _subscriptionRepository.insert(subscription);
    await _notificationService.scheduleSubscriptionReminder(
      subscription.copyWith(id: id),
    );
    await _reload();
  }

  Future<void> updateSubscription(Subscription subscription) async {
    await _subscriptionRepository.update(subscription);
    await _notificationService.scheduleSubscriptionReminder(subscription);
    await _reload();
  }

  Future<void> deleteSubscription(int id) async {
    await _notificationService.cancelReminder(id, isSubscription: true);
    await _subscriptionRepository.delete(id);
    await _reload();
  }

  /// ثبت پرداخت جدید در تاریخچه و به‌روزرسانی وضعیت. اگر تکرارشونده باشد،
  /// سررسید به چرخه بعد منتقل و isPaid برای دوره جدید false می‌شود؛ اگر
  /// یک‌بار مصرف باشد، برای همیشه «پرداخت‌شده» می‌ماند. اگر تعداد تکرار
  /// محدود بود (مثلاً قسط ۱۲ ماهه)، یکی از remainingOccurrences کم می‌شود
  /// و وقتی به صفر برسد، مثل یک اشتراک یک‌بار مصرف برای همیشه تمام می‌شود.
  ///
  /// [amount] و [paidDate] برای قبض‌های متغیر (مثل برق) یا ثبت پرداخت گذشته
  /// قابل تغییرند. اطلاعات لازم برای بازگرداندن همین پرداخت برگردانده می‌شود.
  Future<PaymentUndo> markAsPaid(
    Subscription subscription, {
    double? amount,
    DateTime? paidDate,
  }) async {
    final paidAt = paidDate ?? DateTime.now();
    final paymentId = await _subscriptionRepository.insertPayment(
      SubscriptionPayment(
        subscriptionId: subscription.id!,
        paidDate: paidAt,
        amount: amount ?? subscription.amount,
      ),
    );

    final wasRecurring = subscription.repeatType != SubscriptionRepeatType.once;
    var remaining = subscription.remainingOccurrences;
    if (wasRecurring && remaining != null) {
      remaining -= 1;
    }
    final isFinished = wasRecurring && remaining != null && remaining <= 0;
    final stillRecurring = wasRecurring && !isFinished;

    final updated = subscription.copyWith(
      lastPaidDate: paidAt,
      isPaid: !stillRecurring,
      dueDate: stillRecurring
          ? _nextDueDate(subscription.dueDate, subscription.repeatType)
          : subscription.dueDate,
      remainingOccurrences: remaining,
    );
    await _subscriptionRepository.update(updated);
    if (stillRecurring) {
      await _notificationService.scheduleSubscriptionReminder(updated);
    } else {
      await _notificationService.cancelReminder(
        subscription.id!,
        isSubscription: true,
      );
    }
    await _reload();
    return PaymentUndo(before: subscription, paymentId: paymentId);
  }

  /// بازگرداندن دقیق یک پرداخت: رکورد پرداخت حذف و قبض به وضعیت قبل از آن
  /// (سررسید، تعداد باقی‌مانده، آخرین پرداخت) برمی‌گردد.
  Future<void> undoPayment(PaymentUndo undo) async {
    await _subscriptionRepository.deletePayment(undo.paymentId);
    await _subscriptionRepository.update(undo.before);
    if (undo.before.isPaid) {
      await _notificationService.cancelReminder(
        undo.before.id!,
        isSubscription: true,
      );
    } else {
      await _notificationService.scheduleSubscriptionReminder(undo.before);
    }
    await _reload();
  }

  /// حذف یک رکورد اشتباه از تاریخچه (وضعیت/سررسید قبض تغییر نمی‌کند).
  Future<void> deletePayment(SubscriptionPayment payment) async {
    await _subscriptionRepository.deletePayment(payment.id!);
    await _reload();
  }

  DateTime _nextDueDate(DateTime current, SubscriptionRepeatType repeatType) {
    switch (repeatType) {
      case SubscriptionRepeatType.monthly:
        return DateTime(
          current.year,
          current.month + 1,
          current.day,
          current.hour,
          current.minute,
        );
      case SubscriptionRepeatType.yearly:
        return DateTime(
          current.year + 1,
          current.month,
          current.day,
          current.hour,
          current.minute,
        );
      case SubscriptionRepeatType.once:
        return current;
    }
  }

  Future<List<SubscriptionPayment>> getPaymentHistory(int subscriptionId) {
    return _subscriptionRepository.getPaymentsBySubscriptionId(subscriptionId);
  }
}
