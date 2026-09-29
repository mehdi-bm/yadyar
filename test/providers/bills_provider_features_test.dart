import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yadyar_app/database/database_helper.dart';
import 'package:yadyar_app/models/subscription.dart';
import 'package:yadyar_app/providers/bills_provider.dart';
import 'package:yadyar_app/repositories/subscription_repository.dart';
import 'package:yadyar_app/screens/bills/widgets/bill_status.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('bill status', () {
    final now = DateTime(2026, 9, 29, 10);
    Subscription dueIn(int days, {bool paid = false}) => Subscription(
      title: 'قبض',
      amount: 1000,
      dueDate: DateTime(2026, 9, 29, 20).add(Duration(days: days)),
      category: 'برق',
      isPaid: paid,
    );

    test('classifies by days until due', () {
      expect(billStatusOf(dueIn(-2), now: now), BillStatus.overdue);
      expect(billStatusOf(dueIn(0), now: now), BillStatus.dueToday);
      expect(billStatusOf(dueIn(7), now: now), BillStatus.dueSoon);
      expect(billStatusOf(dueIn(8), now: now), BillStatus.upcoming);
      expect(billStatusOf(dueIn(-5, paid: true), now: now), BillStatus.paid);
    });

    test('countdown labels', () {
      expect(dueCountdownLabel(dueIn(0), now: now), 'امروز');
      expect(dueCountdownLabel(dueIn(1), now: now), 'فردا');
      expect(dueCountdownLabel(dueIn(-1), now: now), 'دیروز');
      expect(dueCountdownLabel(dueIn(5), now: now), '۵ روز مانده');
      expect(dueCountdownLabel(dueIn(-3), now: now), '۳ روز گذشته');
      expect(dueCountdownLabel(dueIn(3, paid: true), now: now), isNull);
    });
  });

  group('BillsProvider features', () {
    late DatabaseHelper databaseHelper;
    late SubscriptionRepository repository;
    late BillsProvider provider;

    setUp(() {
      databaseHelper = DatabaseHelper(path: inMemoryDatabasePath);
      repository = SubscriptionRepository(databaseHelper: databaseHelper);
      provider = BillsProvider(subscriptionRepository: repository);
    });

    tearDown(() async {
      await databaseHelper.close();
    });

    Future<Subscription> add(Subscription subscription) async {
      final id = await repository.insert(subscription);
      await provider.loadSubscriptions();
      return provider.subscriptions.firstWhere((s) => s.id == id);
    }

    final today = DateTime.now();

    test('filters count and narrow the list; overdue sorts first', () async {
      await add(
        Subscription(
          title: 'آینده',
          amount: 1000,
          dueDate: today.add(const Duration(days: 20)),
          category: 'آب',
        ),
      );
      await add(
        Subscription(
          title: 'این هفته',
          amount: 1000,
          dueDate: today.add(const Duration(days: 3)),
          category: 'گاز',
        ),
      );
      await add(
        Subscription(
          title: 'عقب‌افتاده',
          amount: 1000,
          dueDate: today.subtract(const Duration(days: 4)),
          category: 'برق',
        ),
      );
      await add(
        Subscription(
          title: 'تمام‌شده',
          amount: 1000,
          dueDate: today.subtract(const Duration(days: 40)),
          repeatType: SubscriptionRepeatType.once,
          category: 'سایر',
          isPaid: true,
        ),
      );

      expect(provider.countFor(BillFilter.all), 4);
      expect(provider.countFor(BillFilter.overdue), 1);
      expect(provider.countFor(BillFilter.dueSoon), 1);
      expect(provider.countFor(BillFilter.upcoming), 1);
      expect(provider.countFor(BillFilter.finished), 1);
      expect(provider.visibleSubscriptions.map((s) => s.title), [
        'عقب‌افتاده',
        'این هفته',
        'آینده',
        'تمام‌شده',
      ]);

      provider.setFilter(BillFilter.dueSoon);
      expect(provider.visibleSubscriptions.single.title, 'این هفته');
    });

    test('search matches title, category and bill identifier', () async {
      await add(
        Subscription(
          title: 'برق خانه',
          amount: 1000,
          dueDate: today,
          category: 'برق',
          billIdentifier: '1234567890',
        ),
      );
      await add(
        Subscription(
          title: 'اینترنت',
          amount: 1000,
          dueDate: today,
          category: 'اینترنت',
        ),
      );

      provider.setSearchQuery('4567');
      expect(provider.visibleSubscriptions.single.title, 'برق خانه');
      provider.setSearchQuery('اینترنت');
      expect(provider.visibleSubscriptions.single.title, 'اینترنت');
    });

    test('bill identifier and note are stored', () async {
      final bill = await add(
        Subscription(
          title: 'گاز',
          amount: 1000,
          dueDate: today,
          category: 'گاز',
          billIdentifier: '987',
          note: 'اشتراک ۵۵۵',
        ),
      );
      expect(bill.billIdentifier, '987');
      expect(bill.note, 'اشتراک ۵۵۵');
    });

    test('custom amount and date are recorded for variable bills', () async {
      final bill = await add(
        Subscription(
          title: 'برق',
          amount: 300000,
          dueDate: today.add(const Duration(days: 2)),
          category: 'برق',
        ),
      );
      final paidOn = today.subtract(const Duration(days: 1));

      await provider.markAsPaid(bill, amount: 412000, paidDate: paidOn);

      final history = await provider.getPaymentHistory(bill.id!);
      expect(history.single.amount, 412000);
      expect(history.single.paidDate, paidOn);
      final updated = (await repository.getById(bill.id!))!;
      expect(updated.lastPaidDate, paidOn);
    });

    test(
      'undoPayment restores the bill exactly and removes the record',
      () async {
        final bill = await add(
          Subscription(
            title: 'قسط',
            amount: 2000000,
            dueDate: DateTime(2026, 10, 5, 9),
            category: 'سایر',
            remainingOccurrences: 1,
          ),
        );

        final undo = await provider.markAsPaid(bill);
        final afterPay = (await repository.getById(bill.id!))!;
        expect(afterPay.isPaid, isTrue);
        expect(afterPay.remainingOccurrences, 0);

        await provider.undoPayment(undo);

        final restored = (await repository.getById(bill.id!))!;
        expect(restored.isPaid, isFalse);
        expect(restored.remainingOccurrences, 1);
        expect(restored.dueDate, DateTime(2026, 10, 5, 9));
        expect(restored.lastPaidDate, isNull);
        expect(await provider.getPaymentHistory(bill.id!), isEmpty);
      },
    );

    test('deletePayment removes only the history record', () async {
      final bill = await add(
        Subscription(
          title: 'اینترنت',
          amount: 500000,
          dueDate: DateTime(2026, 10, 5, 9),
          category: 'اینترنت',
        ),
      );
      await provider.markAsPaid(bill);
      final payment = (await provider.getPaymentHistory(bill.id!)).single;

      await provider.deletePayment(payment);

      expect(await provider.getPaymentHistory(bill.id!), isEmpty);
      final updated = (await repository.getById(bill.id!))!;
      expect(updated.dueDate, DateTime(2026, 11, 5, 9));
    });

    test('summary: due this month, paid this month and commitment', () async {
      await add(
        Subscription(
          title: 'عقب‌افتاده',
          amount: 100000,
          dueDate: today.subtract(const Duration(days: 2)),
          category: 'برق',
        ),
      );
      final yearly = await add(
        Subscription(
          title: 'بیمه سالانه',
          amount: 1200000,
          dueDate: today.add(const Duration(days: 200)),
          repeatType: SubscriptionRepeatType.yearly,
          category: 'بیمه',
        ),
      );
      await provider.markAsPaid(yearly, amount: 1200000);

      final summary = provider.summary;
      expect(summary.dueThisMonth, 100000);
      expect(summary.paidThisMonth, 1200000);
      // ماهانه ۱۰۰٬۰۰۰ + سالانه ۱٬۲۰۰٬۰۰۰ ÷ ۱۲
      expect(summary.monthlyCommitment, 200000);
      expect(summary.overdueCount, 1);
    });

    test('categoryExpenses groups recent payments by category', () async {
      final power = await add(
        Subscription(
          title: 'برق',
          amount: 300000,
          dueDate: today,
          category: 'برق',
        ),
      );
      final net = await add(
        Subscription(
          title: 'اینترنت',
          amount: 100000,
          dueDate: today,
          category: 'اینترنت',
        ),
      );
      await provider.markAsPaid(power);
      await provider.markAsPaid(net);
      await provider.markAsPaid(
        provider.subscriptions.firstWhere((s) => s.id == net.id),
      );

      final categories = provider.categoryExpenses;
      expect(categories.map((c) => c.category), ['برق', 'اینترنت']);
      expect(categories.map((c) => c.total), [300000, 200000]);
      expect(provider.monthlyExpenses.last.isCurrent, isTrue);
    });
  });
}
