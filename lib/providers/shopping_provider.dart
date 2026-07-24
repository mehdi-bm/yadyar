import 'package:flutter/foundation.dart';

import '../models/shopping_item.dart';
import '../models/shopping_list.dart';
import '../repositories/shopping_list_repository.dart';

class ShoppingProvider extends ChangeNotifier {
  ShoppingProvider({ShoppingListRepository? repository})
    : _repository = repository ?? ShoppingListRepository();

  final ShoppingListRepository _repository;

  List<ShoppingList> _lists = [];
  Map<int, int> _remainingCounts = {};
  bool _isLoadingLists = false;

  List<ShoppingItem> _items = [];
  int? _currentListId;
  bool _isLoadingItems = false;

  bool get isLoadingLists => _isLoadingLists;
  List<ShoppingList> get lists => List.unmodifiable(_lists);

  int remainingCountFor(int listId) => _remainingCounts[listId] ?? 0;

  bool get isLoadingItems => _isLoadingItems;

  /// آیتم‌های تیک‌نخورده، بر اساس دسته‌بندی گروه‌بندی شده‌اند.
  Map<String, List<ShoppingItem>> get uncheckedItemsByCategory {
    final grouped = <String, List<ShoppingItem>>{};
    for (final item in _items.where((item) => !item.isChecked)) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    return grouped;
  }

  /// آیتم‌های خریداری‌شده، جدا از دسته‌بندی‌ها و در پایین لیست نمایش داده می‌شوند.
  List<ShoppingItem> get checkedItems => _items.where((item) => item.isChecked).toList();

  bool get hasCheckedItems => checkedItems.isNotEmpty;

  // ---- لیست‌های خرید ----

  Future<void> loadLists() async {
    _isLoadingLists = true;
    notifyListeners();

    _lists = await _repository.getAll();
    final counts = <int, int>{};
    for (final list in _lists) {
      final items = await _repository.getItemsByListId(list.id!);
      counts[list.id!] = items.where((item) => !item.isChecked).length;
    }
    _remainingCounts = counts;

    _isLoadingLists = false;
    notifyListeners();
  }

  Future<void> addList(String name) async {
    await _repository.insert(ShoppingList(name: name, createdAt: DateTime.now()));
    await loadLists();
  }

  Future<void> renameList(ShoppingList list, String newName) async {
    await _repository.update(list.copyWith(name: newName));
    await loadLists();
  }

  Future<void> deleteList(int id) async {
    await _repository.delete(id);
    await loadLists();
  }

  // ---- آیتم‌های یک لیست خاص ----

  Future<void> loadItems(int listId) async {
    _currentListId = listId;
    _isLoadingItems = true;
    notifyListeners();
    _items = await _repository.getItemsByListId(listId);
    _isLoadingItems = false;
    notifyListeners();
  }

  Future<void> addItem({required String name, required String category, String? quantity}) async {
    final listId = _currentListId;
    if (listId == null) return;
    await _repository.insertItem(
      ShoppingItem(shoppingListId: listId, name: name, category: category, quantity: quantity),
    );
    await loadItems(listId);
  }

  Future<void> toggleItemChecked(ShoppingItem item) async {
    await _repository.updateItem(item.copyWith(isChecked: !item.isChecked));
    await loadItems(item.shoppingListId);
  }

  Future<void> deleteItem(ShoppingItem item) async {
    await _repository.deleteItem(item.id!);
    await loadItems(item.shoppingListId);
  }

  Future<void> clearCheckedItems() async {
    final listId = _currentListId;
    if (listId == null) return;
    for (final item in checkedItems) {
      await _repository.deleteItem(item.id!);
    }
    await loadItems(listId);
  }
}
