import 'package:flutter/material.dart';

import '../../../models/shopping_item.dart';

class ShoppingItemTile extends StatelessWidget {
  const ShoppingItemTile({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  final ShoppingItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Checkbox(value: item.isChecked, onChanged: (_) => onToggle()),
      title: Text(
        item.name,
        style: item.isChecked
            ? theme.textTheme.bodyLarge?.copyWith(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.outline,
              )
            : theme.textTheme.bodyLarge,
      ),
      subtitle: (item.quantity == null || item.quantity!.isEmpty) ? null : Text(item.quantity!),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 20),
        tooltip: 'حذف آیتم',
        onPressed: onDelete,
      ),
      onTap: onToggle,
    );
  }
}
