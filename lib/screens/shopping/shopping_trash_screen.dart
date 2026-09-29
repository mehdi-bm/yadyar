import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/shopping_item.dart';
import '../../providers/shopping_provider.dart';
import '../../repositories/shopping_list_repository.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/shopping_format.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import 'widgets/shopping_visuals.dart';

/// «حذف‌شده‌ها»: اقلام خرید حذف‌شده از همه لیست‌ها، با امکان بازیابی یا حذف
/// دائمی. اقلام پس از [ShoppingProvider.trashRetention] خودکار پاک می‌شوند.
class ShoppingTrashScreen extends StatefulWidget {
  const ShoppingTrashScreen({super.key});

  @override
  State<ShoppingTrashScreen> createState() => _ShoppingTrashScreenState();
}

class _ShoppingTrashScreenState extends State<ShoppingTrashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ShoppingProvider>().loadTrash();
    });
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), showCloseIcon: true));
  }

  Future<void> _restore(TrashedShoppingItem entry) async {
    await context.read<ShoppingProvider>().restoreItem(entry.item);
    _showMessage('«${entry.item.name}» به لیست «${entry.listName}» برگشت');
  }

  Future<void> _deleteForever(ShoppingItem item) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف برای همیشه',
      message: '«${item.name}» برای همیشه حذف می‌شود و دیگر قابل بازیابی نیست.',
      confirmLabel: 'حذف دائمی',
    );
    if (confirmed && mounted) {
      await context.read<ShoppingProvider>().deleteItemForever(item);
    }
  }

  Future<void> _emptyTrash() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'خالی کردن حذف‌شده‌ها',
      message:
          'همه اقلام این بخش برای همیشه حذف می‌شوند و دیگر قابل بازیابی نیستند.',
      confirmLabel: 'خالی کن',
    );
    if (confirmed && mounted) {
      await context.read<ShoppingProvider>().emptyTrash();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShoppingProvider>();
    final trash = provider.trashedItems;
    final theme = Theme.of(context);

    // گروه‌بندی بر اساس نام لیست، با حفظ ترتیب (جدیدترین حذف اول).
    final byList = <String, List<TrashedShoppingItem>>{};
    for (final entry in trash) {
      byList.putIfAbsent(entry.listName, () => []).add(entry);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('حذف‌شده‌ها'),
        actions: [
          if (trash.isNotEmpty)
            TextButton.icon(
              onPressed: _emptyTrash,
              icon: Icon(
                Icons.delete_forever_outlined,
                color: theme.colorScheme.error,
              ),
              label: Text(
                'خالی کردن',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
        ],
      ),
      body: trash.isEmpty
          ? const EmptyStateView(
              icon: Icons.restore_from_trash_outlined,
              message:
                  'بخش حذف‌شده‌ها خالی است.\nاقلامی که از لیست‌ها حذف کنید اینجا نگه داشته می‌شوند تا بتوانید بازیابی‌شان کنید.',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'اقلام حذف‌شده پس از ${formatNumber(ShoppingProvider.trashRetention.inDays)} روز خودکار برای همیشه پاک می‌شوند.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final group in byList.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            group.key,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final entry in group.value)
                    _TrashTile(
                      entry: entry,
                      onRestore: () => _restore(entry),
                      onDeleteForever: () => _deleteForever(entry.item),
                    ),
                ],
              ],
            ),
    );
  }
}

class _TrashTile extends StatelessWidget {
  const _TrashTile({
    required this.entry,
    required this.onRestore,
    required this.onDeleteForever,
  });

  final TrashedShoppingItem entry;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ShoppingProvider>();
    final scheme = Theme.of(context).colorScheme;
    final item = entry.item;
    final quantity = describeQuantity(item);
    final details = [
      item.category,
      ?quantity,
      if (item.deletedAt != null) 'حذف: ${formatJalaliDate(item.deletedAt!)}',
    ].join(' • ');

    return ListTile(
      leading: CategoryAvatar(
        category: provider.categoryByName(item.category),
        size: 38,
      ),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        details,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.restore, color: scheme.primary),
            tooltip: 'بازگردانی',
            onPressed: onRestore,
          ),
          IconButton(
            icon: Icon(Icons.delete_forever_outlined, color: scheme.error),
            tooltip: 'حذف برای همیشه',
            onPressed: onDeleteForever,
          ),
        ],
      ),
    );
  }
}
