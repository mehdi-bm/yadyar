import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yadyar_app/database/database_helper.dart';
import 'package:yadyar_app/models/shopping_list.dart';
import 'package:yadyar_app/providers/shopping_provider.dart';
import 'package:yadyar_app/repositories/shopping_list_repository.dart';
import 'package:yadyar_app/screens/shopping/shopping_list_detail_screen.dart';
import 'package:yadyar_app/screens/shopping/shopping_lists_screen.dart';
import 'package:yadyar_app/theme/app_theme.dart';

void main() {
  setUpAll(() {
    // نسخه بدون ایزوله: در تست ویجت با pumpAndSettle، ارتباط مبتنی بر ایزوله
    // sqflite_common_ffi هرگز پاسخ نمی‌گیرد (zone تست fake-async است).
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late DatabaseHelper databaseHelper;
  late ShoppingListRepository repository;
  late ShoppingProvider provider;

  setUp(() {
    databaseHelper = DatabaseHelper(path: inMemoryDatabasePath);
    repository = ShoppingListRepository(databaseHelper: databaseHelper);
    provider = ShoppingProvider(repository: repository);
  });

  tearDown(() async {
    await databaseHelper.close();
  });

  Widget wrap(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('shows empty state when there are no shopping lists', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const ShoppingListsScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('هنوز لیست خریدی ثبت نشده'), findsOneWidget);
  });

  testWidgets(
    'checking an item moves it into the خریداری‌شده section with strikethrough',
    (tester) async {
      final listId = await repository.insert(
        ShoppingList(name: 'خرید هفتگی', createdAt: DateTime.now()),
      );

      await tester.pumpWidget(
        wrap(
          ShoppingListDetailScreen(
            shoppingList: ShoppingList(
              id: listId,
              name: 'خرید هفتگی',
              createdAt: DateTime.now(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('افزودن آیتم'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'نام آیتم'),
        'شیر',
      );
      await tester.tap(find.text('افزودن'));
      await tester.pumpAndSettle();

      expect(find.text('شیر'), findsOneWidget);
      expect(find.text('خریداری‌شده'), findsNothing);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(find.text('خریداری‌شده'), findsOneWidget);
      // سبک خط‌خورده از طریق AnimatedDefaultTextStyle (وراثت ambient) اعمال
      // می‌شود، نه مستقیم روی ویجت Text؛ بنابراین سبک هدف همان ویجت بررسی می‌شود.
      final animatedStyle = tester
          .widgetList<AnimatedDefaultTextStyle>(
            find.ancestor(
              of: find.text('شیر'),
              matching: find.byType(AnimatedDefaultTextStyle),
            ),
          )
          .first;
      expect(animatedStyle.style.decoration, TextDecoration.lineThrough);
    },
  );
}
