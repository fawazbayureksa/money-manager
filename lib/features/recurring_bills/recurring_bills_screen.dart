import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_segmented_tabs.dart';
import '../../data/database/daos/bill_dao.dart';
import '../settings/settings_screen.dart';
import 'bill_form_sheet.dart';

class RecurringBillsScreen extends ConsumerStatefulWidget {
  const RecurringBillsScreen({super.key});

  @override
  ConsumerState<RecurringBillsScreen> createState() =>
      _RecurringBillsScreenState();
}

class _RecurringBillsScreenState extends ConsumerState<RecurringBillsScreen> {
  bool _showActive = true;

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(
      _showActive ? activeBillsProvider : pausedBillsProvider,
    );
    final currency = ref.watch(settingsProvider).currency;
    final colors = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recurring Bills',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Add Bill',
            onPressed: () => _openForm(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: AppSegmentedTabs<bool>(
              height: 48,
              borderRadius: 16,
              selectedValue: _showActive,
              onChanged: (v) => setState(() => _showActive = v),
              options: [
                AppTabOption(
                  value: true,
                  label: 'Upcoming',
                  icon: Icons.event_available_rounded,
                  count: ref.watch(activeBillsProvider).valueOrNull?.length,
                  accentColor: Theme.of(context).colorScheme.primary,
                  softColor: colors.canvas,
                ),
                AppTabOption(
                  value: false,
                  label: 'Paused',
                  icon: Icons.pause_circle_outline_rounded,
                  count: ref.watch(pausedBillsProvider).valueOrNull?.length,
                  accentColor: colors.warning,
                  softColor: colors.warningSoft,
                ),
              ],
            ),
          ),
          Expanded(
            child: billsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (bills) {
                if (bills.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_repeat_rounded,
                          size: 46,
                          color: colors.mutedText,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _showActive
                              ? 'No upcoming recurring bills'
                              : 'No paused bills',
                          style: TextStyle(color: colors.mutedText),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                  itemCount: bills.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    return _BillCard(
                      detail: bills[index],
                      currency: currency,
                      onEdit: () =>
                          _openForm(context, existing: bills[index]),
                      onMarkPaid: () => _markPaid(context, bills[index]),
                      onTogglePause: () async {
                        await ref
                            .read(databaseProvider)
                            .billDao
                            .setBillActive(
                              bills[index].bill.id,
                              !bills[index].bill.isActive,
                            );
                      },
                      onDelete: () => _deleteBill(context, bills[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context, {RecurringBillDetail? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BillFormSheet(existing: existing?.bill),
    );
  }

  Future<void> _markPaid(
    BuildContext context,
    RecurringBillDetail detail,
  ) async {
    await ref.read(databaseProvider).billDao.markAsPaid(detail.bill);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logged "${detail.bill.title}" & scheduled next due date',
          ),
        ),
      );
    }
  }

  Future<void> _deleteBill(
    BuildContext context,
    RecurringBillDetail detail,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${detail.bill.title}"?'),
        content: const Text(
          'Past paid transactions will remain in your activity history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(databaseProvider).billDao.deleteBill(detail.bill.id);
    }
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({
    required this.detail,
    required this.currency,
    required this.onEdit,
    required this.onMarkPaid,
    required this.onTogglePause,
    required this.onDelete,
  });

  final RecurringBillDetail detail;
  final CurrencyPreset currency;
  final VoidCallback onEdit;
  final VoidCallback onMarkPaid;
  final VoidCallback onTogglePause;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final b = detail.bill;
    final catColor = Color(detail.category.colorValue);
    final colors = context.appColors;

    final today = AppDateUtils.dateOnly(DateTime.now());
    final due = AppDateUtils.dateOnly(b.nextDueDate);
    final diffDays = due.difference(today).inDays;

    final String dueLabel;
    final Color dueBg;
    final Color dueFg;
    if (diffDays < 0) {
      dueLabel = 'Overdue ${-diffDays}d';
      dueBg = colors.expenseSoft;
      dueFg = colors.expense;
    } else if (diffDays == 0) {
      dueLabel = 'Due today';
      dueBg = colors.warningSoft;
      dueFg = colors.warning;
    } else if (diffDays <= 3) {
      dueLabel = 'In ${diffDays}d';
      dueBg = colors.warningSoft;
      dueFg = colors.warning;
    } else {
      dueLabel = DateFormat('d MMM').format(due);
      dueBg = colors.canvas;
      dueFg = colors.mutedText;
    }

    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: catColor.withValues(alpha: 0.14),
                    child: Icon(
                      appIconFromCode(detail.category.iconCodePoint),
                      color: catColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${b.frequency[0].toUpperCase()}${b.frequency.substring(1)} • ${detail.wallet.name}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colors.mutedText),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: dueBg,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      dueLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: dueFg,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    CurrencyFormatter.format(b.amountMinor, currency),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'pause') onTogglePause();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'pause',
                        child: Text(b.isActive ? 'Pause Bill' : 'Resume Bill'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete Bill'),
                      ),
                    ],
                  ),
                  if (b.isActive)
                    FilledButton.icon(
                      onPressed: onMarkPaid,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Mark Paid'),
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
