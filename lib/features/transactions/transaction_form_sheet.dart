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

    final typeColor = switch (_txType) {
      'income' => colors.income,
      'transfer' => colors.transfer,
      _ => colors.expense,
    };

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppSegmentedTabs<String>(
                      height: 46,
                      borderRadius: 15,
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
                          accentColor: colors.expense,
                          softColor: colors.expenseSoft,
                        ),
                        AppTabOption(
                          value: 'income',
                          label: 'Income',
                          accentColor: colors.income,
                          softColor: colors.incomeSoft,
                        ),
                        AppTabOption(
                          value: 'transfer',
                          label: 'Transfer',
                          accentColor: colors.transfer,
                          softColor: colors.transferSoft,
                        ),
                      ],
                    ),
                  ),
                  if (widget.existing != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded,
                          color: colors.expense),
                      onPressed: _delete,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              // Amount Display
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${currency.symbol} $_amountText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: typeColor,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(99),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceCard,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: colors.cardBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    size: 13),
                                const SizedBox(width: 5),
                                Text(
                                  DateFormat('EEE, d MMM • HH:mm')
                                      .format(_date),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          _txType.toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: typeColor,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Wallet Picker(s)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _txType == 'transfer' ? 'From Wallet' : 'Wallet',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.mutedText,
                      ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: wallets.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final w = wallets[index].wallet;
                    final selected = w.id == _walletId;
                    return ChoiceChip(
                      avatar: Icon(
                        appIconFromCode(w.iconCodePoint),
                        size: 16,
                        color: selected ? null : Color(w.colorValue),
                      ),
                      label: Text(w.name),
                      selected: selected,
                      onSelected: (_) => setState(() => _walletId = w.id),
                    );
                  },
                ),
              ),
              if (_txType == 'transfer') ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'To Wallet',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colors.mutedText,
                        ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: wallets.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final w = wallets[index].wallet;
                      final selected = w.id == _destWalletId;
                      return ChoiceChip(
                        avatar: Icon(
                          appIconFromCode(w.iconCodePoint),
                          size: 16,
                          color: selected ? null : Color(w.colorValue),
                        ),
                        label: Text(w.name),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _destWalletId = w.id),
                      );
                    },
                  ),
                ),
              ] else ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Category',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colors.mutedText,
                        ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final c = categories[index];
                      final selected = c.id == _categoryId;
                      return ChoiceChip(
                        avatar: Icon(
                          appIconFromCode(c.iconCodePoint),
                          size: 16,
                          color: selected ? null : Color(c.colorValue),
                        ),
                        label: Text(c.name),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _categoryId = c.id),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _noteCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Add a note (optional)',
                  prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _NumericKeypad(
                allowDecimal: currency.decimalDigits > 0,
                onKey: _onKeypadTap,
                onBackspace: _onBackspace,
                onClear: () => setState(() => _amountText = '0'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: typeColor),
                  onPressed: _save,
                  child: Text(
                    widget.existing == null
                        ? 'Save Transaction'
                        : 'Update Transaction',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      [allowDecimal ? '.' : '000', '0', 'BACK'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: row.map((key) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: context.appColors.canvas,
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
                        height: 44,
                        child: Center(
                          child: key == 'BACK'
                              ? const Icon(Icons.backspace_outlined, size: 20)
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
    );
  }
}
