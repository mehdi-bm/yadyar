import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/shopping_category.dart';
import '../models/shopping_item.dart';
import '../models/shopping_list.dart';

/// قلمی در «حذف‌شده‌ها» همراه با نام لیستی که از آن حذف شده.
class TrashedShoppingItem {
  const TrashedShoppingItem({required this.item, required this.listName});

  final ShoppingItem item;
  final String listName;
}

/// مدیریت لیست‌های خرید، آیتم‌های داخل هر لیست (رابطه یک‌به‌چند) و
/// دسته‌بندی‌های اقلام خرید.
class ShoppingListRepository {
  ShoppingListRepository({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  static const String _listsTable = DatabaseHelper.tableShoppingLists;
  static const String _itemsTable = DatabaseHelper.tableShoppingItems;
  static const String _categoriesTable = DatabaseHelper.tableShoppingCategories;

  // ---- ShoppingList ----

  Future<int> insert(ShoppingList shoppingList) async {
    final db = await _databaseHelper.database;
    return db.insert(_listsTable, shoppingList.toMap());
  }

  Future<int> update(ShoppingList shoppingList) async {
    final db = await _databaseHelper.database;
    return db.update(
      _listsTable,
      shoppingList.toMap(),
      where: 'id = ?',
      whereArgs: [shoppingList.id],
    );
  }

  /// حذف لیست، آیتم‌های آن را نیز به‌واسطه ON DELETE CASCADE حذف می‌کند.
  Future<int> delete(int id) async {
    final db = await _databaseHelper.database;
    return db.delete(_listsTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ShoppingList>> getAll() async {
    final db = await _databaseHelper.database;
    final maps = await db.query(_listsTable, orderBy: 'createdAt DESC');
    return maps.map(ShoppingList.fromMap).toList();
  }

  Future<ShoppingList?> getById(int id) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      _listsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ShoppingList.fromMap(maps.first);
  }

  /// یک کپی از لیست با همه آیتم‌هایش (همه تیک‌نخورده) می‌سازد؛ برای خریدهای
  /// تکراری مثل «خرید هفتگی». شناسه لیست جدید برگردانده می‌شود.
  Future<int> duplicate(int listId, {required String newName}) async {
    final db = await _databaseHelper.database;
    return db.transaction((txn) async {
      final source = await txn.query(
        _listsTable,
        where: 'id = ?',
        whereArgs: [listId],
        limit: 1,
      );
      final original = ShoppingList.fromMap(source.first);
      final newId = await txn.insert(
        _listsTable,
        ShoppingList(
          name: newName,
          createdAt: DateTime.now(),
          colorValue: original.colorValue,
        ).toMap(),
      );
      final items = await txn.query(
        _itemsTable,
        where: 'shoppingListId = ? AND deletedAt IS NULL',
        whereArgs: [listId],
        orderBy: 'id',
      );
      for (final map in items) {
        final item = ShoppingItem.fromMap(map);
        final copy = ShoppingItem(
          shoppingListId: newId,
          name: item.name,
          category: item.category,
          quantity: item.quantity,
          unit: item.unit,
          price: item.price,
          note: item.note,
          isImportant: item.isImportant,
        );
        await txn.insert(_itemsTable, copy.toMap());
      }
      return newId;
    });
  }

  // ---- ShoppingItem ----

  Future<int> insertItem(ShoppingItem item) async {
    final db = await _databaseHelper.database;
    return db.insert(_itemsTable, item.toMap());
  }

  Future<int> updateItem(ShoppingItem item) async {
    final db = await _databaseHelper.database;
    return db.update(
      _itemsTable,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  /// حذف دائمی (از «حذف‌شده‌ها»). برای حذف معمولی از [moveItemToTrash] استفاده کنید.
  Future<int> deleteItem(int id) async {
    final db = await _databaseHelper.database;
    return db.delete(_itemsTable, where: 'id = ?', whereArgs: [id]);
  }

  /// انتقال قلم به «حذف‌شده‌ها» (قابل بازیابی).
  Future<void> moveItemToTrash(int id) async {
    final db = await _databaseHelper.database;
    await db.update(
      _itemsTable,
      {'deletedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restoreItem(int id) async {
    final db = await _databaseHelper.database;
    await db.update(
      _itemsTable,
      {'deletedAt': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// اقلام فعال (حذف‌نشده) یک لیست.
  Future<List<ShoppingItem>> getItemsByListId(int shoppingListId) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      _itemsTable,
      where: 'shoppingListId = ? AND deletedAt IS NULL',
      whereArgs: [shoppingListId],
      orderBy: 'id',
    );
    return maps.map(ShoppingItem.fromMap).toList();
  }

  /// همه آیتم‌های فعال همه لیست‌ها؛ برای محاسبه خلاصه (پیشرفت و جمع قیمت) هر
  /// لیست با یک کوئری، به‌جای یک کوئری برای هر لیست.
  Future<List<ShoppingItem>> getAllItems() async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      _itemsTable,
      where: 'deletedAt IS NULL',
      orderBy: 'id',
    );
    return maps.map(ShoppingItem.fromMap).toList();
  }

  /// محتوای «حذف‌شده‌ها»، جدیدترین حذف اول، همراه با نام لیست هر قلم.
  Future<List<TrashedShoppingItem>> getTrashedItems() async {
    final db = await _databaseHelper.database;
    final maps = await db.rawQuery('''
      SELECT i.*, l.name AS listName
      FROM $_itemsTable i
      JOIN $_listsTable l ON l.id = i.shoppingListId
      WHERE i.deletedAt IS NOT NULL
      ORDER BY i.deletedAt DESC, i.id DESC
    ''');
    return [
      for (final map in maps)
        TrashedShoppingItem(
          item: ShoppingItem.fromMap(map),
          listName: map['listName'] as String,
        ),
    ];
  }

  /// حذف دائمی همه اقلام «حذف‌شده‌ها».
  Future<void> emptyTrash() async {
    final db = await _databaseHelper.database;
    await db.delete(_itemsTable, where: 'deletedAt IS NOT NULL');
  }

  /// اقلامی که بیش از [age] در «حذف‌شده‌ها» مانده‌اند برای همیشه پاک می‌شوند.
  Future<void> purgeTrashOlderThan(Duration age) async {
    final db = await _databaseHelper.database;
    final cutoff = DateTime.now().subtract(age).toIso8601String();
    await db.delete(
      _itemsTable,
      where: 'deletedAt IS NOT NULL AND deletedAt < ?',
      whereArgs: [cutoff],
    );
  }

  Future<ShoppingItem?> getItemById(int id) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      _itemsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ShoppingItem.fromMap(maps.first);
  }

  Future<void> setAllChecked(
    int shoppingListId, {
    required bool checked,
  }) async {
    final db = await _databaseHelper.database;
    await db.update(
      _itemsTable,
      {'isChecked': checked ? 1 : 0},
      where: 'shoppingListId = ? AND deletedAt IS NULL',
      whereArgs: [shoppingListId],
    );
  }

  /// اقلام خریداری‌شده لیست را به «حذف‌شده‌ها» منتقل می‌کند؛ تعداد را برمی‌گرداند.
  Future<int> moveCheckedItemsToTrash(int shoppingListId) async {
    final db = await _databaseHelper.database;
    return db.update(
      _itemsTable,
      {'deletedAt': DateTime.now().toIso8601String()},
      where: 'shoppingListId = ? AND isChecked = 1 AND deletedAt IS NULL',
      whereArgs: [shoppingListId],
    );
  }

  // ---- ShoppingCategory ----

  Future<List<ShoppingCategory>> getCategories() async {
    final db = await _databaseHelper.database;
    final maps = await db.query(_categoriesTable, orderBy: 'sortOrder, id');
    return maps.map(ShoppingCategory.fromMap).toList();
  }

  /// دسته جدید را در انتهای ترتیب فعلی اضافه می‌کند.
  Future<int> insertCategory(ShoppingCategory category) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(MAX(sortOrder), -1) + 1 AS next FROM $_categoriesTable',
    );
    final next = result.first['next'] as int;
    return db.insert(
      _categoriesTable,
      category.copyWith(sortOrder: next).toMap()..remove('id'),
    );
  }

  /// دسته را به‌روزرسانی می‌کند؛ اگر نام تغییر کرده باشد، آیتم‌های آن دسته هم
  /// (در همان تراکنش) به نام جدید منتقل می‌شوند.
  Future<void> updateCategory(
    ShoppingCategory category, {
    required String previousName,
  }) async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        _categoriesTable,
        category.toMap(),
        where: 'id = ?',
        whereArgs: [category.id],
      );
      if (previousName != category.name) {
        await txn.update(
          _itemsTable,
          {'category': category.name},
          where: 'category = ?',
          whereArgs: [previousName],
        );
      }
    });
  }

  /// دسته را حذف و آیتم‌های آن را به دسته «سایر» منتقل می‌کند.
  Future<void> deleteCategory(ShoppingCategory category) async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      await txn.insert(
        _categoriesTable,
        const ShoppingCategory(
          name: ShoppingCategory.fallbackName,
          iconKey: 'other',
          colorValue: ShoppingCategory.defaultColorValue,
          sortOrder: 1 << 20,
        ).toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await txn.update(
        _itemsTable,
        {'category': ShoppingCategory.fallbackName},
        where: 'category = ?',
        whereArgs: [category.name],
      );
      await txn.delete(
        _categoriesTable,
        where: 'id = ?',
        whereArgs: [category.id],
      );
    });
  }

  /// ترتیب نمایش دسته‌ها را مطابق ترتیب شناسه‌های داده‌شده ذخیره می‌کند.
  Future<void> reorderCategories(List<int> orderedIds) async {
    final db = await _databaseHelper.database;
    final batch = db.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(
        _categoriesTable,
        {'sortOrder': i},
        where: 'id = ?',
        whereArgs: [orderedIds[i]],
      );
    }
    await batch.commit(noResult: true);
  }
}
