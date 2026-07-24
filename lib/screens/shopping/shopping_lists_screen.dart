import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/shopping_list.dart';
import '../../providers/shopping_provider.dart';
import '../../theme/app_theme.dart';
import 'shopping_list_detail_screen.dart';
import 'widgets/shopping_list_actions.dart';
import 'widgets/shopping_list_card.dart';

class ShoppingListsScreen extends StatefulWidget {
  const ShoppingListsScreen({super.key});

  @override
  State<ShoppingListsScreen> createState() => _ShoppingListsScreenState();
}

class _ShoppingListsScreenState extends State<ShoppingListsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ShoppingProvider>().loadLists();
    });
  }

  Future<void> _addList(BuildContext context) async {
    final name = await showListNameDialog(context, title: 'لیست خرید جدید');
    if (name != null && context.mounted) {
      await context.read<ShoppingProvider>().addList(name);
    }
  }

  Future<void> _handleLongPress(BuildContext context, ShoppingList list) async {
    final provider = context.read<ShoppingProvider>();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('ویرایش نام'),
              onTap: () => Navigator.of(ctx).pop('rename'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: Text(
                'حذف',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) return;
    switch (action) {
      case 'rename':
        final newName = await showListNameDialog(
          context,
          title: 'ویرایش نام لیست',
          initialName: list.name,
        );
        if (newName != null) await provider.renameList(list, newName);
      case 'delete':
        final confirmed = await showDeleteShoppingListConfirmation(context);
        if (confirmed) await provider.deleteList(list.id!);
    }
  }

  void _openDetail(BuildContext context, ShoppingList list) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ShoppingListDetailScreen(shoppingList: list),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShoppingProvider>();
    final lists = provider.lists;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: const [ThemeModeButton()],
      ),
      body: provider.isLoadingLists
          ? const Center(child: CircularProgressIndicator())
          : lists.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 88),
              itemCount: lists.length,
              itemBuilder: (context, index) {
                final list = lists[index];
                return ShoppingListCard(
                  shoppingList: list,
                  remainingCount: provider.remainingCountFor(list.id!),
                  onTap: () => _openDetail(context, list),
                  onLongPress: () => _handleLongPress(context, list),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addList(context),
        tooltip: 'لیست جدید',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'هنوز لیست خریدی ثبت نشده است.\nبرای شروع، دکمه + را بزنید.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
