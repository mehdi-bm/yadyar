import 'package:flutter/material.dart';

import '../../../models/subscription.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/date_formatter.dart';
import '../subscription_edit_screen.dart'
    show subscriptionOccurrenceUnitLabels, subscriptionRepeatTypeLabels;
import 'bill_status.dart';
import 'subscription_actions.dart';

const Map<String, IconData> _categoryIcons = {
  'اینترنت': Icons.wifi,
  'برق': Icons.bolt_outlined,
  'آب': Icons.water_drop_outlined,
  'گاز': Icons.local_fire_department_outlined,
  'تلفن همراه': Icons.smartphone_outlined,
  'اشتراک نرم‌افزار': Icons.apps_outlined,
  'بیمه': Icons.shield_outlined,
  'اجاره': Icons.home_outlined,
};

IconData billCategoryIcon(String category) =>
    _categoryIcons[category] ?? Icons.receipt_long_outlined;

class SubscriptionCard extends StatefulWidget {
  const SubscriptionCard({
    super.key,
    required this.subscription,
    required this.onTap,
    required this.onAction,
  });

  final Subscription subscription;
  final VoidCallback onTap;
  final ValueChanged<BillAction> onAction;

  @override
  State<SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<SubscriptionCard> {
  bool _showPaidFeedback = false;

  @override
  void didUpdateWidget(SubscriptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // پس از ثبت (یا بازگردانی) پرداخت، کارت با داده جدید دوباره ساخته می‌شود.
    if (oldWidget.subscription.dueDate != widget.subscription.dueDate ||
        oldWidget.subscription.isPaid != widget.subscription.isPaid) {
      _showPaidFeedback = false;
    }
  }

  Future<void> _markAsPaid() async {
    if (_showPaidFeedback) return;
    setState(() => _showPaidFeedback = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (mounted) widget.onAction(BillAction.pay);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subscription = widget.subscription;
    final status = billStatusOf(subscription);
    final statusColor = billStatusColor(context, status);
    final countdown = dueCountdownLabel(subscription);
    final identifier = subscription.billIdentifier;
    final hasIdentifier = identifier != null && identifier.isNotEmpty;
    final remaining = subscription.remainingOccurrences;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: () => widget.onAction(BillAction.payCustom),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: statusColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 4, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              billCategoryIcon(subscription.category),
                              size: 22,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subscription.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${subscription.category} • ${subscriptionRepeatTypeLabels[subscription.repeatType]}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          _StatusChip(
                            label: billStatusLabel(status),
                            color: statusColor,
                          ),
                          PopupMenuButton<BillAction>(
                            tooltip: 'گزینه‌های قبض',
                            onSelected: widget.onAction,
                            itemBuilder: (context) => [
                              if (!subscription.isPaid)
                                _menuItem(
                                  BillAction.payCustom,
                                  Icons.edit_note,
                                  'ثبت پرداخت با مبلغ/تاریخ دیگر',
                                ),
                              _menuItem(
                                BillAction.edit,
                                Icons.edit_outlined,
                                'ویرایش',
                              ),
                              _menuItem(
                                BillAction.history,
                                Icons.history,
                                'تاریخچه پرداخت‌ها',
                              ),
                              if (hasIdentifier)
                                _menuItem(
                                  BillAction.copyIdentifier,
                                  Icons.copy,
                                  'کپی شناسه قبض',
                                ),
                              _menuItem(
                                BillAction.delete,
                                Icons.delete_outline,
                                'حذف',
                                color: scheme.error,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatTooman(subscription.amount),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'سررسید: ${formatJalaliDate(subscription.dueDate)}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    if (countdown != null)
                                      _Pill(
                                        text: countdown,
                                        color: statusColor,
                                      ),
                                    if (!subscription.isPaid &&
                                        remaining != null &&
                                        remaining > 0)
                                      _Pill(
                                        text:
                                            '${formatNumber(remaining)} ${subscriptionOccurrenceUnitLabels[subscription.repeatType]} مانده',
                                        color: scheme.primary,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (!subscription.isPaid)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 8),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, animation) =>
                                    ScaleTransition(
                                      scale: animation,
                                      child: FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                    ),
                                child: _showPaidFeedback
                                    ? Semantics(
                                        liveRegion: true,
                                        label: 'پرداخت ثبت شد',
                                        child: const Chip(
                                          key: ValueKey('paid-feedback'),
                                          avatar: Icon(
                                            Icons.check_circle,
                                            size: 20,
                                          ),
                                          label: Text('ثبت شد'),
                                        ),
                                      )
                                    : FilledButton.tonalIcon(
                                        key: const ValueKey('mark-paid-button'),
                                        onPressed: _markAsPaid,
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text('پرداخت کردم'),
                                      ),
                              ),
                            ),
                        ],
                      ),
                      if (hasIdentifier) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () =>
                              widget.onAction(BillAction.copyIdentifier),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.tag,
                                  size: 16,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'شناسه قبض: $identifier',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.copy,
                                  size: 14,
                                  color: scheme.primary,
                                  semanticLabel: 'کپی شناسه قبض',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (subscription.note != null &&
                          subscription.note!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subscription.note!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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

  PopupMenuItem<BillAction> _menuItem(
    BillAction value,
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
          Flexible(
            child: Text(label, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
