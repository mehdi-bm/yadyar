import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../providers/bills_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/empty_state.dart';
import 'widgets/monthly_expense_chart.dart';
import 'widgets/subscription_actions.dart';
import 'widgets/subscription_card.dart';

class BillsListScreen extends StatefulWidget {
  const BillsListScreen({super.key});

  @override
  State<BillsListScreen> createState() => _BillsListScreenState();
}

class _BillsListScreenState extends State<BillsListScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BillsProvider>().loadSubscriptions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setSearching(bool value) {
    setState(() => _isSearching = value);
    if (!value) {
      _searchController.clear();
      context.read<BillsProvider>().setSearchQuery('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BillsProvider>();
    final all = provider.subscriptions;
    final visible = provider.visibleSubscriptions;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'جستجو در عنوان، دسته یا شناسه قبض...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                onChanged: provider.setSearchQuery,
              )
            : const Text(AppConstants.appName),
        actions: [
          if (all.isNotEmpty)
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              tooltip: _isSearching ? 'بستن جستجو' : 'جستجو',
              onPressed: () => _setSearching(!_isSearching),
            ),
          const ThemeModeButton(),
        ],
      ),
      body: provider.isLoading && all.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : all.isEmpty
          ? EmptyStateView(
              icon: Icons.receipt_long_outlined,
              message:
                  'هنوز اشتراک یا قبضی ثبت نشده است.\nبرای شروع، دکمه + را بزنید.',
              actionLabel: 'افزودن اولین قبض',
              onAction: () => openSubscriptionEditor(context),
            )
          : RefreshIndicator(
              onRefresh: provider.loadSubscriptions,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  if (!_isSearching) ...[
                    _SummaryCard(summary: provider.summary),
                    BillsInsightsCard(
                      monthly: provider.monthlyExpenses,
                      categories: provider.categoryExpenses,
                    ),
                  ],
                  _FilterBar(provider: provider),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 44,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            provider.searchQuery.trim().isNotEmpty
                                ? 'قبضی با این عبارت پیدا نشد.'
                                : 'موردی در این دسته نیست.',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final subscription in visible)
                    SubscriptionCard(
                      key: ValueKey('bill-${subscription.id}'),
                      subscription: subscription,
                      onTap: () => openSubscriptionEditor(
                        context,
                        subscription: subscription,
                      ),
                      onAction: (action) =>
                          runBillAction(context, subscription, action),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openSubscriptionEditor(context),
        tooltip: 'افزودن اشتراک/قبض',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// کارت خلاصه مالی: بدهی این ماه، پرداختی این ماه و تعهد ماهانه.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final BillsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onColor = scheme.onPrimaryContainer;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            scheme.primaryContainer,
            scheme.primary.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مانده پرداخت تا پایان این ماه',
            style: theme.textTheme.bodyMedium?.copyWith(color: onColor),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              formatTooman(summary.dueThisMonth),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: onColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (summary.overdueCount > 0 || summary.dueSoonCount > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (summary.overdueCount > 0)
                  _AlertPill(
                    icon: Icons.warning_amber_rounded,
                    text:
                        '${formatNumber(summary.overdueCount)} قبض عقب‌افتاده',
                    color: context.statusColors.error,
                  ),
                if (summary.dueSoonCount > 0)
                  _AlertPill(
                    icon: Icons.schedule,
                    text: '${formatNumber(summary.dueSoonCount)} قبض این هفته',
                    color: context.statusColors.warning,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: onColor.withValues(alpha: 0.2)),
          const SizedBox(height: 10),
          Row(
            children: [
              _Stat(
                label: 'پرداختی این ماه',
                value: summary.paidThisMonth,
                color: onColor,
              ),
              _Stat(
                label: 'تعهد ماهانه',
                value: summary.monthlyCommitment,
                color: onColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color.withValues(alpha: 0.85),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              formatTooman(value),
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertPill extends StatelessWidget {
  const _AlertPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.provider});

  final BillsProvider provider;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final filter in BillFilter.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(
                  '${billFilterLabels[filter]} (${formatNumber(provider.countFor(filter))})',
                ),
                selected: provider.filter == filter,
                onSelected: (_) => provider.setFilter(filter),
              ),
            ),
        ],
      ),
    );
  }
}
