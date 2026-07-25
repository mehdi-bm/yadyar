import 'package:flutter/material.dart';

import '../../../models/subscription.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/date_formatter.dart';
import 'bill_status.dart';

class SubscriptionCard extends StatefulWidget {
  const SubscriptionCard({
    super.key,
    required this.subscription,
    required this.onTap,
    required this.onLongPress,
    required this.onMarkAsPaid,
  });

  final Subscription subscription;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMarkAsPaid;

  @override
  State<SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<SubscriptionCard> {
  bool _showPaidFeedback = false;

  Future<void> _markAsPaid() async {
    if (_showPaidFeedback) return;
    setState(() => _showPaidFeedback = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (mounted) widget.onMarkAsPaid();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscription = widget.subscription;
    final status = billStatusOf(subscription);
    final statusColor = billStatusColor(context, status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subscription.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      billStatusLabel(status),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subscription.category,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatTooman(subscription.amount),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'سررسید: ${formatJalaliDate(subscription.dueDate)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (!subscription.isPaid)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: _showPaidFeedback
                          ? Semantics(
                              liveRegion: true,
                              label: 'پرداخت ثبت شد',
                              child: Chip(
                                key: const ValueKey('paid-feedback'),
                                avatar: const Icon(
                                  Icons.check_circle,
                                  size: 20,
                                ),
                                label: const Text('ثبت شد'),
                              ),
                            )
                          : FilledButton.tonalIcon(
                              key: const ValueKey('mark-paid-button'),
                              onPressed: _markAsPaid,
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('پرداخت‌شده'),
                            ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
