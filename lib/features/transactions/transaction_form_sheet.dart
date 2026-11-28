import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/app_segmented_tabs.dart';
import '../../data/database/app_database.dart';
import '../../data/database/daos/transaction_dao.dart';
import '../../data/database/daos/wallet_dao.dart';

class TransactionFormSheet extends ConsumerStatefulWidget {
  const TransactionFormSheet({super.key, this.existing});

  final TransactionDetail? existing;

  @override
  ConsumerState<TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  late String _txType; // expense | income | transfer
  late String _amountText;
  late DateTime _date;
  late final TextEditingController _noteCtrl;

  int? _walletId;
  int? _destWalletId;
  int? _categoryId;
  bool _showKeypad = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    final currency = ref.read(settingsProvider).currency;
    if (ex != null) {
      _txType = ex.transaction.txType;
      _amountText = CurrencyFormatter.minorToInputString(
        ex.transaction.amountMinor,
        currency,
      );
      if (_amountText.isEmpty) _amountText = '0';
      _date = ex.transaction.transactionDate;
      _noteCtrl = TextEditingController(text: ex.transaction.note);
      _walletId = ex.transaction.walletId;
      _destWalletId = ex.transaction.destinationWalletId;
      _categoryId = ex.transaction.categoryId;
    } else {
      _txType = 'expense';
      _amountText = '0';
      _date = DateTime.now();
      _noteCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  String _formattedAmount(CurrencyPreset currency) {
    if (_amountText.endsWith('.')) {
      final base = _amountText.substring(0, _amountText.length - 1);
      final minor = CurrencyFormatter.parseToMinor(base, currency);
      final formatted = CurrencyFormatter.format(minor, currency);
      return '$formatted.';
    }
    final minor = CurrencyFormatter.parseToMinor(_amountText, currency);
    if (minor == 0 && _amountText == '0') {
      return CurrencyFormatter.format(0, currency);
    }
    return CurrencyFormatter.format(minor, currency);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currency = ref.watch(settingsProvider).currency;
    final wallets = ref.watch(walletsProvider).valueOrNull ?? [];
    final categories = ref
            .watch(
              _txType == 'income'
                  ? incomeCategoriesProvider
                  : expenseCategoriesProvider,
            )
            .valueOrNull ??
        [];

    // Ensure valid defaults once streams emit
    if (_walletId == null && wallets.isNotEmpty) {
      _walletId = wallets.first.wallet.id;
    }
    if (_txType == 'transfer' &&
        _destWalletId == null &&
        wallets.length >= 2) {
      _destWalletId = wallets
          .firstWhere(
            (w) => w.wallet.id != _walletId,
            orElse: () => wallets.last,
          )
          .wallet
          .id;
    }
    if (_txType != 'transfer' &&
        (_categoryId == null ||
            !categories.any((c) => c.id == _categoryId)) &&
        categories.isNotEmpty) {
      _categoryId = categories.first.id;
    }

    final isEdit = widget.existing != null;
    final typeColor = switch (_txType) {
      'income' => colors.income,
      'transfer' => colors.transfer,
      _ => colors.expense,
    };
    final typeSoftColor = switch (_txType) {
      'income' => colors.incomeSoft,
      'transfer' => colors.transferSoft,
      _ => colors.expenseSoft,
    };

    final selectedWallet = wallets
        .where((w) => w.wallet.id == _walletId)
        .cast<WalletWithBalance?>()
        .firstOrNull;
    final selectedDestWallet = wallets
        .where((w) => w.wallet.id == _destWalletId)
        .cast<WalletWithBalance?>()
        .firstOrNull;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  _HeaderCircleButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Transaction' : 'Add Transaction',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  if (isEdit)
                    _HeaderCircleButton(
                      icon: Icons.delete_outline_rounded,
                      iconColor: colors.expense,
                      onTap: _delete,
                    )
                  else
                    const SizedBox(width: 40),
                ],
              ),
            ),

            // Scrollable Form Body
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Segmented Type Tabs
                    AppSegmentedTabs<String>(
                      height: 48,
                      borderRadius: 99,
                      selectedValue: _txType,
                      onChanged: (v) {
                        setState(() {
                          _txType = v;
                          _categoryId = null;
                        });
                      },
                      options: [
                        AppTabOption(
                          value: 'expense',
                          label: 'Expense',
                          icon: Icons.arrow_upward_rounded,
                          accentColor: colors.expense,
                          softColor: colors.expenseSoft,
                        ),
                        AppTabOption(
                          value: 'income',
                          label: 'Income',
                          icon: Icons.arrow_downward_rounded,
                          accentColor: colors.income,
                          softColor: colors.incomeSoft,
                        ),
                        AppTabOption(
                          value: 'transfer',
                          label: 'Transfer',
                          icon: Icons.swap_horiz_rounded,
                          accentColor: colors.transfer,
                          softColor: colors.transferSoft,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Amount Card
                    _AmountCard(
                      formattedAmount: _formattedAmount(currency),
                      hasValue: _amountText != '0',
                      isKeypadOpen: _showKeypad,
                      accentColor: typeColor,
                      onTap: () => setState(() => _showKeypad = !_showKeypad),
                      onClear: () => setState(() => _amountText = '0'),
                    ),

                    // Collapsible Numeric Keypad
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 220),
                      crossFadeState: _showKeypad
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _NumericKeypad(
                          allowDecimal: currency.decimalDigits > 0,
                          onKey: _onKeypadTap,
                          onBackspace: _onBackspace,
                          onClear: () => setState(() => _amountText = '0'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Category Quick Grid Card (Expense / Income)
                    if (_txType != 'transfer') ...[
                      _CategorySectionCard(
                        categories: categories,
                        selectedCategoryId: _categoryId,
                        accentColor: typeColor,
                        onSelect: (id) => setState(() => _categoryId = id),
                        onSeeAll: () => _openCategoryPicker(categories),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Date Row Card
                    _SelectorRowCard(
                      icon: Icons.calendar_month_rounded,
                      iconColor: typeColor,
                      iconBg: typeSoftColor,
                      label: 'Date',
                      value: DateFormat('MMM d, yyyy • HH:mm').format(_date),
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 12),

                    // Wallet / Payment Method Row Card
                    _SelectorRowCard(
                      icon: selectedWallet != null
                          ? appIconFromCode(selectedWallet.wallet.iconCodePoint)
                          : Icons.account_balance_wallet_rounded,
                      iconColor: selectedWallet != null
                          ? Color(selectedWallet.wallet.colorValue)
                          : colors.income,
                      iconBg: (selectedWallet != null
                              ? Color(selectedWallet.wallet.colorValue)
                              : colors.income)
                          .withValues(alpha: 0.14),
                      label: _txType == 'transfer'
                          ? 'From Wallet'
                          : 'Payment Method',
                      value: selectedWallet?.wallet.name ?? 'Select wallet',
                      onTap: () => _openWalletPicker(
                        wallets: wallets,
                        selectedId: _walletId,
                        title: _txType == 'transfer'
                            ? 'From Wallet'
                            : 'Payment Method',
                        onSelected: (id) => setState(() => _walletId = id),
                      ),
                    ),

                    if (_txType == 'transfer') ...[
                      const SizedBox(height: 12),
                      _SelectorRowCard(
                        icon: selectedDestWallet != null
                            ? appIconFromCode(
                                selectedDestWallet.wallet.iconCodePoint,
                              )
                            : Icons.account_balance_wallet_outlined,
                        iconColor: selectedDestWallet != null
                            ? Color(selectedDestWallet.wallet.colorValue)
                            : colors.transfer,
                        iconBg: (selectedDestWallet != null
                                ? Color(selectedDestWallet.wallet.colorValue)
                                : colors.transfer)
                            .withValues(alpha: 0.14),
                        label: 'To Wallet',
                        value:
                            selectedDestWallet?.wallet.name ?? 'Select wallet',
                        onTap: () => _openWalletPicker(
                          wallets: wallets,
                          selectedId: _destWalletId,
                          title: 'To Wallet',
                          onSelected: (id) =>
                              setState(() => _destWalletId = id),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Notes Card
                    _NotesCard(controller: _noteCtrl),
                    const SizedBox(height: 16),

                    // Primary Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: typeColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        onPressed: _save,
                        child: Text(
                          isEdit ? 'Update Transaction' : 'Save Transaction',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCategoryPicker(List<Category> categories) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final colors = ctx.appColors;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Category',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    itemCount: categories.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemBuilder: (_, index) {
                      final cat = categories[index];
                      final catColor = Color(cat.colorValue);
                      final isSelected = cat.id == _categoryId;
                      return InkWell(
                        onTap: () => Navigator.pop(ctx, cat.id),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? catColor.withValues(alpha: 0.12)
                                : colors.surfaceCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? catColor : colors.cardBorder,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    catColor.withValues(alpha: 0.14),
                                child: Icon(
                                  appIconFromCode(cat.iconCodePoint),
                                  size: 18,
                                  color: catColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                cat.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(ctx)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
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
        );
      },
    );

    if (selected != null) {
      setState(() => _categoryId = selected);
    }
  }

  Future<void> _openWalletPicker({
    required List<WalletWithBalance> wallets,
    required int? selectedId,
    required String title,
    required ValueChanged<int> onSelected,
  }) async {
    final currency = ref.read(settingsProvider).currency;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final colors = ctx.appColors;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                ...wallets.map((item) {
                  final w = item.wallet;
                  final wColor = Color(w.colorValue);
                  final isSelected = w.id == selectedId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? wColor : colors.cardBorder,
                        ),
                      ),
                      tileColor: isSelected
                          ? wColor.withValues(alpha: 0.08)
                          : colors.surfaceCard,
                      leading: CircleAvatar(
                        backgroundColor: wColor.withValues(alpha: 0.14),
                        child: Icon(
                          appIconFromCode(w.iconCodePoint),
                          color: wColor,
                        ),
                      ),
                      title: Text(
                        w.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        CurrencyFormatter.format(item.balanceMinor, currency),
                        style: TextStyle(color: colors.mutedText),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle_rounded, color: wColor)
                          : null,
                      onTap: () => Navigator.pop(ctx, w.id),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (picked != null) {
      onSelected(picked);
    }
  }

  void _onKeypadTap(String key) {
    setState(() {
      if (key == '.') {
        if (_amountText.contains('.')) return;
        _amountText = '$_amountText.';
        return;
      }
      if (key == '000') {
        if (_amountText == '0') return;
        if (_amountText.length + 3 <= 12) _amountText = '$_amountText$key';
        return;
      }
      if (_amountText == '0') {
        _amountText = key;
      } else {
        if (_amountText.contains('.')) {
          final decPart = _amountText.split('.').last;
          if (decPart.length >= 2) return;
        }
        if (_amountText.length < 12) {
          _amountText = '$_amountText$key';
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_amountText.length <= 1) {
        _amountText = '0';
      } else {
        _amountText = _amountText.substring(0, _amountText.length - 1);
      }
    });
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    setState(() {
      _date = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime?.hour ?? _date.hour,
        pickedTime?.minute ?? _date.minute,
      );
    });
  }

  Future<void> _save() async {
    final currency = ref.read(settingsProvider).currency;
    final amountMinor = CurrencyFormatter.parseToMinor(_amountText, currency);
    if (amountMinor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount greater than 0')),
      );
      return;
    }
    if (_walletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create a wallet first')),
      );
      return;
    }
    if (_txType == 'transfer') {
      if (_destWalletId == null || _destWalletId == _walletId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select a different destination wallet for transfer'),
          ),
        );
        return;
      }
    }

    final dao = ref.read(databaseProvider).transactionDao;
    final note = _noteCtrl.text.trim();

    if (widget.existing == null) {
      await dao.createTransaction(
        TransactionsCompanion.insert(
          txType: _txType,
          amountMinor: amountMinor,
          walletId: _walletId!,
          destinationWalletId: Value(
            _txType == 'transfer' ? _destWalletId : null,
          ),
          categoryId: Value(_txType == 'transfer' ? null : _categoryId),
          note: Value(note),
          transactionDate: _date,
        ),
      );
    } else {
      final t = widget.existing!.transaction;
      await dao.updateTransaction(
        TransactionsCompanion(
          id: Value(t.id),
          txType: Value(_txType),
          amountMinor: Value(amountMinor),
          walletId: Value(_walletId!),
          destinationWalletId: Value(
            _txType == 'transfer' ? _destWalletId : null,
          ),
          categoryId: Value(_txType == 'transfer' ? null : _categoryId),
          recurringBillId: Value(t.recurringBillId),
          note: Value(note),
          transactionDate: Value(_date),
          createdAt: Value(t.createdAt),
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final t = widget.existing!.transaction;
    await ref.read(databaseProvider).transactionDao.deleteTransaction(t.id);
    if (mounted) Navigator.pop(context);
  }
}

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.surfaceCard,
      shape: CircleBorder(side: BorderSide(color: colors.cardBorder)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.formattedAmount,
    required this.hasValue,
    required this.isKeypadOpen,
    required this.accentColor,
    required this.onTap,
    required this.onClear,
  });

  final String formattedAmount;
  final bool hasValue;
  final bool isKeypadOpen;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.surfaceCard,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isKeypadOpen ? accentColor : colors.cardBorder,
              width: isKeypadOpen ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colors.mutedText,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedAmount,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                  ],
                ),
              ),
              if (hasValue)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Clear amount',
                  icon: Icon(
                    Icons.cancel_rounded,
                    color: colors.mutedText,
                    size: 20,
                  ),
                  onPressed: onClear,
                )
              else
                Icon(
                  Icons.dialpad_rounded,
                  color: isKeypadOpen ? accentColor : colors.mutedText,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySectionCard extends StatelessWidget {
  const _CategorySectionCard({
    required this.categories,
    required this.selectedCategoryId,
    required this.accentColor,
    required this.onSelect,
    required this.onSeeAll,
  });

  final List<Category> categories;
  final int? selectedCategoryId;
  final Color accentColor;
  final ValueChanged<int> onSelect;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasMore = categories.length > 4;
    final quickCats = hasMore ? categories.take(4).toList() : categories;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Category',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              InkWell(
                onTap: onSeeAll,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See all',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: accentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: accentColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (categories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No categories available',
                style: TextStyle(color: colors.mutedText),
              ),
            )
          else
            Row(
              children: [
                for (var i = 0; i < quickCats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _CategoryQuickTile(
                      label: quickCats[i].name,
                      icon: appIconFromCode(quickCats[i].iconCodePoint),
                      color: Color(quickCats[i].colorValue),
                      selected: quickCats[i].id == selectedCategoryId,
                      onTap: () => onSelect(quickCats[i].id),
                    ),
                  ),
                ],
                if (hasMore) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CategoryQuickTile(
                      label: 'More',
                      icon: Icons.more_horiz_rounded,
                      color: colors.mutedText,
                      selected: !quickCats.any((c) => c.id == selectedCategoryId),
                      onTap: onSeeAll,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _CategoryQuickTile extends StatelessWidget {
  const _CategoryQuickTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: selected ? color.withValues(alpha: 0.10) : colors.canvas,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 82,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : colors.cardBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10.5,
                      height: 1.15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? color : null,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectorRowCard extends StatelessWidget {
  const _SelectorRowCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.surfaceCard,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 19, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.mutedText,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.canvas,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notes_rounded,
              size: 19,
              color: colors.mutedText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notes (Optional)',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.mutedText,
                      ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Lunch with team',
                    filled: true,
                    fillColor: colors.canvas,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
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

class _NumericKeypad extends StatelessWidget {
  const _NumericKeypad({
    required this.allowDecimal,
    required this.onKey,
    required this.onBackspace,
    required this.onClear,
  });

  final bool allowDecimal;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      [allowDecimal ? '.' : '000', '0', 'BACK'],
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        children: rows.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: row.map((key) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Material(
                      color: colors.canvas,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          if (key == 'BACK') {
                            onBackspace();
                          } else {
                            onKey(key);
                          }
                        },
                        onLongPress: key == 'BACK' ? onClear : null,
                        child: SizedBox(
                          height: 42,
                          child: Center(
                            child: key == 'BACK'
                                ? const Icon(Icons.backspace_outlined, size: 19)
                                : Text(
                                    key,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}
