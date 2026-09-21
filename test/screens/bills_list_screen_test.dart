import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yadyar_app/database/database_helper.dart';
import 'package:yadyar_app/models/subscription.dart';
import 'package:yadyar_app/providers/bills_provider.dart';
import 'package:yadyar_app/repositories/subscription_repository.dart';
import 'package:yadyar_app/screens/bills/bills_list_screen.dart';
import 'package:yadyar_app/screens/bills/widgets/bill_status.dart';
import 'package:yadyar_app/theme/app_theme.dart';
import 'package:yadyar_app/utils/currency_formatter.dart';

void main() {
  setUpAll(() {
    // نسخه بدون ایزوله: در تست ویجت با pumpAndSettle، ارتباط مبتنی بر ایزوله
    // sqflite_common_ffi هرگز پاسخ نمی‌گیرد (zone تست fake-async است).
    databaseFactory = databaseFactoryFfiNoIsolate;
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

  Widget buildApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      // AppTheme.light حاوی افزونه AppStatusColors است که billStatusColor به آن
      // نیاز دارد؛ بدون آن context.statusColors با null-check شکست می‌خورد.
      child: MaterialApp(theme: AppTheme.light, home: const BillsListScreen()),
    );
  }

  testWidgets('shows empty state when there are no subscriptions', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('هنوز اشتراک یا قبضی ثبت نشده'), findsOneWidget);
  });

  testWidgets('marking a one-time subscription as paid updates its status', (
    tester,
  ) async {
    await repository.insert(
      Subscription(
        title: 'خرید یک‌باره',
        amount: 200000,
        dueDate: DateTime.now().add(const Duration(days: 5)),
        repeatType: SubscriptionRepeatType.once,
        category: 'سایر',
      ),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text(billStatusLabel(BillStatus.dueSoon)), findsOneWidget);

    await tester.tap(find.text('پرداخت‌شده'));
    await tester.pumpAndSettle();

    expect(find.text(billStatusLabel(BillStatus.paid)), findsOneWidget);
    expect(
      find.text('پرداخت‌شده'),
      findsOneWidget,
    ); // فقط برچسب وضعیت می‌ماند، دکمه پرداخت دیگر نیست
  });

  testWidgets(
    'amount field groups digits with thousand separators while typing',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('افزودن اشتراک/قبض'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'عنوان'),
        'اینترنت خانه',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'مبلغ (تومان)'),
        '1250000',
      );
      await tester.pump();

      expect(find.text(formatAmountInput(1250000)), findsOneWidget);

      await tester.tap(find.byTooltip('ذخیره'));
      await tester.pumpAndSettle();

      expect(find.textContaining(formatTooman(1250000)), findsOneWidget);
    },
  );

  testWidgets(
    'limited repeat count shows remaining periods and decrements after payment',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('افزودن اشتراک/قبض'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'عنوان'),
        'قسط وام',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'مبلغ (تومان)'),
        '2000000',
      );
      // نوع تکرار پیش‌فرض «ماهانه» است؛ گزینه «تعداد مشخص» را انتخاب می‌کنیم.
      await tester.tap(find.text('تعداد مشخص'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'تعداد دفعات باقی‌مانده'),
        '3',
      );

      await tester.tap(find.byTooltip('ذخیره'));
      await tester.pumpAndSettle();

      expect(find.text('3 ماه مانده'), findsOneWidget);

      await tester.tap(find.text('پرداخت‌شده'));
      await tester.pumpAndSettle();

      expect(find.text('2 ماه مانده'), findsOneWidget);
    },
  );
}
