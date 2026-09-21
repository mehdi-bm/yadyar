import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yadyar_app/database/database_helper.dart';
import 'package:yadyar_app/models/note.dart';
import 'package:yadyar_app/models/reminder.dart';
import 'package:yadyar_app/models/shopping_item.dart';
import 'package:yadyar_app/models/shopping_list.dart';
import 'package:yadyar_app/models/subscription.dart';
import 'package:yadyar_app/repositories/note_repository.dart';
import 'package:yadyar_app/repositories/reminder_repository.dart';
import 'package:yadyar_app/repositories/shopping_list_repository.dart';
import 'package:yadyar_app/repositories/subscription_repository.dart';
import 'package:yadyar_app/screens/dashboard_screen.dart';
import 'package:yadyar_app/screens/support/support_screen.dart';
import 'package:yadyar_app/theme/app_theme.dart';

void main() {
  setUpAll(() {
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late DatabaseHelper databaseHelper;

  setUp(() {
    databaseHelper = DatabaseHelper(path: inMemoryDatabasePath);
  });

  tearDown(() async {
    await databaseHelper.close();
  });

  testWidgets(
    'dashboard reflects real reminders, overdue bills and shopping lists',
    (tester) async {
      final noteRepo = NoteRepository(databaseHelper: databaseHelper);
      final reminderRepo = ReminderRepository(databaseHelper: databaseHelper);
      final subscriptionRepo = SubscriptionRepository(
        databaseHelper: databaseHelper,
      );
      final shoppingRepo = ShoppingListRepository(
        databaseHelper: databaseHelper,
      );
      final now = DateTime.now();

      final noteId = await noteRepo.insert(
        Note(
          title: 'یادداشت با یادآور امروز',
          content: '',
          tag: '',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await reminderRepo.insert(
        Reminder(noteId: noteId, title: 'یادآوری امروز', dateTime: now),
      );

      await subscriptionRepo.insert(
        Subscription(
          title: 'قبض برق خانه',
          amount: 500000,
          dueDate: now.subtract(const Duration(days: 3)),
          repeatType: SubscriptionRepeatType.monthly,
          category: 'برق',
        ),
      );

      final listId = await shoppingRepo.insert(
        ShoppingList(name: 'خرید هفتگی', createdAt: now),
      );
      await shoppingRepo.insertItem(
        ShoppingItem(
          shoppingListId: listId,
          name: 'نان',
          category: 'نان و غلات',
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeController(),
          child: MaterialApp(
            theme: AppTheme.light,
            home: DashboardScreen(
              onNavigateToTab: (_) {},
              noteRepository: noteRepo,
              reminderRepository: reminderRepo,
              subscriptionRepository: subscriptionRepo,
              shoppingRepository: shoppingRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('یادداشت با یادآور امروز'), findsOneWidget);
      expect(find.text('قبض برق خانه'), findsOneWidget);
      // خلاصه بالای صفحه: ۱ یادآور امروز، ۱ قبض معوق و ۱ آیتم خرید باقی‌مانده.
      expect(find.text('1'), findsNWidgets(3));

      // بخش خرید در انتهای صفحه است؛ محتوای بیشتر بالای آن (سرآمد
      // خوش‌آمدگویی، کارت‌های بزرگ‌تر) ممکن است آن را بیرون از ناحیه
      // realize پیش‌فرض sliver در ویوپورت تست قرار دهد، پس اسکرول می‌کنیم.
      await tester.dragUntilVisible(
        find.textContaining('خرید هفتگی'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      expect(find.textContaining('خرید هفتگی'), findsOneWidget);
    },
  );

  testWidgets('support entry point in the app bar opens the support screen', (
    tester,
  ) async {
    final noteRepo = NoteRepository(databaseHelper: databaseHelper);
    final reminderRepo = ReminderRepository(databaseHelper: databaseHelper);
    final subscriptionRepo = SubscriptionRepository(
      databaseHelper: databaseHelper,
    );
    final shoppingRepo = ShoppingListRepository(databaseHelper: databaseHelper);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeController(),
        child: MaterialApp(
          theme: AppTheme.light,
          home: DashboardScreen(
            onNavigateToTab: (_) {},
            noteRepository: noteRepo,
            reminderRepository: reminderRepo,
            subscriptionRepository: subscriptionRepo,
            shoppingRepository: shoppingRepo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.help_outline));
    await tester.pumpAndSettle();

    expect(find.byType(SupportScreen), findsOneWidget);
    expect(find.text('ارسال گزارش خطا'), findsWidgets);
    expect(find.text('درخواست تبلیغ'), findsWidgets);
  });
}
