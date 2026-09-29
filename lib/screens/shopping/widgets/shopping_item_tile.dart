import 'package:flutter/material.dart';

import '../../../models/shopping_item.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/shopping_format.dart';

class ShoppingItemTile extends StatelessWidget {
  const ShoppingItemTile({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final ShoppingItem item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  /// با کشیدن ردیف به کنار صدا زده می‌شود.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final quantity = describeQuantity(item);
    final lineTotal = item.lineTotal;
    final note = item.note?.trim();
    final details = [
      ?quantity,
      if (lineTotal != null) formatTooman(lineTotal),
    ].join(' • ');

    return Dismissible(
      key: ValueKey('shopping-item-${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: scheme.errorContainer,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'حذف',
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.delete_outline, color: scheme.onErrorContainer),
          ],
        ),
      ),
      child: Semantics(
        checked: item.isChecked,
        button: true,
        label: '${item.name}، ${item.isChecked ? 'خریداری‌شده' : 'باقی‌مانده'}',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          color: item.isChecked
              ? scheme.primaryContainer.withValues(alpha: 0.25)
              : scheme.surface.withValues(alpha: 0),
          // Material شفاف لازم است تا جوهر لمس ListTile روی رنگ پس‌زمینه دیده شود.
          child: Material(
            type: MaterialType.transparency,
            child: ListTile(
              contentPadding: const EdgeInsetsDirectional.only(
                start: 8,
                end: 4,
              ),
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
              title: Row(
                children: [
                  Flexible(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      style:
                          (item.isChecked
                              ? theme.textTheme.bodyLarge?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  color: scheme.outline,
                                )
                              : theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: item.isImportant
                                      ? FontWeight.w700
                                      : null,
                                )) ??
                          const TextStyle(),
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (item.isImportant && !item.isChecked) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: Colors.amber,
                    ),
                  ],
                ],
              ),
              subtitle: (details.isEmpty && (note == null || note.isEmpty))
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (details.isNotEmpty)
                          Text(
                            details,
                            style: TextStyle(
                              color: item.isChecked
                                  ? scheme.outline
                                  : scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (note != null && note.isNotEmpty)
                          Text(
                            note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'ویرایش آیتم',
                onPressed: onEdit,
              ),
              onTap: onToggle,
              onLongPress: onEdit,
            ),
          ),
        ),
      ),
    );
  }
}
