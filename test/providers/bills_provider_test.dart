import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yadyar_app/database/database_helper.dart';
import 'package:yadyar_app/models/subscription.dart';
import 'package:yadyar_app/providers/bills_provider.dart';
import 'package:yadyar_app/repositories/subscription_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

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

  test('markAsPaid on a one-time subscription marks it paid and keeps the due date', () async {
    final dueDate = DateTime(2026, 8, 1);
    final id = await repository.insert(
      Subscription(
        title: 'خرید یک‌باره',
        amount: 200000,
        dueDate: dueDate,
        repeatType: SubscriptionRepeatType.once,
        category: 'سایر',
      ),
    );
    await provider.loadSubscriptions();
    final subscription = provider.subscriptions.firstWhere((s) => s.id == id);

    await provider.markAsPaid(subscription);

    final updated = (await repository.getById(id))!;
    expect(updated.isPaid, isTrue);
    expect(updated.dueDate, dueDate);
    expect(updated.lastPaidDate, isNotNull);

    final history = await provider.getPaymentHistory(id);
    expect(history, hasLength(1));
    expect(history.first.amount, 200000);
  });

  test(
    'markAsPaid on a monthly subscription advances the due date by one month and resets isPaid',
    () async {
      final dueDate = DateTime(2026, 1, 31);
      final id = await repository.insert(
        Subscription(
          title: 'اینترنت خانه',
          amount: 350000,
          dueDate: dueDate,
          repeatType: SubscriptionRepeatType.monthly,
          category: 'اینترنت',
        ),
      );
      await provider.loadSubscriptions();
      final subscription = provider.subscriptions.firstWhere((s) => s.id == id);

      await provider.markAsPaid(subscription);

      final updated = (await repository.getById(id))!;
      expect(updated.isPaid, isFalse);
      expect(updated.dueDate.isAfter(dueDate), isTrue);

      final history = await provider.getPaymentHistory(id);
      expect(history, hasLength(1));
    },
  );

  test('markAsPaid on a yearly subscription advances the due date by one year', () async {
    final dueDate = DateTime(2026, 3, 10);
    final id = await repository.insert(
      Subscription(
        title: 'بیمه خودرو',
        amount: 5000000,
        dueDate: dueDate,
        repeatType: SubscriptionRepeatType.yearly,
        category: 'بیمه',
      ),
    );
    await provider.loadSubscriptions();
    final subscription = provider.subscriptions.firstWhere((s) => s.id == id);

    await provider.markAsPaid(subscription);

    final updated = (await repository.getById(id))!;
    expect(updated.dueDate, DateTime(2027, 3, 10));
    expect(updated.isPaid, isFalse);
  });

  test('monthlyExpenses reflects a payment made in the current month', () async {
    final id = await repository.insert(
      Subscription(
        title: 'تست نمودار',
        amount: 100000,
        dueDate: DateTime.now(),
        repeatType: SubscriptionRepeatType.once,
        category: 'سایر',
      ),
    );
    await provider.loadSubscriptions();
    final subscription = provider.subscriptions.firstWhere((s) => s.id == id);

    await provider.markAsPaid(subscription);

    expect(provider.monthlyExpenses, hasLength(6));
    expect(provider.monthlyExpenses.last.total, 100000);
  });
}
