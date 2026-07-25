import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/subscription.dart';
import '../../models/subscription_payment.dart';
import '../../providers/bills_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key, required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<BillsProvider>();

    return Scaffold(
      appBar: AppBar(title: Text('تاریخچه پرداخت — ${subscription.title}')),
      body: FutureBuilder<List<SubscriptionPayment>>(
        future: provider.getPaymentHistory(subscription.id!),
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

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final payment = payments[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(formatJalaliDate(payment.paidDate)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
