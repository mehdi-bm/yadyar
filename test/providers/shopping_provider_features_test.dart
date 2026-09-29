import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yadyar_app/database/database_helper.dart';
import 'package:yadyar_app/models/shopping_category.dart';
import 'package:yadyar_app/models/shopping_item.dart';
import 'package:yadyar_app/providers/shopping_provider.dart';
import 'package:yadyar_app/repositories/shopping_list_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('migration to v4', () {
    test(
      'keeps existing lists/items and imports custom categories from items',
      () async {
        final dir = await Directory.systemTemp.createTemp('yadyar_v4_test');
        addTearDown(() => dir.delete(recursive: true));
        final path = p.join(dir.path, 'test.db');

        // پایگاه‌داده نسخه ۳ با همان شِمای خرید که روی گوشی کاربران است.
        final v3 = await databaseFactory.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 3,
            onCreate: (db, version) async {
              await db.execute('''
                CREATE TABLE shopping_lists (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  name TEXT NOT NULL,
                  createdAt TEXT NOT NULL
                )
              ''');
              await db.execute('''
                CREATE TABLE shopping_items (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  shoppingListId INTEGER NOT NULL,
                  name TEXT NOT NULL,
                  category TEXT NOT NULL,
                  isChecked INTEGER NOT NULL DEFAULT 0,
                  quantity TEXT
                )
              ''');
              for (final table in ['notes', 'subscriptions']) {
                await db.execute(
                  'CREATE TABLE $table (id INTEGER PRIMARY KEY AUTOINCREMENT)',
                );
              }
            },
          ),
        );
        final listId = await v3.insert('shopping_lists', {
          'name': 'خرید قدیمی',
          'createdAt': DateTime(2026, 9, 1).toIso8601String(),
        });
        await v3.insert('shopping_items', {
          'shoppingListId': listId,
          'name': 'ماکارونی',
          'category': 'نان و غلات',
          'isChecked': 1,
          'quantity': '۱',
        });
        await v3.insert('shopping_items', {
          'shoppingListId': listId,
          'name': 'پسته',
          'category': 'آجیل',
          'isChecked': 0,
          'quantity': null,
        });
        await v3.close();

        final helper = DatabaseHelper(path: path);
        addTearDown(helper.close);
        final repository = ShoppingListRepository(databaseHelper: helper);

        final lists = await repository.getAll();
        expect(lists.single.name, 'خرید قدیمی');
        expect(lists.single.colorValue, isNull);

        final items = await repository.getItemsByListId(listId);
        expect(items.map((item) => item.name), ['ماکارونی', 'پسته']);
        expect(items.first.isChecked, isTrue);
        expect(items.first.numericQuantity, 1);
        expect(items.first.isImportant, isFalse);
        expect(items.first.price, isNull);
        expect(items.first.deletedAt, isNull);

        final names = (await repository.getCategories()).map((c) => c.name);
        expect(
          names,
          containsAll([
            ...ShoppingCategory.defaults.map((category) => category.name),
            'آجیل',
          ]),
        );
        expect(names.last, 'آجیل');
      },
    );

    test('fresh install seeds the default categories in order', () async {
      final helper = DatabaseHelper(path: inMemoryDatabasePath);
      addTearDown(helper.close);
      final repository = ShoppingListRepository(databaseHelper: helper);

      final names = (await repository.getCategories()).map((c) => c.name);
      expect(names, ShoppingCategory.defaults.map((category) => category.name));
    });
  });

  group('ShoppingProvider features', () {
    late DatabaseHelper databaseHelper;
    late ShoppingListRepository repository;
    late ShoppingProvider provider;
    late int listId;

    setUp(() async {
      databaseHelper = DatabaseHelper(path: inMemoryDatabasePath);
      repository = ShoppingListRepository(databaseHelper: databaseHelper);
      provider = ShoppingProvider(repository: repository);
      listId = await provider.addList('خرید هفتگی');
      await provider.loadItems(listId);
    });

    tearDown(() async {
      await databaseHelper.close();
    });

    ShoppingItem itemNamed(String name) => [
      ...provider.uncheckedGroups.expand((group) => group.items),
      ...provider.checkedItems,
    ].firstWhere((item) => item.name == name);

    test('prices and quantities roll up into the list summary', () async {
      await provider.addItem(
        name: 'سیب',
        category: 'میوه و سبزیجات',
        quantity: '2',
        unit: 'کیلوگرم',
        price: 50000,
      );
      await provider.addItem(name: 'شیر', category: 'لبنیات', price: 30000);
      await provider.addItem(name: 'نمک', category: 'سایر');
      await provider.toggleItemChecked(itemNamed('شیر'));

      final summary = provider.summaryFor(listId);
      expect(summary.totalCount, 3);
      expect(summary.checkedCount, 1);
      expect(summary.estimatedTotal, 130000);
      expect(summary.spentTotal, 30000);
      expect(summary.progress, closeTo(1 / 3, 1e-9));
      expect(provider.overallSummary.remainingCount, 2);
    });

    test('updateItem edits every field', () async {
      await provider.addItem(name: 'نان', category: 'نان و غلات');

      final original = itemNamed('نان');
      await provider.updateItem(
        ShoppingItem(
          id: original.id,
          shoppingListId: listId,
          name: 'نان سنگک',
          category: 'سایر',
          quantity: '3',
          unit: 'عدد',
          price: 20000,
          note: 'کنجدی',
          isImportant: true,
        ),
      );

      final updated = itemNamed('نان سنگک');
      expect(updated.category, 'سایر');
      expect(updated.quantity, '3');
      expect(updated.unit, 'عدد');
      expect(updated.lineTotal, 60000);
      expect(updated.note, 'کنجدی');
      expect(updated.isImportant, isTrue);
    });

    test('important items come first inside their category', () async {
      await provider.addItem(name: 'موز', category: 'میوه و سبزیجات');
      await provider.addItem(
        name: 'سیب',
        category: 'میوه و سبزیجات',
        isImportant: true,
      );

      expect(
        provider.uncheckedItemsByCategory['میوه و سبزیجات']!.map((i) => i.name),
        ['سیب', 'موز'],
      );
    });

    test(
      'groups follow the category order and reordering changes it',
      () async {
        await provider.addItem(name: 'شیر', category: 'لبنیات');
        await provider.addItem(name: 'سیب', category: 'میوه و سبزیجات');

        expect(provider.uncheckedGroups.map((g) => g.name), [
          'میوه و سبزیجات',
          'لبنیات',
        ]);

        // «لبنیات» (ایندکس ۱) به ابتدای لیست منتقل می‌شود.
        await provider.reorderCategories(1, 0);

        expect(provider.categories.first.name, 'لبنیات');
        expect(provider.uncheckedGroups.map((g) => g.name), [
          'لبنیات',
          'میوه و سبزیجات',
        ]);
      },
    );

    test('renaming a category renames it on its items too', () async {
      await provider.addItem(name: 'شیر', category: 'لبنیات');

      final dairy = provider.categoryByName('لبنیات')!;
      await provider.updateCategory(dairy.copyWith(name: 'لبنی'));

      expect(provider.categoryByName('لبنیات'), isNull);
      expect(itemNamed('شیر').category, 'لبنی');
    });

    test('deleting a category moves its items to سایر', () async {
      final nuts = await provider.addCategory(
        const ShoppingCategory(
          name: 'آجیل',
          iconKey: 'snack',
          colorValue: 0xFF8D6E63,
        ),
      );
      expect(provider.categories.last.name, 'آجیل');
      await provider.addItem(name: 'پسته', category: 'آجیل');

      await provider.deleteCategory(nuts);

      expect(provider.categoryByName('آجیل'), isNull);
      expect(itemNamed('پسته').category, ShoppingCategory.fallbackName);
    });

    test('isCategoryNameTaken ignores case, spaces and the edited one', () {
      final dairy = provider.categoryByName('لبنیات')!;
      expect(provider.isCategoryNameTaken(' لبنیات '), isTrue);
      expect(
        provider.isCategoryNameTaken('لبنیات', exceptId: dairy.id),
        isFalse,
      );
      expect(provider.isCategoryNameTaken('آجیل'), isFalse);
    });

    test('delete and restore brings the item back with its data', () async {
      await provider.addItem(
        name: 'پنیر',
        category: 'لبنیات',
        price: 90000,
        note: 'لیقوان',
      );
      final cheese = itemNamed('پنیر');

      await provider.deleteItem(cheese);
      expect(provider.hasItems, isFalse);

      await provider.restoreItem(cheese);
      final restored = itemNamed('پنیر');
      expect(restored.id, cheese.id);
      expect(restored.price, 90000);
      expect(restored.note, 'لیقوان');
    });

    test('setAllChecked and clearCheckedItems', () async {
      await provider.addItem(name: 'سیب', category: 'میوه و سبزیجات');
      await provider.addItem(name: 'شیر', category: 'لبنیات');

      await provider.setAllChecked(true);
      expect(provider.currentSummary.isCompleted, isTrue);

      await provider.setAllChecked(false);
      expect(provider.hasCheckedItems, isFalse);

      await provider.toggleItemChecked(itemNamed('شیر'));
      await provider.clearCheckedItems();
      expect(provider.currentSummary.totalCount, 1);
      expect(provider.hasCheckedItems, isFalse);
    });

    test('duplicateList copies every item unchecked into a new list', () async {
      await provider.addItem(
        name: 'سیب',
        category: 'میوه و سبزیجات',
        quantity: '2',
        price: 50000,
      );
      await provider.addItem(name: 'شیر', category: 'لبنیات');
      await provider.toggleItemChecked(itemNamed('شیر'));

      final copyId = await provider.duplicateList(provider.listById(listId)!);

      expect(provider.listById(copyId)!.name, 'خرید هفتگی (کپی)');
      final copied = await repository.getItemsByListId(copyId);
      expect(copied.map((item) => item.name), ['سیب', 'شیر']);
      expect(copied.every((item) => !item.isChecked), isTrue);
      expect(copied.first.price, 50000);
      // لیست اصلی دست‌نخورده می‌ماند.
      expect(provider.summaryFor(listId).checkedCount, 1);
    });

    test(
      'quickAddItem reuses category/unit/price from purchase history',
      () async {
        await provider.addItem(
          name: 'ماست',
          category: 'لبنیات',
          unit: 'بسته',
          price: 45000,
        );
        final otherId = await provider.addList('خرید بعدی');
        await provider.loadItems(otherId);

        await provider.quickAddItem('  ماست ');
        await provider.quickAddItem('چیز ناشناخته');

        final yogurt = itemNamed('ماست');
        expect(yogurt.category, 'لبنیات');
        expect(yogurt.unit, 'بسته');
        expect(yogurt.price, 45000);
        expect(
          itemNamed('چیز ناشناخته').category,
          ShoppingCategory.fallbackName,
        );
      },
    );

    test(
      'suggestionsFor matches prefixes first and skips exact name',
      () async {
        await provider.addItem(name: 'شیر', category: 'لبنیات');
        await provider.addItem(name: 'شیرینی', category: 'سایر');
        await provider.addItem(name: 'آب شیرین', category: 'نوشیدنی');

        expect(provider.suggestionsFor('شیر').map((s) => s.name), [
          'شیرینی',
          'آب شیرین',
        ]);
        expect(provider.suggestionsFor(''), isEmpty);
      },
    );

    test('search filters items by name and note', () async {
      await provider.addItem(name: 'سیب', category: 'میوه و سبزیجات');
      await provider.addItem(name: 'شیر', category: 'لبنیات', note: 'کم‌چرب');

      provider.setSearchQuery('چرب');
      expect(provider.uncheckedGroups.single.items.single.name, 'شیر');

      provider.setSearchQuery('');
      expect(provider.uncheckedGroups, hasLength(2));
    });

    test('buildShareText lists items by category with the total', () async {
      await provider.addItem(
        name: 'سیب',
        category: 'میوه و سبزیجات',
        quantity: '2',
        unit: 'کیلوگرم',
        price: 50000,
        isImportant: true,
      );
      await provider.addItem(name: 'شیر', category: 'لبنیات', note: 'کم‌چرب');
      await provider.toggleItemChecked(itemNamed('شیر'));

      final text = await provider.buildShareText(provider.listById(listId)!);

      expect(text, startsWith('🛒 خرید هفتگی'));
      expect(text, contains('میوه و سبزیجات:\n☐ سیب — ۲ کیلوگرم ⭐'));
      expect(text, contains('خریداری‌شده:\n☑ شیر (کم‌چرب)'));
      expect(text, contains('جمع تقریبی: ۱۰۰٬۰۰۰ تومان'));
    });

    test(
      'categoryCounts lists only categories used in the list, in order',
      () async {
        await provider.addItem(name: 'شیر', category: 'لبنیات');
        await provider.addItem(name: 'پنیر', category: 'لبنیات');
        await provider.addItem(name: 'سیب', category: 'میوه و سبزیجات');
        await provider.toggleItemChecked(itemNamed('پنیر'));

        final counts = provider.categoryCounts;
        expect(counts.map((c) => c.name), ['میوه و سبزیجات', 'لبنیات']);
        expect(counts.map((c) => c.remainingCount), [1, 1]);
        expect(counts.first.category, isNotNull);
      },
    );

    test('category filter narrows groups and checked items', () async {
      await provider.addItem(name: 'شیر', category: 'لبنیات');
      await provider.addItem(name: 'پنیر', category: 'لبنیات');
      await provider.addItem(name: 'سیب', category: 'میوه و سبزیجات');
      await provider.toggleItemChecked(itemNamed('پنیر'));
      await provider.toggleItemChecked(itemNamed('سیب'));

      provider.setCategoryFilter('لبنیات');

      expect(provider.uncheckedGroups.single.name, 'لبنیات');
      expect(provider.checkedItems.map((i) => i.name), ['پنیر']);
      // خلاصه/پیشرفت کل لیست به فیلتر وابسته نیست.
      expect(provider.currentSummary.totalCount, 3);

      provider.setCategoryFilter(null);
      expect(provider.checkedItems, hasLength(2));
    });

    test(
      'filter falls back to all when its category has no items left',
      () async {
        await provider.addItem(name: 'شیر', category: 'لبنیات');
        await provider.addItem(name: 'سیب', category: 'میوه و سبزیجات');
        provider.setCategoryFilter('لبنیات');

        await provider.deleteItem(itemNamed('شیر'));

        expect(provider.categoryFilter, isNull);
        expect(provider.uncheckedGroups.single.name, 'میوه و سبزیجات');
      },
    );

    test('active filter becomes the category for new items', () async {
      await provider.addItem(name: 'ماست', category: 'لبنیات');
      await provider.addItem(name: 'سیب', category: 'میوه و سبزیجات');
      provider.setCategoryFilter('میوه و سبزیجات');

      expect(provider.defaultCategoryName, 'میوه و سبزیجات');
      await provider.quickAddItem('موز');
      expect(itemNamed('موز').category, 'میوه و سبزیجات');
    });

    test('opening a list resets the category filter', () async {
      await provider.addItem(name: 'شیر', category: 'لبنیات');
      await provider.addItem(name: 'سیب', category: 'میوه و سبزیجات');
      provider.setCategoryFilter('لبنیات');

      await provider.loadItems(listId);

      expect(provider.categoryFilter, isNull);
    });

    test('deleting moves an item to the trash with its list name', () async {
      await provider.addItem(name: 'شیر', category: 'لبنیات', price: 30000);
      await provider.addItem(name: 'سیب', category: 'میوه و سبزیجات');

      await provider.deleteItem(itemNamed('شیر'));

      expect(provider.currentSummary.totalCount, 1);
      expect(provider.summaryFor(listId).estimatedTotal, 0);
      expect(provider.trashCount, 1);
      final trashed = provider.trashedItems.single;
      expect(trashed.item.name, 'شیر');
      expect(trashed.listName, 'خرید هفتگی');
      expect(trashed.item.deletedAt, isNotNull);
    });

    test('restoring from trash brings the item back to its list', () async {
      await provider.addItem(name: 'شیر', category: 'لبنیات', note: 'کم‌چرب');
      await provider.deleteItem(itemNamed('شیر'));

      await provider.restoreItem(provider.trashedItems.single.item);

      expect(provider.trashCount, 0);
      final milk = itemNamed('شیر');
      expect(milk.note, 'کم‌چرب');
      expect(milk.deletedAt, isNull);
    });

    test('deleteItemForever and emptyTrash remove rows permanently', () async {
      await provider.addItem(name: 'شیر', category: 'لبنیات');
      await provider.addItem(name: 'سیب', category: 'میوه و سبزیجات');
      await provider.addItem(name: 'نان', category: 'نان و غلات');
      final milkId = itemNamed('شیر').id!;
      await provider.deleteItem(itemNamed('شیر'));
      await provider.deleteItem(itemNamed('سیب'));

      await provider.deleteItemForever(
        provider.trashedItems.firstWhere((e) => e.item.name == 'شیر').item,
      );
      expect(await repository.getItemById(milkId), isNull);
      expect(provider.trashCount, 1);

      await provider.emptyTrash();
      expect(provider.trashCount, 0);
      expect(provider.currentSummary.totalCount, 1);
    });

    test('clearCheckedItems moves checked items to the trash', () async {
      await provider.addItem(name: 'شیر', category: 'لبنیات');
      await provider.addItem(name: 'سیب', category: 'میوه و سبزیجات');
      await provider.toggleItemChecked(itemNamed('شیر'));

      final moved = await provider.clearCheckedItems();

      expect(moved, 1);
      expect(provider.hasCheckedItems, isFalse);
      expect(provider.trashedItems.single.item.name, 'شیر');
    });

    test('trashed items are not duplicated or suggested', () async {
      await provider.addItem(name: 'شیر', category: 'لبنیات');
      await provider.addItem(name: 'سیب', category: 'میوه و سبزیجات');
      await provider.deleteItem(itemNamed('شیر'));

      final copyId = await provider.duplicateList(provider.listById(listId)!);

      final copied = await repository.getItemsByListId(copyId);
      expect(copied.map((item) => item.name), ['سیب']);
      expect(provider.suggestionFor('شیر'), isNull);
    });

    test('items older than the retention period are purged on load', () async {
      await provider.addItem(name: 'شیر', category: 'لبنیات');
      await provider.addItem(name: 'سیب', category: 'میوه و سبزیجات');
      final milk = itemNamed('شیر');
      final apple = itemNamed('سیب');
      await repository.updateItem(
        milk.copyWith().withDeletedAt(
          DateTime.now().subtract(
            ShoppingProvider.trashRetention + const Duration(days: 1),
          ),
        ),
      );
      await provider.deleteItem(apple);

      await provider.loadLists();

      expect(await repository.getItemById(milk.id!), isNull);
      expect(provider.trashedItems.single.item.name, 'سیب');
    });
  });
}

extension on ShoppingItem {
  ShoppingItem withDeletedAt(DateTime value) => ShoppingItem(
    id: id,
    shoppingListId: shoppingListId,
    name: name,
    category: category,
    isChecked: isChecked,
    quantity: quantity,
    unit: unit,
    price: price,
    note: note,
    isImportant: isImportant,
    deletedAt: value,
  );
}
