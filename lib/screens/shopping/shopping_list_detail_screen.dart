import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/shopping_category.dart';
import '../../models/shopping_item.dart';
import '../../models/shopping_list.dart';
import '../../providers/shopping_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/empty_state.dart';
import 'shopping_categories_screen.dart';
import 'shopping_trash_screen.dart';
import 'widgets/item_form_sheet.dart';
import 'widgets/shopping_item_tile.dart';
import 'widgets/shopping_list_actions.dart';
import 'widgets/shopping_list_card.dart';
import 'widgets/shopping_visuals.dart';

enum _DetailAction {
  toggleChecked,
  checkAll,
  uncheckAll,
  clearChecked,
  share,
  duplicate,
  editList,
  categories,
  trash,
  deleteList,
}

class ShoppingListDetailScreen extends StatefulWidget {
  const ShoppingListDetailScreen({super.key, required this.shoppingList});

  final ShoppingList shoppingList;

  @override
  State<ShoppingListDetailScreen> createState() =>
      _ShoppingListDetailScreenState();
}

class _ShoppingListDetailScreenState extends State<ShoppingListDetailScreen> {
  final _quickAddController = TextEditingController();
  final _quickAddFocus = FocusNode();
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ShoppingProvider>().loadItems(widget.shoppingList.id!);
      }
    });
  }

  @override
  void dispose() {
    _quickAddController.dispose();
    _quickAddFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// نسخه به‌روز لیست (مثلاً پس از ویرایش نام/رنگ)، یا همان نسخه اولیه.
  ShoppingList _currentList(ShoppingProvider provider) =>
      provider.listById(widget.shoppingList.id!) ?? widget.shoppingList;

  Future<void> _quickAdd() async {
    final text = _quickAddController.text;
    if (text.trim().isEmpty) return;
    _quickAddController.clear();
    await context.read<ShoppingProvider>().quickAddItem(text);
    _quickAddFocus.requestFocus();
  }

  void _deleteWithUndo(ShoppingItem item) {
    context.read<ShoppingProvider>().deleteItem(item);
    _showUndo(item);
  }

  void _showUndo(ShoppingItem item) {
    final provider = context.read<ShoppingProvider>();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('«${item.name}» به حذف‌شده‌ها منتقل شد'),
          // اسنک‌بار دارای action به‌طور پیش‌فرض خودکار بسته نمی‌شود (persist)؛
          // اینجا باید پس از چند ثانیه برود و کاربر هم بتواند ببندد.
          persist: false,
          duration: const Duration(seconds: 4),
          showCloseIcon: true,
          action: SnackBarAction(
            label: 'بازگردانی',
            onPressed: () => provider.restoreItem(item),
          ),
        ),
      );
  }

  void _openTrash() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ShoppingTrashScreen()),
    );
  }

  Future<void> _edit(ShoppingItem item) async {
    final deleted = await showItemFormSheet(context, item: item);
    if (deleted != null && mounted) _showUndo(deleted);
  }

  void _setSearching(bool value) {
    setState(() => _isSearching = value);
    if (!value) {
      _searchController.clear();
      context.read<ShoppingProvider>().setSearchQuery('');
    }
  }

  Future<void> _onAction(_DetailAction action) async {
    final provider = context.read<ShoppingProvider>();
    final list = _currentList(provider);
    switch (action) {
      case _DetailAction.toggleChecked:
        provider.toggleShowCheckedItems();
      case _DetailAction.checkAll:
        await provider.setAllChecked(true);
      case _DetailAction.uncheckAll:
        await provider.setAllChecked(false);
      case _DetailAction.clearChecked:
        // قابل بازیابی است (به «حذف‌شده‌ها» می‌رود)، پس تأیید لازم نیست.
        final count = await provider.clearCheckedItems();
        if (!mounted || count == 0) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                '${formatNumber(count)} مورد خریداری‌شده به حذف‌شده‌ها منتقل شد',
              ),
              persist: false,
              duration: const Duration(seconds: 4),
              showCloseIcon: true,
              action: SnackBarAction(label: 'مشاهده', onPressed: _openTrash),
            ),
          );
      case _DetailAction.trash:
        _openTrash();
      case _DetailAction.share:
        await runShoppingListAction(context, list, ShoppingListAction.share);
      case _DetailAction.duplicate:
        await runShoppingListAction(
          context,
          list,
          ShoppingListAction.duplicate,
        );
      case _DetailAction.editList:
        await runShoppingListAction(context, list, ShoppingListAction.edit);
      case _DetailAction.categories:
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const ShoppingCategoriesScreen()),
        );
      case _DetailAction.deleteList:
        final deleted = await runShoppingListAction(
          context,
          list,
          ShoppingListAction.delete,
        );
        if (deleted && mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShoppingProvider>();
    final list = _currentList(provider);
    final accent = list.colorValue != null
        ? Color(list.colorValue!)
        : Theme.of(context).colorScheme.primary;
    final groups = provider.uncheckedGroups;
    final checked = provider.checkedItems;
    final summary = provider.currentSummary;
    final isFiltering = provider.searchQuery.trim().isNotEmpty;
    final categoryCounts = provider.categoryCounts;
    final hasVisibleResults =
        groups.isNotEmpty || (checked.isNotEmpty && provider.showCheckedItems);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'جستجو در این لیست...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                onChanged: provider.setSearchQuery,
              )
            : Text(list.name),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? 'بستن جستجو' : 'جستجو',
            onPressed: () => _setSearching(!_isSearching),
          ),
          PopupMenuButton<_DetailAction>(
            tooltip: 'گزینه‌های بیشتر',
            onSelected: _onAction,
            itemBuilder: (context) => [
              if (provider.hasCheckedItems)
                _menuItem(
                  _DetailAction.toggleChecked,
                  provider.showCheckedItems
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  provider.showCheckedItems
                      ? 'پنهان کردن خریداری‌شده‌ها'
                      : 'نمایش خریداری‌شده‌ها',
                ),
              if (provider.hasUncheckedItems)
                _menuItem(
                  _DetailAction.checkAll,
                  Icons.done_all,
                  'علامت‌زدن همه',
                ),
              if (provider.hasCheckedItems)
                _menuItem(
                  _DetailAction.uncheckAll,
                  Icons.remove_done,
                  'برداشتن علامت همه',
                ),
              if (provider.hasCheckedItems)
                _menuItem(
                  _DetailAction.clearChecked,
                  Icons.cleaning_services_outlined,
                  'حذف خریداری‌شده‌ها',
                ),
              const PopupMenuDivider(),
              _menuItem(
                _DetailAction.share,
                Icons.share_outlined,
                'اشتراک‌گذاری لیست',
              ),
              _menuItem(
                _DetailAction.duplicate,
                Icons.copy_all_outlined,
                'کپی لیست',
              ),
              _menuItem(
                _DetailAction.editList,
                Icons.edit_outlined,
                'ویرایش لیست',
              ),
              _menuItem(
                _DetailAction.categories,
                Icons.category_outlined,
                'مدیریت دسته‌بندی‌ها',
              ),
              _menuItem(
                _DetailAction.trash,
                Icons.restore_from_trash_outlined,
                provider.trashCount > 0
                    ? 'حذف‌شده‌ها (${formatNumber(provider.trashCount)})'
                    : 'حذف‌شده‌ها',
              ),
              _menuItem(
                _DetailAction.deleteList,
                Icons.delete_outline,
                'حذف لیست',
                color: Theme.of(context).colorScheme.error,
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _QuickAddBar(
            controller: _quickAddController,
            focusNode: _quickAddFocus,
            onSubmit: _quickAdd,
          ),
          if (categoryCounts.length > 1)
            _CategoryFilterBar(
              counts: categoryCounts,
              selected: provider.categoryFilter,
              totalRemaining: summary.remainingCount,
              onSelected: provider.setCategoryFilter,
            ),
          Expanded(
            child: provider.isLoadingItems && !provider.hasItems
                ? const Center(child: CircularProgressIndicator())
                : !provider.hasItems
                ? EmptyStateView(
                    icon: Icons.playlist_add_outlined,
                    message:
                        'این لیست هنوز آیتمی ندارد.\nنام آیتم را در کادر بالا بنویسید یا دکمه + را بزنید.',
                    actionLabel: 'افزودن اولین آیتم',
                    onAction: () => showItemFormSheet(context),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 96),
                    children: [
                      if (!isFiltering)
                        _ProgressHeader(summary: summary, accent: accent),
                      if (isFiltering && !hasVisibleResults)
                        const _NoResults(
                          message: 'آیتمی با این عبارت پیدا نشد.',
                        )
                      else if (provider.categoryFilter != null &&
                          !hasVisibleResults)
                        const _NoResults(
                          icon: Icons.task_alt,
                          message: 'همه اقلام این دسته خریداری شده است.',
                        ),
                      for (final group in groups) ...[
                        _CategoryHeader(
                          title: group.name,
                          count: group.items.length,
                          avatar: CategoryAvatar(
                            category: group.category,
                            size: 28,
                          ),
                        ),
                        for (final item in group.items)
                          ShoppingItemTile(
                            item: item,
                            onToggle: () => provider.toggleItemChecked(item),
                            onEdit: () => _edit(item),
                            onDelete: () => _deleteWithUndo(item),
                          ),
                      ],
                      if (checked.isNotEmpty && provider.showCheckedItems) ...[
                        _CategoryHeader(
                          title: 'خریداری‌شده',
                          count: checked.length,
                          avatar: Icon(Icons.task_alt, color: accent, size: 24),
                        ),
                        for (final item in checked)
                          ShoppingItemTile(
                            item: item,
                            onToggle: () => provider.toggleItemChecked(item),
                            onEdit: () => _edit(item),
                            onDelete: () => _deleteWithUndo(item),
                          ),
                      ],
                      if (checked.isNotEmpty && !provider.showCheckedItems)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: provider.toggleShowCheckedItems,
                              icon: const Icon(Icons.visibility_outlined),
                              label: Text(
                                'نمایش ${checked.length} مورد خریداری‌شده',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showItemFormSheet(context),
        tooltip: 'افزودن آیتم',
        child: const Icon(Icons.add),
      ),
    );
  }

  PopupMenuItem<_DetailAction> _menuItem(
    _DetailAction value,
    IconData icon,
    String label, {
    Color? color,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

/// کادر «افزودن سریع»: فقط نام را بنویسید و Enter بزنید.
class _QuickAddBar extends StatelessWidget {
  const _QuickAddBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onSubmit(),
        decoration: InputDecoration(
          hintText: 'افزودن سریع؛ مثلاً «نان» و Enter',
          prefixIcon: const Icon(Icons.add_task),
          isDense: true,
          suffixIcon: IconButton(
            icon: const Icon(Icons.send_rounded),
            tooltip: 'افزودن سریع',
            onPressed: onSubmit,
          ),
        ),
      ),
    );
  }
}

/// پیشرفت خرید و جمع قیمت‌های لیست.
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.summary, required this.accent});

  final ShoppingListSummary summary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final percent = (summary.progress * 100).round();

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 58,
                  height: 58,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: summary.progress),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: value,
                          strokeWidth: 6,
                          color: accent,
                          backgroundColor: accent.withValues(alpha: 0.15),
                          strokeCap: StrokeCap.round,
                        ),
                        Center(
                          child: Text(
                            '${formatNumber(percent)}٪',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.isCompleted
                            ? 'خرید این لیست کامل شد 🎉'
                            : '${formatNumber(summary.checkedCount)} از ${formatNumber(summary.totalCount)} مورد خریداری شد',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary.isCompleted
                            ? 'می‌توانید از منو، علامت‌ها را بردارید و لیست را دوباره استفاده کنید.'
                            : '${formatNumber(summary.remainingCount)} مورد دیگر باقی مانده است.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (summary.hasPrices) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  _PriceStat(
                    label: 'جمع کل',
                    value: summary.estimatedTotal,
                    color: scheme.onSurface,
                  ),
                  _PriceStat(
                    label: 'خریداری‌شده',
                    value: summary.spentTotal,
                    color: accent,
                  ),
                  _PriceStat(
                    label: 'باقی‌مانده',
                    value: summary.estimatedTotal - summary.spentTotal,
                    color: scheme.error,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriceStat extends StatelessWidget {
  const _PriceStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatNumber(value),
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text('تومان', style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.title,
    required this.count,
    required this.avatar,
  });

  final String title;
  final int count;
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(formatNumber(count), style: theme.textTheme.labelSmall),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.message, this.icon = Icons.search_off});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 48, color: scheme.outline),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// نوار افقی فیلتر دسته‌ها: «همه» و فقط دسته‌هایی که در این لیست آیتم دارند.
/// لمس دوباره دسته انتخاب‌شده، فیلتر را برمی‌دارد.
class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
    required this.counts,
    required this.selected,
    required this.totalRemaining,
    required this.onSelected,
  });

  final List<ShoppingCategoryCount> counts;
  final String? selected;
  final int totalRemaining;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _FilterChip(
            label: 'همه',
            count: totalRemaining,
            icon: Icons.apps_rounded,
            color: scheme.primary,
            isSelected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final entry in counts)
            _FilterChip(
              label: entry.name,
              count: entry.remainingCount,
              icon: shoppingCategoryIcon(entry.category?.iconKey),
              color: Color(
                entry.category?.colorValue ??
                    ShoppingCategory.defaultColorValue,
              ),
              isSelected: selected == entry.name,
              onTap: () =>
                  onSelected(selected == entry.name ? null : entry.name),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '$label، ${formatNumber(count)} مورد',
        // متن داخل چیپ دوباره خوانده نشود؛ برچسب بالا کامل است.
        excludeSemantics: true,
        child: Material(
          color: isSelected
              ? color.withValues(alpha: 0.22)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: StadiumBorder(
            side: BorderSide(
              color: isSelected ? color : scheme.outlineVariant,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      formatNumber(count),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isSelected ? Colors.white : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
