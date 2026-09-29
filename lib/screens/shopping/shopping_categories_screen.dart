import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/shopping_category.dart';
import '../../providers/shopping_provider.dart';
import '../../widgets/confirm_dialog.dart';
import 'widgets/category_form_dialog.dart';
import 'widgets/shopping_visuals.dart';

/// مدیریت دسته‌بندی‌های خرید: افزودن، ویرایش (نام/آیکون/رنگ)، حذف و ترتیب.
class ShoppingCategoriesScreen extends StatefulWidget {
  const ShoppingCategoriesScreen({super.key});

  @override
  State<ShoppingCategoriesScreen> createState() =>
      _ShoppingCategoriesScreenState();
}

class _ShoppingCategoriesScreenState extends State<ShoppingCategoriesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ShoppingProvider>().loadCategories();
    });
  }

  Future<void> _delete(ShoppingCategory category) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف دسته «${category.name}»',
      message:
          'اقلام این دسته حذف نمی‌شوند و به دسته «${ShoppingCategory.fallbackName}» منتقل می‌شوند.',
    );
    if (confirmed && mounted) {
      await context.read<ShoppingProvider>().deleteCategory(category);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShoppingProvider>();
    final categories = provider.categories;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('دسته‌بندی‌های خرید')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(
                  Icons.drag_indicator,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'برای تغییر ترتیب نمایش در لیست‌ها، دسته‌ها را بکشید.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.only(bottom: 88, top: 4),
              itemCount: categories.length,
              onReorderItem: provider.reorderCategories,
              itemBuilder: (context, index) {
                final category = categories[index];
                return Card(
                  key: ValueKey('category-${category.id}'),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: ListTile(
                    leading: CategoryAvatar(category: category, size: 40),
                    title: Text(
                      category.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: category.isFallback
                        ? const Text('دسته پیش‌فرض (قابل حذف نیست)')
                        : null,
                    // لمس خود ردیف ویرایش را باز می‌کند؛ دکمه ویرایش جدا جای
                    // نام دسته را تنگ می‌کرد.
                    onTap: () =>
                        showCategoryFormDialog(context, category: category),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!category.isFallback)
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: theme.colorScheme.error,
                            ),
                            tooltip: 'حذف دسته',
                            onPressed: () => _delete(category),
                          ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.drag_handle),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCategoryFormDialog(context),
        tooltip: 'دسته جدید',
        icon: const Icon(Icons.add),
        label: const Text('دسته جدید'),
      ),
    );
  }
}
