import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_segmented_tabs.dart';
import '../../data/database/app_database.dart';
import 'category_form_sheet.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _selectedType = 'expense';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
  }

  void _handleTabChanged() {
    final nextType = _tabController.index == 0 ? 'expense' : 'income';
    if (_selectedType != nextType) {
      setState(() => _selectedType = nextType);
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

  void _selectType(String type) {
    final index = type == 'expense' ? 0 : 1;
    if (_selectedType != type) {
      setState(() => _selectedType = type);
    }
    if (_tabController.index != index) {
      _tabController.animateTo(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final expenseCatsAsync = ref.watch(expenseCategoriesProvider);
    final incomeCatsAsync = ref.watch(incomeCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Categories',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Add Category',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => _openForm(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: AppSegmentedTabs<String>(
              selectedValue: _selectedType,
              onChanged: _selectType,
              options: [
                AppTabOption(
                  value: 'expense',
                  label: 'Expense',
                  icon: Icons.north_east_rounded,
                  count: expenseCatsAsync.valueOrNull?.length,
                  accentColor: colors.expense,
                  softColor: colors.expenseSoft,
                ),
                AppTabOption(
                  value: 'income',
                  label: 'Income',
                  icon: Icons.south_west_rounded,
                  count: incomeCatsAsync.valueOrNull?.length,
                  accentColor: colors.income,
                  softColor: colors.incomeSoft,
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryList(context, expenseCatsAsync, 'expense'),
                _buildCategoryList(context, incomeCatsAsync, 'income'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(
    BuildContext context,
    AsyncValue<List<Category>> catsAsync,
    String type,
  ) {
    final colors = context.appColors;

    return catsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (cats) {
        if (cats.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 44,
                  color: colors.mutedText,
                ),
                const SizedBox(height: 10),
                Text(
                  'No $type categories yet',
                  style: TextStyle(color: colors.mutedText),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
          itemCount: cats.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, index) {
            final cat = cats[index];
            final color = Color(cat.colorValue);
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(
                    appIconFromCode(cat.iconCodePoint),
                    color: color,
                  ),
                ),
                title: Text(
                  cat.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: colors.mutedText,
                  ),
                  onPressed: () => _deleteCategory(context, cat),
                ),
                onTap: () => _openForm(context, existing: cat),
              ),
            );
          },
        );
      },
    );
  }

  void _openForm(BuildContext context, {Category? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CategoryFormSheet(
        initialType: _selectedType,
        existing: existing,
      ),
    );
  }

  Future<void> _deleteCategory(BuildContext context, Category cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove "${cat.name}"?'),
        content: const Text(
          'If this category is used in existing transactions, it will be archived to preserve your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref
          .read(databaseProvider)
          .categoryDao
          .archiveOrDeleteCategory(cat.id);
    }
  }
}
