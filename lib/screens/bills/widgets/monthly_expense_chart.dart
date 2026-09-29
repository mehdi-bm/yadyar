import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../providers/bills_provider.dart';
import '../../../utils/currency_formatter.dart';
import 'subscription_card.dart' show billCategoryIcon;

enum _InsightView { monthly, categories }

/// کارت تحلیل هزینه‌ها: نمودار میله‌ای ۶ ماه اخیر، یا سهم هر دسته (دونات).
class BillsInsightsCard extends StatefulWidget {
  const BillsInsightsCard({
    super.key,
    required this.monthly,
    required this.categories,
  });

  final List<MonthlyExpense> monthly;
  final List<CategoryExpense> categories;

  @override
  State<BillsInsightsCard> createState() => _BillsInsightsCardState();
}

class _BillsInsightsCardState extends State<BillsInsightsCard> {
  _InsightView _view = _InsightView.monthly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.monthly.fold<double>(0, (sum, e) => sum + e.total);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تحلیل هزینه‌ها',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '۶ ماه اخیر: ${formatTooman(total)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SegmentedButton<_InsightView>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: _InsightView.monthly,
                      icon: Icon(Icons.bar_chart, size: 18),
                      tooltip: 'هزینه ماهانه',
                    ),
                    ButtonSegment(
                      value: _InsightView.categories,
                      icon: Icon(Icons.donut_large, size: 18),
                      tooltip: 'به تفکیک دسته',
                    ),
                  ],
                  selected: {_view},
                  onSelectionChanged: (value) =>
                      setState(() => _view = value.first),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _view == _InsightView.monthly
                  ? _MonthlyBars(
                      key: const ValueKey('monthly'),
                      data: widget.monthly,
                    )
                  : _CategoryDonut(
                      key: const ValueKey('categories'),
                      data: widget.categories,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyBars extends StatelessWidget {
  const _MonthlyBars({super.key, required this.data});

  final List<MonthlyExpense> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxTotal = data.fold<double>(
      0,
      (max, e) => e.total > max ? e.total : max,
    );
    final maxY = maxTotal <= 0 ? 1.0 : maxTotal * 1.2;

    return SizedBox(
      height: 170,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      data[index].label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: data[index].isCurrent
                            ? FontWeight.bold
                            : null,
                        color: data[index].isCurrent ? scheme.primary : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i].total,
                    color: data[i].isCurrent
                        ? scheme.primary
                        : scheme.primary.withValues(alpha: 0.45),
                    width: 20,
                    borderRadius: BorderRadius.circular(6),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY,
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
          ],
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  formatTooman(rod.toY),
                  theme.textTheme.labelSmall!.copyWith(
                    color: scheme.onInverseSurface,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

const List<Color> _categoryColors = [
  Color(0xFF26A69A),
  Color(0xFF42A5F5),
  Color(0xFFFFA726),
  Color(0xFFEC407A),
  Color(0xFF7E57C2),
  Color(0xFF9CCC65),
  Color(0xFF8D6E63),
  Color(0xFF78909C),
];

class _CategoryDonut extends StatelessWidget {
  const _CategoryDonut({super.key, required this.data});

  final List<CategoryExpense> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) {
      return SizedBox(
        height: 170,
        child: Center(
          child: Text(
            'هنوز پرداختی در ۶ ماه اخیر ثبت نشده است.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    final total = data.fold<double>(0, (sum, e) => sum + e.total);

    return SizedBox(
      height: 170,
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 38,
                sectionsSpace: 2,
                sections: [
                  for (var i = 0; i < data.length; i++)
                    PieChartSectionData(
                      value: data[i].total,
                      color: _categoryColors[i % _categoryColors.length],
                      radius: 26,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < data.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          billCategoryIcon(data[i].category),
                          size: 16,
                          color: _categoryColors[i % _categoryColors.length],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            data[i].category,
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${formatNumber((data[i].total / total * 100).round())}٪',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
