import 'package:flutter/foundation.dart';

import '../models/shopping_category.dart';
import '../models/shopping_item.dart';
import '../models/shopping_list.dart';
import '../repositories/shopping_list_repository.dart';
import '../utils/currency_formatter.dart';
import '../utils/shopping_format.dart';

/// خلاصه وضعیت یک لیست خرید: پیشرفت و جمع قیمت‌ها.
class ShoppingListSummary {
  const ShoppingListSummary({
    this.totalCount = 0,
    this.checkedCount = 0,
    this.estimatedTotal = 0,
    this.spentTotal = 0,
  });

  factory ShoppingListSummary.fromItems(Iterable<ShoppingItem> items) {
    var total = 0;
    var checked = 0;
    double estimated = 0;
    double spent = 0;
    for (final item in items) {
      total++;
      final line = item.lineTotal ?? 0;
      estimated += line;
      if (item.isChecked) {
        checked++;
        spent += line;
      }
    }
    return ShoppingListSummary(
      totalCount: total,
      checkedCount: checked,
      estimatedTotal: estimated,
      spentTotal: spent,
    );
  }

  final int totalCount;
  final int checkedCount;

  /// جمع قیمت همه اقلامی که قیمت دارند.
  final double estimatedTotal;

  /// جمع قیمت اقلام خریداری‌شده.
  final double spentTotal;

  int get remainingCount => totalCount - checkedCount;
  double get progress => totalCount == 0 ? 0 : checkedCount / totalCount;
  bool get isCompleted => totalCount > 0 && checkedCount == totalCount;
  bool get hasPrices => estimatedTotal > 0;
}

/// اقلام تیک‌نخورده یک دسته، به ترتیب دسته‌ها.
class ShoppingItemGroup {
  const ShoppingItemGroup({
    required this.name,
    required this.category,
    required this.items,
  });

  final String name;

  /// null یعنی دسته‌ای که در جدول دسته‌ها نیست (مثلاً داده بازیابی‌شده قدیمی).
  final ShoppingCategory? category;
  final List<ShoppingItem> items;
}

/// یک دسته در نوار فیلتر لیست، با تعداد اقلام باقی‌مانده آن.
class ShoppingCategoryCount {
  const ShoppingCategoryCount({
    required this.name,
    required this.category,
    required this.remainingCount,
  });

  final String name;
  final ShoppingCategory? category;
  final int remainingCount;
}

/// پیشنهاد نام قلم از خریدهای قبلی، همراه با آخرین دسته/واحد/قیمت آن.
class ShoppingItemSuggestion {
  const ShoppingItemSuggestion({
    required this.name,
    required this.category,
    this.unit,
    this.price,
  });

  final String name;
  final String category;
  final String? unit;
  final double? price;
}

class ShoppingProvider extends ChangeNotifier {
  ShoppingProvider({ShoppingListRepository? repository})
    : _repository = repository ?? ShoppingListRepository();

  final ShoppingListRepository _repository;

  List<ShoppingList> _lists = [];
  Map<int, ShoppingListSummary> _summaries = {};
  List<ShoppingCategory> _categories = [];
  List<ShoppingItemSuggestion> _history = [];
  List<TrashedShoppingItem> _trash = [];
  bool _isLoadingLists = false;

  List<ShoppingItem> _items = [];
  int? _currentListId;
  bool _isLoadingItems = false;
  String _searchQuery = '';
  String? _categoryFilter;
  bool _showCheckedItems = true;
  String? _lastUsedCategory;

  bool get isLoadingLists => _isLoadingLists;
  List<ShoppingList> get lists => List.unmodifiable(_lists);

  ShoppingList? listById(int id) {
    for (final list in _lists) {
      if (list.id == id) return list;
    }
    return null;
  }

  ShoppingListSummary summaryFor(int listId) =>
      _summaries[listId] ?? const ShoppingListSummary();

  int remainingCountFor(int listId) => summaryFor(listId).remainingCount;

  /// خلاصه همه لیست‌ها با هم (برای کارت خلاصه بالای صفحه لیست‌ها).
  ShoppingListSummary get overallSummary {
    var total = 0;
    var checked = 0;
    double estimated = 0;
    double spent = 0;
    for (final summary in _summaries.values) {
      total += summary.totalCount;
      checked += summary.checkedCount;
      estimated += summary.estimatedTotal;
      spent += summary.spentTotal;
    }
    return ShoppingListSummary(
      totalCount: total,
      checkedCount: checked,
      estimatedTotal: estimated,
      spentTotal: spent,
    );
  }

