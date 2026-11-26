import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/app_database.dart';

class WalletFormSheet extends ConsumerStatefulWidget {
  const WalletFormSheet({super.key, this.existing});

  final Wallet? existing;

  @override
  ConsumerState<WalletFormSheet> createState() => _WalletFormSheetState();
}

class _WalletFormSheetState extends ConsumerState<WalletFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _initialCtrl;
  late String _walletType;
  late int _iconCodePoint;
  late int _colorValue;

  static const _walletTypes = [
    ('cash', 'Cash'),
    ('bank', 'Bank'),
    ('ewallet', 'E-Wallet'),
    ('savings', 'Savings'),
  ];

  @override
  void initState() {
    super.initState();
    final w = widget.existing;
    final currency = ref.read(settingsProvider).currency;
    _nameCtrl = TextEditingController(text: w?.name ?? '');
    _initialCtrl = TextEditingController(
      text: w != null
          ? CurrencyFormatter.minorToInputString(w.initialBalanceMinor, currency)
          : '',
    );
    _walletType = w?.walletType ?? 'cash';
    _iconCodePoint =
        w?.iconCodePoint ?? Icons.account_balance_wallet_rounded.codePoint;
    _colorValue = w?.colorValue ?? kSwatchColors.first.toARGB32();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _initialCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(settingsProvider).currency;
    final isEdit = widget.existing != null;

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
                isEdit ? 'Edit Wallet' : 'New Wallet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Wallet Name',
                  hintText: 'e.g., Main Bank, Cash, GoPay',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _initialCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Initial Balance (${currency.symbol})',
                  hintText: '0',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Type',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _walletTypes.map((t) {
                  final selected = _walletType == t.$1;
                  return ChoiceChip(
                    label: Text(t.$2),
                    selected: selected,
                    onSelected: (_) => setState(() => _walletType = t.$1),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                'Color',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: kSwatchColors.map((c) {
                  final val = c.toARGB32();
                  final selected = _colorValue == val;
                  return GestureDetector(
                    onTap: () => setState(() => _colorValue = val),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 3,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                'Icon',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kAppIcons.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final icon = kAppIcons[index];
                    final selected = icon.codePoint == _iconCodePoint;
                    return InkWell(
                      onTap: () =>
                          setState(() => _iconCodePoint = icon.codePoint),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: selected
                              ? Color(_colorValue).withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? Color(_colorValue)
                                : Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: selected ? Color(_colorValue) : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(isEdit ? 'Save Changes' : 'Create Wallet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final currency = ref.read(settingsProvider).currency;
    final initialMinor =
        CurrencyFormatter.parseToMinor(_initialCtrl.text, currency);
    final dao = ref.read(databaseProvider).walletDao;

    if (widget.existing == null) {
      await dao.createWallet(
        WalletsCompanion.insert(
          name: _nameCtrl.text.trim(),
          walletType: Value(_walletType),
          initialBalanceMinor: Value(initialMinor),
          iconCodePoint: _iconCodePoint,
          colorValue: _colorValue,
        ),
      );
    } else {
      final w = widget.existing!;
      await dao.updateWallet(
        WalletsCompanion(
          id: Value(w.id),
          name: Value(_nameCtrl.text.trim()),
          walletType: Value(_walletType),
          initialBalanceMinor: Value(initialMinor),
          iconCodePoint: Value(_iconCodePoint),
          colorValue: Value(_colorValue),
          isArchived: Value(w.isArchived),
          sortOrder: Value(w.sortOrder),
          createdAt: Value(w.createdAt),
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }
}
