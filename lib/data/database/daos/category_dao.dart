import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [Categories, Transactions, RecurringBills])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  Stream<List<Category>> watchCategories({
    String? categoryType,
    bool includeArchived = false,
  }) {
    final query = select(categories)
      ..orderBy([
        (c) => OrderingTerm.asc(c.sortOrder),
        (c) => OrderingTerm.asc(c.id),
      ]);
    if (categoryType != null) {
      query.where((c) => c.categoryType.equals(categoryType));
    }
    if (!includeArchived) {
      query.where((c) => c.isArchived.equals(false));
    }
    return query.watch();
  }

  Future<List<Category>> getAllCategories() {
    return (select(categories)
          ..orderBy([
            (c) => OrderingTerm.asc(c.sortOrder),
            (c) => OrderingTerm.asc(c.id),
          ]))
        .get();
  }

  Future<int> createCategory(CategoriesCompanion entry) {
    return into(categories).insert(entry);
  }

  Future<bool> updateCategory(CategoriesCompanion entry) {
    return update(categories).replace(entry);
  }

  Future<int> countUsage(int categoryId) async {
    final txCount = await (select(transactions)
          ..where((t) => t.categoryId.equals(categoryId)))
        .get()
        .then((l) => l.length);
    final billCount = await (select(recurringBills)
          ..where((b) => b.categoryId.equals(categoryId)))
        .get()
        .then((l) => l.length);
    return txCount + billCount;
  }

  Future<void> archiveOrDeleteCategory(int categoryId) async {
    final used = await countUsage(categoryId);
    if (used > 0) {
      await (update(categories)..where((c) => c.id.equals(categoryId)))
          .write(const CategoriesCompanion(isArchived: Value(true)));
    } else {
      await (delete(categories)..where((c) => c.id.equals(categoryId))).go();
    }
  }
}
