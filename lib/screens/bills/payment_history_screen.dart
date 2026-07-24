import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/subscription.dart';
import '../../models/subscription_payment.dart';
import '../../providers/bills_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';

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
            final theme = Theme.of(context);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history, size: 64, color: theme.colorScheme.outline),
                    const SizedBox(height: 12),
                    Text(
                      'هنوز پرداختی برای این مورد ثبت نشده است.',
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: payments.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final payment = payments[index];
              return ListTile(
                leading: Icon(Icons.check_circle_outline, color: AppConstants.successColor),
                title: Text(formatTooman(payment.amount)),
                subtitle: Text(formatJalaliDate(payment.paidDate)),
              );
            },
          );
        },
      ),
    );
  }
}
