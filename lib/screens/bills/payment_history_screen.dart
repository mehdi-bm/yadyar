import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/subscription.dart';
import '../../models/subscription_payment.dart';
import '../../providers/bills_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key, required this.subscription});

  final Subscription subscription;

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  late Future<List<SubscriptionPayment>> _payments;

  @override
  void initState() {
    super.initState();
    _payments = _load();
  }

  Future<List<SubscriptionPayment>> _load() =>
      context.read<BillsProvider>().getPaymentHistory(widget.subscription.id!);

  Future<void> _delete(SubscriptionPayment payment) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف رکورد پرداخت',
      message:
          'این رکورد از تاریخچه حذف می‌شود (مثلاً اگر اشتباه ثبت شده). سررسید و وضعیت قبض تغییری نمی‌کند.',
    );
    if (!confirmed || !mounted) return;
    await context.read<BillsProvider>().deletePayment(payment);
    setState(() => _payments = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تاریخچه پرداخت — ${widget.subscription.title}'),
      ),
      body: FutureBuilder<List<SubscriptionPayment>>(
        future: _payments,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final payments = snapshot.data ?? [];
          if (payments.isEmpty) {
            return const EmptyStateView(
              icon: Icons.history,
              message: 'هنوز پرداختی برای این مورد ثبت نشده است.',
            );
          }

          final total = payments.fold<double>(0, (sum, p) => sum + p.amount);
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _HistorySummary(
                total: total,
                count: payments.length,
                average: total / payments.length,
              ),
              for (final payment in payments)
                Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: context.statusColors.success.withValues(
                        alpha: 0.12,
                      ),
                      child: Icon(
                        Icons.check_circle_outline,
                        color: context.statusColors.success,
                      ),
                    ),
                    title: Text(
                      formatTooman(payment.amount),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(formatJalaliLong(payment.paidDate)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'حذف رکورد',
                      onPressed: () => _delete(payment),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HistorySummary extends StatelessWidget {
  const _HistorySummary({
    required this.total,
    required this.count,
    required this.average,
  });

  final double total;
  final int count;
  final double average;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget stat(String label, String value) => Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            stat('جمع پرداخت‌ها', formatTooman(total)),
            stat('تعداد', formatNumber(count)),
            stat('میانگین', formatTooman(average.roundToDouble())),
          ],
        ),
      ),
    );
  }
}
