import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yadyar_app/database/database_helper.dart';
import 'package:yadyar_app/models/note.dart';
import 'package:yadyar_app/models/reminder.dart';
import 'package:yadyar_app/models/shopping_item.dart';
import 'package:yadyar_app/models/shopping_list.dart';
import 'package:yadyar_app/models/subscription.dart';
import 'package:yadyar_app/providers/bills_provider.dart';
import 'package:yadyar_app/providers/notes_provider.dart';
import 'package:yadyar_app/providers/shopping_provider.dart';
import 'package:yadyar_app/repositories/note_repository.dart';
import 'package:yadyar_app/repositories/reminder_repository.dart';
import 'package:yadyar_app/repositories/shopping_list_repository.dart';
import 'package:yadyar_app/repositories/subscription_repository.dart';
import 'package:yadyar_app/screens/bills/bills_list_screen.dart';
import 'package:yadyar_app/screens/dashboard_screen.dart';
import 'package:yadyar_app/screens/notes/notes_list_screen.dart';
import 'package:yadyar_app/screens/shopping/shopping_lists_screen.dart';
import 'package:yadyar_app/theme/app_theme.dart';

/// سه سایز صفحه که در بازار اندروید رایج‌اند: یک گوشی کوچک عمودی، یک تبلت
/// بزرگ افقی، و یک گوشی در حالت افقی (ارتفاع خیلی کم) — overflow معمولاً در
/// یکی از این انتهاها خودش را نشان می‌دهد.
const _smallPhone = Size(320, 568);
const _largeTablet = Size(1024, 768);
const _phoneLandscape = Size(780, 360);

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

  Future<void> seedRealisticData() async {
    final noteRepo = NoteRepository(databaseHelper: databaseHelper);
    final reminderRepo = ReminderRepository(databaseHelper: databaseHelper);
    final subscriptionRepo = SubscriptionRepository(
      databaseHelper: databaseHelper,
    );
    final shoppingRepo = ShoppingListRepository(databaseHelper: databaseHelper);
    final now = DateTime.now();

    final noteId = await noteRepo.insert(
      Note(
        title: 'یک عنوان یادداشت نسبتاً طولانی برای بررسی سرریز متن در کارت‌ها',
        content: 'متن نمونه برای بررسی چیدمان در اندازه‌های مختلف صفحه‌نمایش.',
        tag: 'کار',
        isPinned: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await reminderRepo.insert(
      Reminder(
        noteId: noteId,
        title: 'یادآوری تست',
        dateTime: now.add(const Duration(hours: 2)),
      ),
    );

    await subscriptionRepo.insert(
      Subscription(
        title: 'یک اشتراک نرم‌افزاری با نام نسبتاً طولانی برای تست چیدمان',
        amount: 1250000,
        dueDate: now.subtract(const Duration(days: 2)),
        repeatType: SubscriptionRepeatType.monthly,
        category: 'اشتراک نرم‌افزار',
        reminderDaysBefore: 3,
      ),
    );

    final listId = await shoppingRepo.insert(
      ShoppingList(
        name: 'خرید هفتگی خانواده با یک نام نسبتاً بلند',
        createdAt: now,
      ),
    );
    await shoppingRepo.insertItem(
      ShoppingItem(
        shoppingListId: listId,
        name: 'یک نام آیتم نسبتاً طولانی برای بررسی سرریز',
        category: 'میوه و سبزیجات',
        quantity: '۲ کیلوگرم',
      ),
    );
  }

  Future<void> pumpAtSize(
    WidgetTester tester,
    Size size,
    Widget child, {
    List<SingleChildWidget>? extraProviders,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ...?extraProviders,
        ],
        child: MaterialApp(theme: AppTheme.light, home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  group(
    'at ${_phoneLandscape.width.toInt()}x${_phoneLandscape.height.toInt()} (phone landscape, empty state)',
    () {
      testWidgets('NotesListScreen empty state renders without overflow', (
        tester,
      ) async {
        await pumpAtSize(
          tester,
          _phoneLandscape,
          const NotesListScreen(),
          extraProviders: [
            ChangeNotifierProvider(
              create: (_) => NotesProvider(
                noteRepository: NoteRepository(databaseHelper: databaseHelper),
                reminderRepository: ReminderRepository(
                  databaseHelper: databaseHelper,
                ),
              )..loadNotes(),
            ),
          ],
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('BillsListScreen empty state renders without overflow', (
        tester,
      ) async {
        await pumpAtSize(
          tester,
          _phoneLandscape,
          const BillsListScreen(),
          extraProviders: [
            ChangeNotifierProvider(
              create: (_) => BillsProvider(
                subscriptionRepository: SubscriptionRepository(
                  databaseHelper: databaseHelper,
                ),
              )..loadSubscriptions(),
            ),
          ],
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('ShoppingListsScreen empty state renders without overflow', (
        tester,
      ) async {
        await pumpAtSize(
          tester,
          _phoneLandscape,
          const ShoppingListsScreen(),
          extraProviders: [
            ChangeNotifierProvider(
              create: (_) => ShoppingProvider(
                repository: ShoppingListRepository(
                  databaseHelper: databaseHelper,
                ),
              )..loadLists(),
            ),
          ],
        );
        expect(tester.takeException(), isNull);
      });
    },
  );

  for (final size in [_smallPhone, _largeTablet]) {
    group('at ${size.width.toInt()}x${size.height.toInt()}', () {
      testWidgets('NotesListScreen renders without overflow', (tester) async {
        await seedRealisticData();
        await pumpAtSize(
          tester,
          size,
          const NotesListScreen(),
          extraProviders: [
            ChangeNotifierProvider(
              create: (_) => NotesProvider(
                noteRepository: NoteRepository(databaseHelper: databaseHelper),
                reminderRepository: ReminderRepository(
                  databaseHelper: databaseHelper,
                ),
              )..loadNotes(),
            ),
          ],
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('BillsListScreen renders without overflow', (tester) async {
        await seedRealisticData();
        await pumpAtSize(
          tester,
          size,
          const BillsListScreen(),
          extraProviders: [
            ChangeNotifierProvider(
              create: (_) => BillsProvider(
                subscriptionRepository: SubscriptionRepository(
                  databaseHelper: databaseHelper,
                ),
              )..loadSubscriptions(),
            ),
          ],
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('ShoppingListsScreen renders without overflow', (
        tester,
      ) async {
        await seedRealisticData();
        await pumpAtSize(
          tester,
          size,
          const ShoppingListsScreen(),
          extraProviders: [
            ChangeNotifierProvider(
              create: (_) => ShoppingProvider(
                repository: ShoppingListRepository(
                  databaseHelper: databaseHelper,
                ),
              )..loadLists(),
            ),
          ],
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('DashboardScreen renders without overflow', (tester) async {
        await seedRealisticData();
        await pumpAtSize(
          tester,
          size,
          DashboardScreen(
            onNavigateToTab: (_) {},
            noteRepository: NoteRepository(databaseHelper: databaseHelper),
            reminderRepository: ReminderRepository(
              databaseHelper: databaseHelper,
            ),
            subscriptionRepository: SubscriptionRepository(
              databaseHelper: databaseHelper,
            ),
            shoppingRepository: ShoppingListRepository(
              databaseHelper: databaseHelper,
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    });
  }
}
