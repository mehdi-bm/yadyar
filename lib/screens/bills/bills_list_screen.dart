import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/subscription.dart';
import '../../providers/bills_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import 'payment_history_screen.dart';
import 'subscription_edit_screen.dart';
import 'widgets/monthly_expense_chart.dart';
import 'widgets/subscription_actions.dart';
import 'widgets/subscription_card.dart';

class BillsListScreen extends StatefulWidget {
  const BillsListScreen({super.key});

  @override
  State<BillsListScreen> createState() => _BillsListScreenState();
}

class _BillsListScreenState extends State<BillsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BillsProvider>().loadSubscriptions();
    });
  }

  Future<void> _openEditor(BuildContext context, {Subscription? subscription}) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SubscriptionEditScreen(subscription: subscription),
      ),
    );
  }

  Future<void> _openHistory(BuildContext context, Subscription subscription) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PaymentHistoryScreen(subscription: subscription),
      ),
    );
  }

  Future<void> _handleLongPress(
    BuildContext context,
    Subscription subscription,
  ) async {
    final provider = context.read<BillsProvider>();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('ویرایش'),
              onTap: () => Navigator.of(ctx).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('تاریخچه پرداخت‌ها'),
              onTap: () => Navigator.of(ctx).pop('history'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: Text(
                'حذف',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) return;
    switch (action) {
      case 'edit':
        await _openEditor(context, subscription: subscription);
      case 'history':
        await _openHistory(context, subscription);
      case 'delete':
        final confirmed = await showDeleteSubscriptionConfirmation(context);
        if (confirmed) await provider.deleteSubscription(subscription.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BillsProvider>();
    final subscriptions = provider.subscriptions;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: const [ThemeModeButton()],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : subscriptions.isEmpty
          ? EmptyStateView(
              icon: Icons.receipt_long_outlined,
              message: 'هنوز اشتراک یا قبضی ثبت نشده است.\nبرای شروع، دکمه + را بزنید.',
              actionLabel: 'افزودن اولین قبض',
              onAction: () => _openEditor(context),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                MonthlyExpenseChart(data: provider.monthlyExpenses),
                for (final subscription in subscriptions)
                  SubscriptionCard(
                    subscription: subscription,
                    onTap: () =>
                        _openEditor(context, subscription: subscription),
                    onLongPress: () => _handleLongPress(context, subscription),
                    onMarkAsPaid: () => provider.markAsPaid(subscription),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        tooltip: 'افزودن اشتراک/قبض',
        child: const Icon(Icons.add),
      ),
    );
  }
}
