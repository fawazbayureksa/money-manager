import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_segmented_tabs.dart';
import '../../data/database/app_database.dart';

class CategoryFormSheet extends ConsumerStatefulWidget {
  const CategoryFormSheet({
    super.key,
    required this.initialType,
    this.existing,
  });

  final String initialType;
  final Category? existing;

  @override
  ConsumerState<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late String _categoryType;
  late int _iconCodePoint;
  late int _colorValue;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _categoryType = c?.categoryType ?? widget.initialType;
    _iconCodePoint = c?.iconCodePoint ?? Icons.restaurant_rounded.codePoint;
    _colorValue = c?.colorValue ?? kSwatchColors.first.toARGB32();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                isEdit ? 'Edit Category' : 'New Category',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              if (!isEdit) ...[
                AppSegmentedTabs<String>(
                  height: 46,
                  borderRadius: 15,
                  selectedValue: _categoryType,
                  onChanged: (v) => setState(() => _categoryType = v),
                  options: [
                    AppTabOption(
                      value: 'expense',
                      label: 'Expense',
                      icon: Icons.north_east_rounded,
                      accentColor: context.appColors.expense,
                      softColor: context.appColors.expenseSoft,
                    ),
                    AppTabOption(
                      value: 'income',
                      label: 'Income',
                      icon: Icons.south_west_rounded,
                      accentColor: context.appColors.income,
                      softColor: context.appColors.incomeSoft,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 16),
              Text('Color', style: Theme.of(context).textTheme.labelLarge),
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
              Text('Icon', style: Theme.of(context).textTheme.labelLarge),
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
                  child: Text(isEdit ? 'Save Changes' : 'Create Category'),
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
    final dao = ref.read(databaseProvider).categoryDao;

    if (widget.existing == null) {
      await dao.createCategory(
        CategoriesCompanion.insert(
          name: _nameCtrl.text.trim(),
          categoryType: _categoryType,
          iconCodePoint: _iconCodePoint,
          colorValue: _colorValue,
        ),
      );
    } else {
      final c = widget.existing!;
      await dao.updateCategory(
        CategoriesCompanion(
          id: Value(c.id),
          name: Value(_nameCtrl.text.trim()),
          categoryType: Value(c.categoryType),
          iconCodePoint: Value(_iconCodePoint),
          colorValue: Value(_colorValue),
          isSystemDefault: Value(c.isSystemDefault),
          isArchived: Value(c.isArchived),
          sortOrder: Value(c.sortOrder),
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }
}
