import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yadyar_app/database/database_helper.dart';
import 'package:yadyar_app/models/shopping_item.dart';
import 'package:yadyar_app/models/shopping_list.dart';
import 'package:yadyar_app/providers/shopping_provider.dart';
import 'package:yadyar_app/repositories/shopping_list_repository.dart';
import 'package:yadyar_app/screens/shopping/shopping_categories_screen.dart';
import 'package:yadyar_app/screens/shopping/shopping_list_detail_screen.dart';
import 'package:yadyar_app/screens/shopping/shopping_lists_screen.dart';
import 'package:yadyar_app/screens/shopping/shopping_trash_screen.dart';
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

  Future<int> openDetailWithItems(
    WidgetTester tester,
    List<ShoppingItem Function(int listId)> items,
  ) async {
    final listId = await repository.insert(
      ShoppingList(name: 'خرید هفتگی', createdAt: DateTime.now()),
    );
    for (final build in items) {
      await repository.insertItem(build(listId));
    }
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
    return listId;
  }

  testWidgets('editing an item updates its name, quantity and price', (
    tester,
  ) async {
    await openDetailWithItems(tester, [
      (id) => ShoppingItem(shoppingListId: id, name: 'نان', category: 'سایر'),
    ]);

    await tester.tap(find.byTooltip('ویرایش آیتم'));
    await tester.pumpAndSettle();

    expect(find.text('ویرایش آیتم'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'نام آیتم'),
      'نان سنگک',
    );
    await tester.tap(find.byTooltip('زیاد کردن'));
    await tester.tap(find.byTooltip('زیاد کردن'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'قیمت واحد (اختیاری)'),
      '20000',
    );
    await tester.pump();
    await tester.tap(find.text('ذخیره تغییرات'));
    await tester.pumpAndSettle();

    expect(find.text('نان سنگک'), findsOneWidget);
    expect(find.text('۲ • ۴۰٬۰۰۰ تومان'), findsOneWidget);
  });

  testWidgets('swiping an item deletes it and undo restores it', (
    tester,
  ) async {
    await openDetailWithItems(tester, [
      (id) => ShoppingItem(shoppingListId: id, name: 'شیر', category: 'لبنیات'),
      (id) => ShoppingItem(shoppingListId: id, name: 'سیب', category: 'سایر'),
    ]);

    await tester.drag(find.text('شیر'), const Offset(-700, 0));
    await tester.pumpAndSettle();

    expect(find.text('شیر'), findsNothing);
    expect(find.text('«شیر» به حذف‌شده‌ها منتقل شد'), findsOneWidget);

    await tester.tap(find.text('بازگردانی'));
    await tester.pumpAndSettle();

    expect(find.text('شیر'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick add bar adds an item by name', (tester) async {
    await openDetailWithItems(tester, []);

    await tester.enterText(
      find.widgetWithText(TextField, 'افزودن سریع؛ مثلاً «نان» و Enter'),
      'پنیر',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('پنیر'), findsOneWidget);
    expect(find.text('سایر'), findsOneWidget);
  });

  testWidgets('categories screen creates a new category', (tester) async {
    await tester.pumpWidget(wrap(const ShoppingCategoriesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('لبنیات'), findsOneWidget);

    await tester.tap(find.byTooltip('دسته جدید'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'نام دسته'),
      'آجیل',
    );
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    // دسته جدید در انتهای لیست اضافه می‌شود (ممکن است بیرون از صفحه باشد).
    await tester.scrollUntilVisible(find.text('آجیل'), 200);
    expect(find.text('آجیل'), findsOneWidget);
    expect(provider.categories.last.name, 'آجیل');
  });

  testWidgets('duplicate name for a category is rejected', (tester) async {
    await tester.pumpWidget(wrap(const ShoppingCategoriesScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('دسته جدید'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'نام دسته'),
      'لبنیات',
    );
    await tester.tap(find.text('ذخیره'));
    await tester.pump();

    expect(find.text('این دسته از قبل وجود دارد'), findsOneWidget);
  });

  testWidgets('category filter bar shows only used categories and filters', (
    tester,
  ) async {
    await openDetailWithItems(tester, [
      (id) => ShoppingItem(shoppingListId: id, name: 'شیر', category: 'لبنیات'),
      (id) => ShoppingItem(
        shoppingListId: id,
        name: 'سیب',
        category: 'میوه و سبزیجات',
      ),
    ]);

    // «همه» + دو دسته استفاده‌شده؛ دسته‌های بی‌آیتم (مثل «نوشیدنی») نیستند.
    expect(find.bySemanticsLabel('همه، ۲ مورد'), findsOneWidget);
    expect(find.bySemanticsLabel('لبنیات، ۱ مورد'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^نوشیدنی')), findsNothing);

    await tester.tap(find.bySemanticsLabel('لبنیات، ۱ مورد'));
    await tester.pumpAndSettle();

    expect(find.text('شیر'), findsOneWidget);
    expect(find.text('سیب'), findsNothing);

    // لمس دوباره همان دسته، فیلتر را برمی‌دارد.
    await tester.tap(find.bySemanticsLabel('لبنیات، ۱ مورد'));
    await tester.pumpAndSettle();

    expect(find.text('سیب'), findsOneWidget);
  });

  testWidgets('undo snackbar hides by itself and can be closed', (
    tester,
  ) async {
    await openDetailWithItems(tester, [
      (id) => ShoppingItem(shoppingListId: id, name: 'شیر', category: 'لبنیات'),
      (id) => ShoppingItem(shoppingListId: id, name: 'سیب', category: 'سایر'),
    ]);

    await tester.drag(find.text('شیر'), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('«شیر» به حذف‌شده‌ها منتقل شد'), findsNothing);

    await tester.drag(find.text('سیب'), const Offset(-700, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('«سیب» به حذف‌شده‌ها منتقل شد'), findsNothing);
  });

  testWidgets('trash screen lists deleted items and restores them', (
    tester,
  ) async {
    final listId = await repository.insert(
      ShoppingList(name: 'خرید هفتگی', createdAt: DateTime.now()),
    );
    final id = await repository.insertItem(
      ShoppingItem(shoppingListId: listId, name: 'پنیر', category: 'لبنیات'),
    );
    await repository.moveItemToTrash(id);

    await tester.pumpWidget(wrap(const ShoppingTrashScreen()));
    await tester.pumpAndSettle();

    expect(find.text('پنیر'), findsOneWidget);
    expect(find.text('خرید هفتگی'), findsOneWidget);

    await tester.tap(find.byTooltip('بازگردانی'));
    await tester.pumpAndSettle();

    expect(find.textContaining('بخش حذف‌شده‌ها خالی است'), findsOneWidget);
    expect((await repository.getItemsByListId(listId)).single.name, 'پنیر');
  });
}
