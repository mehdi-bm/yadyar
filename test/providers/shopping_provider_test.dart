import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yadyar_app/database/database_helper.dart';
import 'package:yadyar_app/providers/shopping_provider.dart';
import 'package:yadyar_app/repositories/shopping_list_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
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

  test('addList then loadLists shows the list with zero remaining items', () async {
    await provider.addList('خرید هفتگی');

    expect(provider.lists, hasLength(1));
    final list = provider.lists.first;
    expect(list.name, 'خرید هفتگی');
    expect(provider.remainingCountFor(list.id!), 0);
  });

  test('remainingCountFor counts only unchecked items', () async {
    await provider.addList('خرید هفتگی');
    final listId = provider.lists.first.id!;

    await provider.loadItems(listId);
    await provider.addItem(name: 'سیب', category: 'میوه و سبزیجات');
    await provider.addItem(name: 'شیر', category: 'لبنیات');
    await provider.toggleItemChecked(provider.uncheckedItemsByCategory['میوه و سبزیجات']!.first);

    await provider.loadLists();

    expect(provider.remainingCountFor(listId), 1);
  });

  test('items are grouped by category and checked items are separated', () async {
    await provider.addList('خرید هفتگی');
    final listId = provider.lists.first.id!;
    await provider.loadItems(listId);

    await provider.addItem(name: 'سیب', category: 'میوه و سبزیجات');
    await provider.addItem(name: 'موز', category: 'میوه و سبزیجات');
    await provider.addItem(name: 'شیر', category: 'لبنیات');

    expect(provider.uncheckedItemsByCategory['میوه و سبزیجات'], hasLength(2));
    expect(provider.uncheckedItemsByCategory['لبنیات'], hasLength(1));
    expect(provider.checkedItems, isEmpty);

    final milk = provider.uncheckedItemsByCategory['لبنیات']!.first;
    await provider.toggleItemChecked(milk);

    expect(provider.uncheckedItemsByCategory.containsKey('لبنیات'), isFalse);
    expect(provider.checkedItems, hasLength(1));
    expect(provider.checkedItems.first.name, 'شیر');
  });

  test('clearCheckedItems removes only checked items', () async {
    await provider.addList('خرید هفتگی');
    final listId = provider.lists.first.id!;
    await provider.loadItems(listId);

    await provider.addItem(name: 'سیب', category: 'میوه و سبزیجات');
    await provider.addItem(name: 'شیر', category: 'لبنیات');
    await provider.toggleItemChecked(provider.uncheckedItemsByCategory['لبنیات']!.first);

    expect(provider.hasCheckedItems, isTrue);

    await provider.clearCheckedItems();

    expect(provider.checkedItems, isEmpty);
    expect(provider.uncheckedItemsByCategory['میوه و سبزیجات'], hasLength(1));
  });

  test('deleteList removes the list and its items disappear from provider state', () async {
    await provider.addList('لیست حذفی');
    final listId = provider.lists.first.id!;
    await provider.loadItems(listId);
    await provider.addItem(name: 'نان', category: 'نان و غلات');

    await provider.deleteList(listId);

    expect(provider.lists, isEmpty);
    expect(await repository.getItemsByListId(listId), isEmpty);
  });
}
