import 'package:flutter/material.dart';

import '../../../models/shopping_list.dart';
import '../../../providers/shopping_provider.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/date_formatter.dart';

enum ShoppingListAction { edit, duplicate, share, delete }

class ShoppingListCard extends StatelessWidget {
  const ShoppingListCard({
    super.key,
    required this.shoppingList,
    required this.summary,
    required this.onTap,
    required this.onAction,
  });

  final ShoppingList shoppingList;
  final ShoppingListSummary summary;
  final VoidCallback onTap;
  final ValueChanged<ShoppingListAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = shoppingList.colorValue != null
        ? Color(shoppingList.colorValue!)
        : scheme.primary;
    final isCompleted = summary.isCompleted;

    final String status;
    if (summary.totalCount == 0) {
      status = 'بدون آیتم';
    } else if (isCompleted) {
      status = 'همه ${formatNumber(summary.totalCount)} مورد خریداری شد';
    } else {
      status =
          '${formatNumber(summary.remainingCount)} مورد باقی‌مانده از ${formatNumber(summary.totalCount)}';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => onAction(ShoppingListAction.edit),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 4, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isCompleted
                                  ? Icons.task_alt
                                  : Icons.shopping_cart_outlined,
                              color: accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shoppingList.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  status,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isCompleted
                                        ? accent
                                        : scheme.onSurfaceVariant,
                                    fontWeight: isCompleted
                                        ? FontWeight.w600
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<ShoppingListAction>(
                            tooltip: 'گزینه‌های لیست',
                            onSelected: onAction,
                            itemBuilder: (context) => [
                              _menuItem(
                                ShoppingListAction.edit,
                                Icons.edit_outlined,
                                'ویرایش',
                              ),
                              _menuItem(
                                ShoppingListAction.duplicate,
                                Icons.copy_all_outlined,
                                'کپی لیست',
                              ),
                              _menuItem(
                                ShoppingListAction.share,
                                Icons.share_outlined,
                                'اشتراک‌گذاری',
                              ),
                              _menuItem(
                                ShoppingListAction.delete,
                                Icons.delete_outline,
                                'حذف',
                                color: scheme.error,
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (summary.totalCount > 0) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: summary.progress),
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) =>
                                LinearProgressIndicator(
                                  value: value,
                                  minHeight: 6,
                                  color: accent,
                                  backgroundColor: accent.withValues(
                                    alpha: 0.15,
                                  ),
                                ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _Meta(
                            icon: Icons.calendar_today_outlined,
                            text: formatJalaliDate(shoppingList.createdAt),
                          ),
                          if (summary.hasPrices)
                            _Meta(
                              icon: Icons.payments_outlined,
                              text: formatTooman(summary.estimatedTotal),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<ShoppingListAction> _menuItem(
    ShoppingListAction value,
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

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
