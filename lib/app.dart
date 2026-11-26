import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/app_providers.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/recurring_bills/recurring_bills_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/transactions/transaction_form_sheet.dart';
import 'features/wallets/wallets_screen.dart';

class MoneyManagerApp extends ConsumerWidget {
  const MoneyManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'MoneyFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      home: const AppShell(),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    WalletsScreen(),
    RecurringBillsScreen(),
    ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dueCount = ref.watch(dueBillsProvider).length;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Floating Pill Dock
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.dockBackground,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: colors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DockItem(
                      icon: Icons.receipt_long_rounded,
                      label: 'Home',
                      selected: _index == 0,
                      onTap: () => setState(() => _index = 0),
                    ),
                    const SizedBox(width: 4),
                    _DockItem(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Wallets',
                      selected: _index == 1,
                      onTap: () => setState(() => _index = 1),
                    ),
                    const SizedBox(width: 4),
                    _DockItem(
                      icon: Icons.event_repeat_rounded,
                      label: 'Bills',
                      badgeCount: dueCount,
                      selected: _index == 2,
                      onTap: () => setState(() => _index = 2),
                    ),
                    const SizedBox(width: 4),
                    _DockItem(
                      icon: Icons.bar_chart_rounded,
                      label: 'Reports',
                      selected: _index == 3,
                      onTap: () => setState(() => _index = 3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Detached Circular + FAB
              Material(
                color: colors.dockBackground,
                shape: CircleBorder(
                  side: BorderSide(color: colors.cardBorder),
                ),
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.14),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => const TransactionFormSheet(),
                    );
                  },
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: Icon(
                      Icons.add_rounded,
                      size: 28,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final activeColor = colors.dockActive;
    final onActive = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0F141E)
        : Colors.white;

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: selected ? activeColor : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                size: 21,
                color: selected ? onActive : colors.mutedText,
              ),
              if (badgeCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.expense,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