  // ---- دسته‌بندی‌ها ----

  List<ShoppingCategory> get categories => List.unmodifiable(_categories);

  ShoppingCategory? categoryByName(String name) {
    for (final category in _categories) {
      if (category.name == name) return category;
    }
    return null;
  }

  bool isCategoryNameTaken(String name, {int? exceptId}) {
    final normalized = name.trim().toLowerCase();
    return _categories.any(
      (category) =>
          category.id != exceptId &&
          category.name.trim().toLowerCase() == normalized,
    );
  }

  /// دسته پیش‌فرض فرم افزودن قلم: دسته فیلترشده فعلی، وگرنه آخرین دسته
  /// استفاده‌شده، وگرنه اولین دسته.
  String get defaultCategoryName {
    final filter = categoryFilter;
    if (filter != null) return filter;
    final last = _lastUsedCategory;
    if (last != null && categoryByName(last) != null) return last;
    if (_categories.isNotEmpty) return _categories.first.name;
    return ShoppingCategory.fallbackName;
  }

  // ---- آیتم‌های لیست جاری ----

  bool get isLoadingItems => _isLoadingItems;
  String get searchQuery => _searchQuery;
  bool get showCheckedItems => _showCheckedItems;

  ShoppingListSummary get currentSummary =>
      ShoppingListSummary.fromItems(_items);

  bool get hasItems => _items.isNotEmpty;

  /// دسته‌هایی که در لیست جاری آیتم دارند (برای نوار فیلتر افقی)، به ترتیب
  /// دسته‌ها؛ تعداد هر کدام، اقلام باقی‌مانده (تیک‌نخورده) آن دسته است.
  List<ShoppingCategoryCount> get categoryCounts {
    final remaining = <String, int>{};
    for (final item in _items) {
      remaining[item.category] =
          (remaining[item.category] ?? 0) + (item.isChecked ? 0 : 1);
    }
    return [
      for (final name in _sortedCategoryNames(remaining.keys))
        ShoppingCategoryCount(
          name: name,
          category: categoryByName(name),
          remainingCount: remaining[name]!,
        ),
    ];
  }

  /// دسته انتخاب‌شده در نوار فیلتر؛ null یعنی «همه». اگر دسته دیگر در لیست
  /// آیتمی نداشته باشد (مثلاً آخرین آیتمش حذف شده)، فیلتر خودبه‌خود «همه» است.
  String? get categoryFilter {
    final filter = _categoryFilter;
    if (filter == null) return null;
    return _items.any((item) => item.category == filter) ? filter : null;
  }

  void setCategoryFilter(String? category) {
    if (category == _categoryFilter) return;
    _categoryFilter = category;
    notifyListeners();
  }

  /// اقلام تیک‌نخورده (با فیلتر جستجو و دسته)، گروه‌بندی‌شده به ترتیب دسته‌ها.
  List<ShoppingItemGroup> get uncheckedGroups =>
      _groupItems(_filtered(_items.where((item) => !item.isChecked)));

  /// آیتم‌های تیک‌نخورده، بر اساس دسته‌بندی گروه‌بندی شده‌اند.
  Map<String, List<ShoppingItem>> get uncheckedItemsByCategory => {
    for (final group in uncheckedGroups) group.name: group.items,
  };

  /// آیتم‌های خریداری‌شده، جدا از دسته‌بندی‌ها و در پایین لیست نمایش داده می‌شوند.
  List<ShoppingItem> get checkedItems =>
      _filtered(_items.where((item) => item.isChecked)).toList();

  bool get hasCheckedItems => _items.any((item) => item.isChecked);
  bool get hasUncheckedItems => _items.any((item) => !item.isChecked);

