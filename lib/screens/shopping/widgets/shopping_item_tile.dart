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
    return Semantics(
      checked: item.isChecked,
      button: true,
      label: '${item.name}، ${item.isChecked ? 'خریداری‌شده' : 'باقی‌مانده'}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        color: item.isChecked
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
            : theme.colorScheme.surface.withValues(alpha: 0),
        child: ListTile(
          leading: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Checkbox(
              key: ValueKey(item.isChecked),
              value: item.isChecked,
              onChanged: (_) => onToggle(),
            ),
          ),
          title: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style:
                (item.isChecked
                    ? theme.textTheme.bodyLarge?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: theme.colorScheme.outline,
                      )
                    : theme.textTheme.bodyLarge) ??
                const TextStyle(),
            child: Text(item.name),
          ),
          subtitle: (item.quantity == null || item.quantity!.isEmpty)
              ? null
              : Text(item.quantity!),
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'حذف آیتم',
            onPressed: onDelete,
          ),
          onTap: onToggle,
        ),
      ),
    );
  }
}
