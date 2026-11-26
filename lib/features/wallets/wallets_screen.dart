import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/daos/wallet_dao.dart';
import '../settings/settings_screen.dart';
import 'wallet_form_sheet.dart';

class WalletsScreen extends ConsumerStatefulWidget {
  const WalletsScreen({super.key});

  @override
  ConsumerState<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends ConsumerState<WalletsScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(
      _showArchived ? allWalletsProvider : walletsProvider,
    );
    final netWorth = ref.watch(totalNetWorthProvider);
    final currency = ref.watch(settingsProvider).currency;
    final colors = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wallets',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: _showArchived ? 'Hide archived' : 'Show archived',
            icon: Icon(
              _showArchived
                  ? Icons.visibility_off_outlined
                  : Icons.archive_outlined,
            ),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Add Wallet',
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
      body: walletsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Net Worth',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.mutedText,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        CurrencyFormatter.format(netWorth, currency),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${items.where((w) => !w.wallet.isArchived).length} active wallets',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.mutedText,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ...items.map((item) => _WalletCard(
                    item: item,
                    currency: currency,
                    onEdit: () => _openForm(context, existing: item),
                    onDeleteOrArchive: () => _confirmDeleteOrArchive(context, item),
                  )),
            ],
          );
        },
      ),
    );
  }

  void _openForm(BuildContext context, {WalletWithBalance? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => WalletFormSheet(existing: existing?.wallet),
    );
  }

  Future<void> _confirmDeleteOrArchive(
    BuildContext context,
    WalletWithBalance item,
  ) async {
    final dao = ref.read(databaseProvider).walletDao;
    final w = item.wallet;

    if (w.isArchived) {
      await dao.setArchived(w.id, false);
      return;
    }

    if (item.transactionCount == 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Delete "${w.name}"?'),
          content: const Text('This wallet has no transactions yet.'),
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
        await dao.deleteWalletWithTransactions(w.id);
      }
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Manage "${w.name}"'),
        content: Text(
          'This wallet has ${item.transactionCount} transactions. '
          'Archiving hides it from new entries while preserving your report history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await dao.deleteWalletWithTransactions(w.id);
            },
            child: Text(
              'Delete All',
              style: TextStyle(color: context.appColors.expense),
            ),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await dao.setArchived(w.id, true);
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.item,
    required this.currency,
    required this.onEdit,
    required this.onDeleteOrArchive,
  });

  final WalletWithBalance item;
  final CurrencyPreset currency;
  final VoidCallback onEdit;
  final VoidCallback onDeleteOrArchive;

  @override
  Widget build(BuildContext context) {
    final w = item.wallet;
    final color = Color(w.colorValue);
    final colors = context.appColors;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(appIconFromCode(w.iconCodePoint), color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            w.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (w.isArchived) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.mutedText.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              'Archived',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${w.walletType.toUpperCase()} • ${item.transactionCount} tx',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.mutedText,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(item.balanceMinor, currency),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: item.balanceMinor < 0 ? colors.expense : null,
                        ),
                  ),
                  IconButton(
                    icon: Icon(
                      w.isArchived
                          ? Icons.unarchive_outlined
                          : Icons.more_horiz_rounded,
                      size: 20,
                      color: colors.mutedText,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: onDeleteOrArchive,
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