  /// پیشنهادهای نام قلم برای تکمیل خودکار، از جدیدترین خرید به قدیمی‌ترین.
  List<ShoppingItemSuggestion> suggestionsFor(String query, {int limit = 6}) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    final startsWith = <ShoppingItemSuggestion>[];
    final contains = <ShoppingItemSuggestion>[];
    for (final suggestion in _history) {
      final name = suggestion.name.toLowerCase();
      if (name == normalized) continue;
      if (name.startsWith(normalized)) {
        startsWith.add(suggestion);
      } else if (name.contains(normalized)) {
        contains.add(suggestion);
      }
    }
    return [...startsWith, ...contains].take(limit).toList();
  }

  ShoppingItemSuggestion? suggestionFor(String name) {
    final normalized = name.trim().toLowerCase();
    for (final suggestion in _history) {
      if (suggestion.name.toLowerCase() == normalized) return suggestion;
    }
    return null;
  }

  // ---- بارگذاری ----

  Future<void> loadLists() async {
    _isLoadingLists = true;
    notifyListeners();
    await _repository.purgeTrashOlderThan(trashRetention);
    await _refreshDerived();
    _isLoadingLists = false;
    notifyListeners();
  }

  Future<void> loadItems(int listId) async {
    // هر بار باز شدن صفحه لیست با نوار جستجوی بسته شروع می‌شود.
    _searchQuery = '';
    _categoryFilter = null;
    _currentListId = listId;
    _isLoadingItems = true;
    notifyListeners();
    _items = await _repository.getItemsByListId(listId);
    await _refreshDerived();
    _isLoadingItems = false;
    notifyListeners();
  }

  Future<void> loadCategories() async {
    _categories = await _repository.getCategories();
    notifyListeners();
  }

  /// لیست‌ها، دسته‌ها، خلاصه هر لیست و تاریخچه پیشنهادها را از نو می‌خواند.
  Future<void> _refreshDerived() async {
    _lists = await _repository.getAll();
    _categories = await _repository.getCategories();
    _trash = await _repository.getTrashedItems();
    final allItems = await _repository.getAllItems();

    final byList = <int, List<ShoppingItem>>{};
    // LinkedHashMap: حذف و درج دوباره، نام را به انتهای ترتیب (جدیدترین) می‌برد.
    final history = <String, ShoppingItemSuggestion>{};
    for (final item in allItems) {
      byList.putIfAbsent(item.shoppingListId, () => []).add(item);
      final key = item.name.trim().toLowerCase();
      if (key.isEmpty) continue;
      history.remove(key);
      history[key] = ShoppingItemSuggestion(
        name: item.name.trim(),
        category: item.category,
        unit: item.unit,
        price: item.price,
      );
    }
    _summaries = {
      for (final list in _lists)
        list.id!: ShoppingListSummary.fromItems(byList[list.id] ?? const []),
    };
    _history = history.values.toList().reversed.toList();
  }

  Future<void> _reloadCurrentItems() async {
    final listId = _currentListId;
    if (listId != null) {
      _items = await _repository.getItemsByListId(listId);
    }
    await _refreshDerived();
    notifyListeners();
  }

  // ---- لیست‌های خرید ----

  Future<int> addList(String name, {int? colorValue}) async {
    final id = await _repository.insert(
      ShoppingList(
        name: name,
        createdAt: DateTime.now(),
        colorValue: colorValue,
      ),
    );
    await loadLists();
    return id;
  }

  Future<void> updateList(ShoppingList list) async {
    await _repository.update(list);
    await _reloadCurrentItems();
  }

  Future<void> renameList(ShoppingList list, String newName) =>
      updateList(list.copyWith(name: newName));

  Future<void> deleteList(int id) async {
    await _repository.delete(id);
    await loadLists();
  }

  /// کپی لیست با همه اقلام (تیک‌نخورده)؛ شناسه لیست جدید را برمی‌گرداند.
  Future<int> duplicateList(ShoppingList list) async {
    final id = await _repository.duplicate(
      list.id!,
      newName: '${list.name} (کپی)',
    );
    await loadLists();
    return id;
  }

  // ---- اقلام ----

  Future<void> addItem({
    required String name,
    required String category,
    String? quantity,
    String? unit,
    double? price,
    String? note,
    bool isImportant = false,
  }) async {
    final listId = _currentListId;
    if (listId == null) return;
    await _repository.insertItem(
      ShoppingItem(
        shoppingListId: listId,
        name: name,
        category: category,
        quantity: quantity,
        unit: unit,
        price: price,
        note: note,
        isImportant: isImportant,
      ),
    );
    _lastUsedCategory = category;
    await _reloadCurrentItems();
  }

  /// افزودن سریع فقط با نام. دسته: اگر در نوار فیلتر دسته‌ای انتخاب شده، همان
  /// دسته؛ وگرنه اگر این قلم قبلاً خریده شده، دسته آخرین خرید آن؛ وگرنه «سایر».
  /// واحد/قیمت آخرین خرید هم (در صورت وجود) استفاده می‌شود.
  Future<void> quickAddItem(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) return;
    final suggestion = suggestionFor(name);
    final category =
        categoryFilter ??
        (suggestion != null && categoryByName(suggestion.category) != null
            ? suggestion.category
            : ShoppingCategory.fallbackName);
    final listId = _currentListId;
    if (listId == null) return;
    await _repository.insertItem(
      ShoppingItem(
        shoppingListId: listId,
        name: name,
        category: category,
        unit: suggestion?.unit,
        price: suggestion?.price,
      ),
    );
    await _reloadCurrentItems();
  }

  Future<void> updateItem(ShoppingItem item) async {
    _replaceLocal(item);
    notifyListeners();
    await _repository.updateItem(item);
    _lastUsedCategory = item.category;
    await _reloadCurrentItems();
  }

  Future<void> toggleItemChecked(ShoppingItem item) async {
    final updated = item.copyWith(isChecked: !item.isChecked);
    _replaceLocal(updated);
    notifyListeners();
    await _repository.updateItem(updated);
    await _reloadCurrentItems();
  }

  /// حذف فوری از حالت محلی (پیش از پایگاه‌داده) لازم است: Dismissible انتظار
  /// دارد ویجتِ کشیده‌شده در همان فریم از درخت حذف شود.
  ///
  /// حذف، قلم را به «حذف‌شده‌ها» منتقل می‌کند (نه پاک کردن دائمی).
  Future<void> deleteItem(ShoppingItem item) async {
    _items = _items.where((existing) => existing.id != item.id).toList();
    notifyListeners();
    await _repository.moveItemToTrash(item.id!);
    await _reloadCurrentItems();
  }

  /// بازگرداندن قلم از «حذف‌شده‌ها» (یا دکمه «بازگردانی» اسنک‌بار) با همان
  /// شناسه و همه اطلاعات قبلی.
  Future<void> restoreItem(ShoppingItem item) async {
    await _repository.restoreItem(item.id!);
    await _reloadCurrentItems();
  }

  // ---- حذف‌شده‌ها ----

  /// مدت نگهداری اقلام در «حذف‌شده‌ها» پیش از پاک شدن خودکار.
  static const Duration trashRetention = Duration(days: 30);

  List<TrashedShoppingItem> get trashedItems => List.unmodifiable(_trash);
  int get trashCount => _trash.length;

  Future<void> loadTrash() async {
    _trash = await _repository.getTrashedItems();
    notifyListeners();
  }

  Future<void> deleteItemForever(ShoppingItem item) async {
    _trash = _trash.where((entry) => entry.item.id != item.id).toList();
    notifyListeners();
    await _repository.deleteItem(item.id!);
    await _reloadCurrentItems();
  }

  Future<void> emptyTrash() async {
    await _repository.emptyTrash();
    await _reloadCurrentItems();
  }

  Future<void> setAllChecked(bool checked) async {
    final listId = _currentListId;
    if (listId == null) return;
    _items = [for (final item in _items) item.copyWith(isChecked: checked)];
    notifyListeners();
    await _repository.setAllChecked(listId, checked: checked);
    await _reloadCurrentItems();
  }

  /// اقلام خریداری‌شده را به «حذف‌شده‌ها» منتقل می‌کند؛ تعدادشان را برمی‌گرداند.
  Future<int> clearCheckedItems() async {
    final listId = _currentListId;
    if (listId == null) return 0;
    final count = await _repository.moveCheckedItemsToTrash(listId);
    await _reloadCurrentItems();
    return count;
  }

  void setSearchQuery(String query) {
    if (query == _searchQuery) return;
    _searchQuery = query;
    notifyListeners();
  }

  void toggleShowCheckedItems() {
    _showCheckedItems = !_showCheckedItems;
    notifyListeners();
  }

  // ---- مدیریت دسته‌بندی‌ها ----

  Future<ShoppingCategory> addCategory(ShoppingCategory category) async {
    final id = await _repository.insertCategory(category);
    await _reloadCurrentItems();
    return _categories.firstWhere((existing) => existing.id == id);
  }

  Future<void> updateCategory(ShoppingCategory category) async {
    final previous = _categories.firstWhere(
      (existing) => existing.id == category.id,
    );
    await _repository.updateCategory(category, previousName: previous.name);
    if (_lastUsedCategory == previous.name) _lastUsedCategory = category.name;
    await _reloadCurrentItems();
  }

  Future<void> deleteCategory(ShoppingCategory category) async {
    await _repository.deleteCategory(category);
    await _reloadCurrentItems();
  }

  /// جابه‌جایی دسته (onReorderItem در ReorderableListView: [newIndex] جایگاه
  /// نهایی پس از برداشتن قلم است)؛ حالت محلی فوراً به‌روز می‌شود.
  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    final reordered = [..._categories];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    _categories = reordered;
    notifyListeners();
    await _repository.reorderCategories([
      for (final category in reordered) category.id!,
    ]);
    await _reloadCurrentItems();
  }

  // ---- اشتراک‌گذاری ----

  /// متن قابل اشتراک لیست (مثلاً برای ارسال در پیام‌رسان).
  Future<String> buildShareText(ShoppingList list) async {
    final items = await _repository.getItemsByListId(list.id!);
    final buffer = StringBuffer('🛒 ${list.name}\n');
    final groups = _groupItems(items.where((item) => !item.isChecked));
    for (final group in groups) {
      buffer.write('\n${group.name}:\n');
      for (final item in group.items) {
        buffer.write('☐ ${_shareLine(item)}\n');
      }
    }
    final checked = items.where((item) => item.isChecked).toList();
    if (checked.isNotEmpty) {
      buffer.write('\nخریداری‌شده:\n');
      for (final item in checked) {
        buffer.write('☑ ${_shareLine(item)}\n');
      }
    }
    final summary = ShoppingListSummary.fromItems(items);
    if (summary.hasPrices) {
      buffer.write('\nجمع تقریبی: ${formatTooman(summary.estimatedTotal)}\n');
    }
    return buffer.toString().trimRight();
  }

  String _shareLine(ShoppingItem item) {
    final parts = <String>[item.name];
    final quantity = describeQuantity(item);
    if (quantity != null) parts.add(quantity);
    var line = parts.join(' — ');
    final note = item.note?.trim();
    if (note != null && note.isNotEmpty) line += ' ($note)';
    if (item.isImportant) line += ' ⭐';
    return line;
  }

  // ---- کمکی ----

  void _replaceLocal(ShoppingItem updated) {
    _items = [
      for (final item in _items) item.id == updated.id ? updated : item,
    ];
  }

  Iterable<ShoppingItem> _filtered(Iterable<ShoppingItem> items) {
    final filter = categoryFilter;
    if (filter != null) {
      items = items.where((item) => item.category == filter);
    }
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items.where(
      (item) =>
          item.name.toLowerCase().contains(query) ||
          (item.note?.toLowerCase().contains(query) ?? false),
    );
  }

  List<ShoppingItemGroup> _groupItems(Iterable<ShoppingItem> items) {
    final grouped = <String, List<ShoppingItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    return [
      for (final name in _sortedCategoryNames(grouped.keys))
        ShoppingItemGroup(
          name: name,
          category: categoryByName(name),
          items: grouped[name]!..sort(_importantFirst),
        ),
    ];
  }

  /// نام دسته‌ها به ترتیب تعریف‌شده در مدیریت دسته‌بندی‌ها؛ دسته‌های ناشناخته
  /// (نه در جدول دسته‌ها) در انتها و به ترتیب الفبا.
  List<String> _sortedCategoryNames(Iterable<String> names) {
    final order = {
      for (var i = 0; i < _categories.length; i++) _categories[i].name: i,
    };
    const unknown = 1 << 30;
    return names.toList()..sort((a, b) {
      final byOrder = (order[a] ?? unknown).compareTo(order[b] ?? unknown);
      return byOrder != 0 ? byOrder : a.compareTo(b);
    });
  }

  static int _importantFirst(ShoppingItem a, ShoppingItem b) {
    if (a.isImportant != b.isImportant) return a.isImportant ? -1 : 1;
    return (a.id ?? 0).compareTo(b.id ?? 0);
  }
}
