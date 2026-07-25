import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/shopping_list.dart';
import '../../providers/shopping_provider.dart';
import '../../widgets/empty_state.dart';
import 'widgets/add_item_sheet.dart';
import 'widgets/shopping_item_tile.dart';

class ShoppingListDetailScreen extends StatefulWidget {
  const ShoppingListDetailScreen({super.key, required this.shoppingList});

  final ShoppingList shoppingList;

  @override
  State<ShoppingListDetailScreen> createState() =>
      _ShoppingListDetailScreenState();
}

class _ShoppingListDetailScreenState extends State<ShoppingListDetailScreen> {
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
  Widget build(BuildContext context) {
    final provider = context.watch<ShoppingProvider>();
    final grouped = provider.uncheckedItemsByCategory;
    final checked = provider.checkedItems;
    final isEmpty = grouped.isEmpty && checked.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.shoppingList.name),
        actions: [
          if (provider.hasCheckedItems)
            IconButton(
              icon: const Icon(Icons.cleaning_services_outlined),
              tooltip: 'پاک کردن آیتم‌های خریداری‌شده',
              onPressed: () => provider.clearCheckedItems(),
            ),
        ],
      ),
      body: provider.isLoadingItems
          ? const Center(child: CircularProgressIndicator())
          : isEmpty
          ? EmptyStateView(
              icon: Icons.playlist_add_outlined,
              message: 'این لیست هنوز آیتمی ندارد.\nبرای شروع، دکمه + را بزنید.',
              actionLabel: 'افزودن اولین آیتم',
              onAction: () => showAddItemSheet(context),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final entry in grouped.entries) ...[
                  _CategoryHeader(title: entry.key),
                  for (final item in entry.value)
                    ShoppingItemTile(
                      item: item,
                      onToggle: () => provider.toggleItemChecked(item),
                      onDelete: () => provider.deleteItem(item),
                    ),
                ],
                if (checked.isNotEmpty) ...[
                  const _CategoryHeader(title: 'خریداری‌شده'),
                  for (final item in checked)
                    ShoppingItemTile(
                      item: item,
                      onToggle: () => provider.toggleItemChecked(item),
                      onDelete: () => provider.deleteItem(item),
                    ),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddItemSheet(context),
        tooltip: 'افزودن آیتم',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
