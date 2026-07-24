import '../database/database_helper.dart';
import '../models/shopping_item.dart';
import '../models/shopping_list.dart';

/// مدیریت لیست‌های خرید و آیتم‌های داخل هر لیست (رابطه یک‌به‌چند).
class ShoppingListRepository {
  ShoppingListRepository({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  static const String _listsTable = DatabaseHelper.tableShoppingLists;
  static const String _itemsTable = DatabaseHelper.tableShoppingItems;

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
    final maps = await db.query(_listsTable, where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return ShoppingList.fromMap(maps.first);
  }

  // ---- ShoppingItem ----

  Future<int> insertItem(ShoppingItem item) async {
    final db = await _databaseHelper.database;
    return db.insert(_itemsTable, item.toMap());
  }

  Future<int> updateItem(ShoppingItem item) async {
    final db = await _databaseHelper.database;
    return db.update(_itemsTable, item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<int> deleteItem(int id) async {
    final db = await _databaseHelper.database;
    return db.delete(_itemsTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ShoppingItem>> getItemsByListId(int shoppingListId) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      _itemsTable,
      where: 'shoppingListId = ?',
      whereArgs: [shoppingListId],
    );
    return maps.map(ShoppingItem.fromMap).toList();
  }

  Future<ShoppingItem?> getItemById(int id) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(_itemsTable, where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return ShoppingItem.fromMap(maps.first);
  }
}
