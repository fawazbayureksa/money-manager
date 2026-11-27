import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_segmented_tabs.dart';
import '../../core/widgets/transaction_tile.dart';
import '../../data/database/daos/report_dao.dart';
import '../../data/database/daos/transaction_dao.dart';
import '../transactions/transaction_form_sheet.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _txType = 'expense'; // expense | income
  ReportPeriod _period = ReportPeriod.week;
  DateTime _anchor = DateTime.now();
  int? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currency = ref.watch(settingsProvider).currency;
    final db = ref.watch(databaseProvider);
    final range = AppDateUtils.periodRange(_period, _anchor);

    final summaryStream = db.reportDao.watchPeriodSummary(
      range.start,
      range.end,
    );
    final breakdownStream = db.reportDao.watchCategoryBreakdown(
      start: range.start,
      end: range.end,
      txType: _txType,
    );
    final txStream = db.transactionDao.watchTransactions(
      start: range.start,
      end: range.end,
      txType: _txType,
      categoryId: _selectedCategoryId,
    );

    final activeAccent =
        _txType == 'expense' ? colors.expense : colors.income;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // Top Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    PopupMenuButton<String>(
                      initialValue: _txType,
                      onSelected: (v) {
                        setState(() {
                          _txType = v;
                          _selectedCategoryId = null;
                        });
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'expense', child: Text('Expense')),
                        PopupMenuItem(value: 'income', child: Text('Income')),
                      ],
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                activeAccent.withValues(alpha: 0.14),
                            child: Icon(
                              _txType == 'expense'
                                  ? Icons.north_east_rounded
                                  : Icons.south_west_rounded,
                              size: 16,
                              color: activeAccent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _txType == 'expense' ? 'Expense' : 'Income',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded),
                        ],
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 132,
                      child: AppSegmentedTabs<ReportPeriod>(
                        height: 38,
                        borderRadius: 12,
                        selectedValue: _period,
                        onChanged: (p) {
                          setState(() {
                            _period = p;
                            _anchor = DateTime.now();
                            _selectedCategoryId = null;
                          });
                        },
                        options: [
                          AppTabOption(
                            value: ReportPeriod.week,
                            label: 'W',
                            accentColor: activeAccent,
                            softColor: activeAccent.withValues(alpha: 0.14),
                          ),
                          AppTabOption(
                            value: ReportPeriod.month,
                            label: 'M',
                            accentColor: activeAccent,
                            softColor: activeAccent.withValues(alpha: 0.14),
                          ),
                          AppTabOption(
                            value: ReportPeriod.year,
                            label: 'Y',
                            accentColor: activeAccent,
                            softColor: activeAccent.withValues(alpha: 0.14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Period Navigator + Net Cashflow Pill
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: StreamBuilder<PeriodSummary>(
                  stream: summaryStream,
                  builder: (context, snap) {
                    final s = snap.data ??
                        const PeriodSummary(incomeMinor: 0, expenseMinor: 0);
                    final net = s.netMinor;
                    return Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: () => setState(() {
                            _anchor = AppDateUtils.shiftAnchor(
                                _period, _anchor, -1);
                          }),
                        ),
                        Text(
                          AppDateUtils.periodLabel(_period, _anchor),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: () => setState(() {
                            _anchor = AppDateUtils.shiftAnchor(
                                _period, _anchor, 1);
                          }),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: net >= 0
                                ? colors.incomeSoft
                                : colors.expenseSoft,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'Net ${CurrencyFormatter.format(net, currency, showPlus: true)}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: net >= 0
                                      ? colors.income
                                      : colors.expense,
                                ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Donut Chart + Legend Card
            SliverToBoxAdapter(
              child: StreamBuilder<List<CategoryBreakdown>>(
                stream: breakdownStream,
                builder: (context, snap) {
                  final items = snap.data ?? [];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: items.isEmpty
                                ? SizedBox(
                                    height: 140,
                                    child: Center(
                                      child: Text(
                                        'No $_txType data for this period\n(Transfers are excluded)',
                                        textAlign: TextAlign.center,
                                        style:
                                            TextStyle(color: colors.mutedText),
                                      ),
                                    ),
                                  )
                                : Row(
                                    children: [
                                      SizedBox(
                                        width: 136,
                                        height: 136,
                                        child: PieChart(
                                          PieChartData(
                                            sectionsSpace: 3,
                                            centerSpaceRadius: 36,
                                            pieTouchData: PieTouchData(
                                              touchCallback: (event, res) {
                                                if (!event
                                                        .isInterestedForInteractions ||
                                                    res == null ||
                                                    res.touchedSection ==
                                                        null) {
                                                  return;
                                                }
                                                final idx = res.touchedSection!
                                                    .touchedSectionIndex;
                                                if (idx >= 0 &&
                                                    idx < items.length) {
                                                  final id =
                                                      items[idx].category.id;
                                                  setState(() {
                                                    _selectedCategoryId =
                                                        _selectedCategoryId ==
                                                                id
                                                            ? null
                                                            : id;
                                                  });
                                                }
                                              },
                                            ),
                                            sections: items.map((b) {
                                              final isSelected =
                                                  _selectedCategoryId ==
                                                      b.category.id;
                                              return PieChartSectionData(
                                                value: b.totalMinor.toDouble(),
                                                color:
                                                    Color(b.category.colorValue),
                                                radius: isSelected ? 34 : 28,
                                                showTitle: false,
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: items.take(5).map((b) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 8),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 10,
                                                    height: 10,
                                                    decoration: BoxDecoration(
                                                      color: Color(
                                                          b.category.colorValue),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${b.percentage.toStringAsFixed(0)}%',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      b.category.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        if (items.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 38,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: items.length + 1,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, index) {
                                if (index == 0) {
                                  return ChoiceChip(
                                    label: const Text('All'),
                                    selected: _selectedCategoryId == null,
                                    onSelected: (_) => setState(
                                        () => _selectedCategoryId = null),
                                  );
                                }
                                final b = items[index - 1];
                                final selected =
                                    _selectedCategoryId == b.category.id;
                                return ChoiceChip(
                                  avatar: Icon(
                                    appIconFromCode(b.category.iconCodePoint),
                                    size: 16,
                                    color: selected
                                        ? null
                                        : Color(b.category.colorValue),
                                  ),
                                  label: Text(b.category.name),
                                  selected: selected,
                                  onSelected: (_) => setState(() {
                                    _selectedCategoryId =
                                        selected ? null : b.category.id;
                                  }),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bar Chart + Filtered Transactions
            StreamBuilder<List<TransactionDetail>>(
              stream: txStream,
              builder: (context, snap) {
                final txs = snap.data ?? [];
                final totalFiltered = txs.fold<int>(
                  0,
                  (sum, t) => sum + t.transaction.amountMinor,
                );

                return SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  CurrencyFormatter.format(
                                      totalFiltered, currency),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  'Total $_txType in selected filter',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: colors.mutedText),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 140,
                                  child: _PeriodBarChart(
                                    period: _period,
                                    anchor: _anchor,
                                    txs: txs,
                                    barColor: activeAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                      sliver: SliverToBoxAdapter(
                        child: txs.isEmpty
                            ? const SizedBox.shrink()
                            : Card(
                                child: Column(
                                  children: [
                                    for (var i = 0; i < txs.length; i++) ...[
                                      TransactionTile(
                                        detail: txs[i],
                                        currency: currency,
                                        onTap: () {
                                          showModalBottomSheet<void>(
                                            context: context,
                                            isScrollControlled: true,
                                            showDragHandle: true,
                                            builder: (_) =>
                                                TransactionFormSheet(
                                              existing: txs[i],
                                            ),
                                          );
                                        },
                                      ),
                                      if (i < txs.length - 1)
                                        Divider(
                                          height: 1,
                                          indent: 68,
                                          color: colors.cardBorder,
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodBarChart extends StatelessWidget {
  const _PeriodBarChart({
    required this.period,
    required this.anchor,
    required this.txs,
    required this.barColor,
  });

  final ReportPeriod period;
  final DateTime anchor;
  final List<TransactionDetail> txs;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final buckets = _buildBuckets();
    final maxVal = buckets.fold<int>(0, (m, b) => b.amount > m ? b.amount : m);

    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= buckets.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    buckets[idx].label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.appColors.mutedText,
                          fontSize: 10,
                        ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(buckets.length, (i) {
          final val = buckets[i].amount.toDouble();
          final ratio = maxVal == 0 ? 0.0 : val / maxVal;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: val == 0 ? 0.1 : val,
                width: period == ReportPeriod.week ? 22 : 12,
                borderRadius: BorderRadius.circular(6),
                color: val == 0
                    ? barColor.withValues(alpha: 0.12)
                    : barColor.withValues(alpha: 0.35 + (0.65 * ratio)),
              ),
            ],
          );
        }),
      ),
    );
  }

  List<({String label, int amount})> _buildBuckets() {
    switch (period) {
      case ReportPeriod.week:
        final range = AppDateUtils.periodRange(ReportPeriod.week, anchor);
        const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
        final totals = List<int>.filled(7, 0);
        for (final t in txs) {
          final diff = AppDateUtils.dateOnly(t.transaction.transactionDate)
              .difference(range.start)
              .inDays;
          if (diff >= 0 && diff < 7) {
            totals[diff] += t.transaction.amountMinor;
          }
        }
        return List.generate(
          7,
          (i) => (label: dayLabels[i], amount: totals[i]),
        );

      case ReportPeriod.month:
        // Group into 4-5 weeks of the month
        final totals = List<int>.filled(5, 0);
        for (final t in txs) {
          final weekIdx = ((t.transaction.transactionDate.day - 1) ~/ 7)
              .clamp(0, 4);
          totals[weekIdx] += t.transaction.amountMinor;
        }
        return List.generate(
          5,
          (i) => (label: 'W${i + 1}', amount: totals[i]),
        );

      case ReportPeriod.year:
        final totals = List<int>.filled(12, 0);
        for (final t in txs) {
          final m = t.transaction.transactionDate.month - 1;
          totals[m] += t.transaction.amountMinor;
        }
        return List.generate(
          12,
          (i) => (
            label: DateFormat('MMM').format(DateTime(2026, i + 1, 1))[0],
            amount: totals[i],
          ),
        );
    }
  }
}
