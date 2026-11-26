import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart';
import '../../data/database/app_database.dart';

class BillFormSheet extends ConsumerStatefulWidget {
  const BillFormSheet({super.key, this.existing});

  final RecurringBill? existing;

  @override
  ConsumerState<BillFormSheet> createState() => _BillFormSheetState();
}

class _BillFormSheetState extends ConsumerState<BillFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;

  late BillFrequency _frequency;
  late DateTime _nextDueDate;
  int? _walletId;
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    final currency = ref.read(settingsProvider).currency;
    _titleCtrl = TextEditingController(text: b?.title ?? '');
    _amountCtrl = TextEditingController(
      text: b != null
          ? CurrencyFormatter.minorToInputString(b.amountMinor, currency)
          : '',
    );
    _noteCtrl = TextEditingController(text: b?.note ?? '');
    _frequency = b != null
        ? BillFrequency.values.firstWhere(
            (e) => e.name == b.frequency,
            orElse: () => BillFrequency.monthly,
          )
        : BillFrequency.monthly;
    _nextDueDate = b?.nextDueDate ?? AppDateUtils.dateOnly(DateTime.now());
    _walletId = b?.walletId;
    _categoryId = b?.categoryId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(settingsProvider).currency;
    final wallets = ref.watch(walletsProvider).valueOrNull ?? [];
    final categories = ref.watch(expenseCategoriesProvider).valueOrNull ?? [];

    if (_walletId == null && wallets.isNotEmpty) {
      _walletId = wallets.first.wallet.id;
    }
    if (_categoryId == null && categories.isNotEmpty) {
      _categoryId = categories.first.id;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null ? 'New Recurring Bill' : 'Edit Bill',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Bill Title',
                  hintText: 'e.g., Internet, Rent, Spotify',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (${currency.symbol})',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final amt =
                      CurrencyFormatter.parseToMinor(v ?? '', currency);
                  return amt <= 0 ? 'Enter an amount > 0' : null;
                },
              ),
              const SizedBox(height: 14),
              Text('Frequency', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: BillFrequency.values.map((f) {
                  return ChoiceChip(
                    label: Text(
                      f.name[0].toUpperCase() + f.name.substring(1),
                    ),
                    selected: _frequency == f,
                    onSelected: (_) => setState(() => _frequency = f),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: const Text('Next Due Date'),
                subtitle: Text(DateFormat('EEE, d MMM yyyy').format(_nextDueDate)),
                trailing: TextButton(
                  onPressed: _pickDate,
                  child: const Text('Change'),
                ),
              ),
              const SizedBox(height: 8),
              Text('Pay From Wallet',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: wallets.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final w = wallets[index].wallet;
                    return ChoiceChip(
                      label: Text(w.name),
                      selected: w.id == _walletId,
                      onSelected: (_) => setState(() => _walletId = w.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Text('Category', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final c = categories[index];
                    return ChoiceChip(
                      avatar: Icon(
                        appIconFromCode(c.iconCodePoint),
                        size: 16,
                      ),
                      label: Text(c.name),
                      selected: c.id == _categoryId,
                      onSelected: (_) => setState(() => _categoryId = c.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(
                    widget.existing == null ? 'Create Bill' : 'Save Changes',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _nextDueDate = AppDateUtils.dateOnly(picked));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_walletId == null || _categoryId == null) return;

    final currency = ref.read(settingsProvider).currency;
    final amountMinor =
        CurrencyFormatter.parseToMinor(_amountCtrl.text, currency);
    final dao = ref.read(databaseProvider).billDao;

    if (widget.existing == null) {
      await dao.createBill(
        RecurringBillsCompanion.insert(
          title: _titleCtrl.text.trim(),
          amountMinor: amountMinor,
          walletId: _walletId!,
          categoryId: _categoryId!,
          frequency: _frequency.name,
          nextDueDate: _nextDueDate,
          note: Value(_noteCtrl.text.trim()),
        ),
      );
    } else {
      final b = widget.existing!;
      await dao.updateBill(
        RecurringBillsCompanion(
          id: Value(b.id),
          title: Value(_titleCtrl.text.trim()),
          amountMinor: Value(amountMinor),
          walletId: Value(_walletId!),
          categoryId: Value(_categoryId!),
          frequency: Value(_frequency.name),
          nextDueDate: Value(_nextDueDate),
          isActive: Value(b.isActive),
          note: Value(_noteCtrl.text.trim()),
          createdAt: Value(b.createdAt),
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }
}
