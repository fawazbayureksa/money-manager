import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/transaction_tile.dart';
import '../../data/database/daos/report_dao.dart';
import '../../data/database/daos/transaction_dao.dart';
import '../settings/settings_screen.dart';
import '../transactions/transaction_form_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  ReportPeriod _period = ReportPeriod.month;
  int? _selectedWalletId;
  bool _searching = false;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currency = ref.watch(settingsProvider).currency;
    final netWorth = ref.watch(totalNetWorthProvider);
    final wallets = ref.watch(walletsProvider).valueOrNull ?? [];
    final dueBills = ref.watch(dueBillsProvider);

    final range = AppDateUtils.periodRange(_period, DateTime.now());
    final db = ref.watch(databaseProvider);

    final summaryStream = db.reportDao.watchPeriodSummary(
      range.start,
      range.end,
      walletId: _selectedWalletId,
    );
    final txStream = db.transactionDao.watchTransactions(
      start: range.start,
      end: range.end,
      walletId: _selectedWalletId,
      searchQuery: _searchQuery,
    );

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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'lib/assets/new-icon.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _searching
                          ? TextField(
                              autofocus: true,
                              decoration: const InputDecoration(
                                hintText: 'Search notes or categories...',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v),
                            )
                          : Text(
                              'Rexxflow',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                    ),
                    IconButton(
                      icon: Icon(
                        _searching ? Icons.close_rounded : Icons.search_rounded,
                      ),
                      onPressed: () {
                        setState(() {
                          _searching = !_searching;
                          if (!_searching) _searchQuery = '';
                        });
                      },
                    ),
                    _PeriodPill(
                      period: _period,
                      onChanged: (p) => setState(() => _period = p),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Net Worth + Mini Wallet Strip
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Net Worth',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.mutedText,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(netWorth, currency),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: wallets.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, index) {
                          final item = wallets[index];
                          final selected = _selectedWalletId == item.wallet.id;
                          final wColor = Color(item.wallet.colorValue);
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedWalletId =
                                    selected ? null : item.wallet.id;
                              });
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : colors.surfaceCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? Theme.of(context).colorScheme.primary
                                      : colors.cardBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    appIconFromCode(item.wallet.iconCodePoint),
                                    size: 16,
                                    color: selected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimary
                                        : wColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${item.wallet.name} • ${CurrencyFormatter.format(item.balanceMinor, currency)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: selected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onPrimary
                                              : null,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Due Bills Alert Banner
            if (dueBills.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.warningSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_active_outlined,
                          color: colors.warning,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${dueBills.first.bill.title} due • ${CurrencyFormatter.format(dueBills.first.bill.amountMinor, currency)}'
                            '${dueBills.length > 1 ? ' (+${dueBills.length - 1} more)' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () async {
                            await ref
                                .read(databaseProvider)
                                .billDao
                                .markAsPaid(dueBills.first.bill);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Paid "${dueBills.first.bill.title}"',
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text('Pay'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Income / Expense Summary Cards
            SliverToBoxAdapter(
              child: StreamBuilder<PeriodSummary>(
                stream: summaryStream,
                builder: (context, snapshot) {
                  final summary = snapshot.data ??
                      const PeriodSummary(incomeMinor: 0, expenseMinor: 0);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            label: 'Income',
                            amountText: CurrencyFormatter.format(
                              summary.incomeMinor,
                              currency,
                            ),
                            background: colors.incomeSoft,
                            accent: colors.income,
                            icon: Icons.south_west_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            label: 'Expense',
                            amountText: CurrencyFormatter.format(
                              summary.expenseMinor,
                              currency,
                            ),
                            background: colors.expenseSoft,
                            accent: colors.expense,
                            icon: Icons.north_east_rounded,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Activity Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                child: Text(
                  'Activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),

            // Grouped Transaction List
            StreamBuilder<List<TransactionDetail>>(
              stream: txStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                final txs = snapshot.data!;
                if (txs.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 44,
                            color: colors.mutedText,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No transactions in this period',
                            style: TextStyle(color: colors.mutedText),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap + below to add one',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colors.mutedText),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final grouped = _groupByDay(txs);
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                  sliver: SliverList.separated(
                    itemCount: grouped.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final entry = grouped[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 6),
                            child: Text(
                              entry.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: colors.mutedText,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          Card(
                            child: Column(
                              children: [
                                for (var i = 0;
                                    i < entry.items.length;
                                    i++) ...[
                                  TransactionTile(
                                    detail: entry.items[i],
                                    currency: currency,
                                    onTap: () {
                                      showModalBottomSheet<void>(
                                        context: context,
                                        isScrollControlled: true,
                                        showDragHandle: true,
                                        builder: (_) => TransactionFormSheet(
                                          existing: entry.items[i],
                                        ),
                                      );
                                    },
                                  ),
                                  if (i < entry.items.length - 1)
                                    Divider(
                                      height: 1,
                                      indent: 68,
                                      color: colors.cardBorder,
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<({String label, List<TransactionDetail> items})> _groupByDay(
    List<TransactionDetail> txs,
  ) {
    final map = <String, List<TransactionDetail>>{};
    for (final tx in txs) {
      final label = AppDateUtils.dayGroupLabel(tx.transaction.transactionDate);
      map.putIfAbsent(label, () => []).add(tx);
    }
    return map.entries
        .map((e) => (label: e.key, items: e.value))
        .toList();
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({required this.period, required this.onChanged});

  final ReportPeriod period;
  final ValueChanged<ReportPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final label = switch (period) {
      ReportPeriod.week => 'This Week',
      ReportPeriod.month => 'This Month',
      ReportPeriod.year => 'This Year',
    };

    return PopupMenuButton<ReportPeriod>(
      initialValue: period,
      onSelected: onChanged,
      itemBuilder: (_) => const [
        PopupMenuItem(value: ReportPeriod.week, child: Text('This Week')),
        PopupMenuItem(value: ReportPeriod.month, child: Text('This Month')),
        PopupMenuItem(value: ReportPeriod.year, child: Text('This Year')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: colors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amountText,
    required this.background,
    required this.accent,
    required this.icon,
  });

  final String label;
  final String amountText;
  final Color background;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: accent.withValues(alpha: 0.18),
                child: Icon(icon, size: 15, color: accent),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            amountText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
