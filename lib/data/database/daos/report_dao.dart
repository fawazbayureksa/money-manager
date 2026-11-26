import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'report_dao.g.dart';

class PeriodSummary {
  const PeriodSummary({
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final int incomeMinor;
  final int expenseMinor;

  int get netMinor => incomeMinor - expenseMinor;
}

class CategoryBreakdown {
  const CategoryBreakdown({
    required this.category,
    required this.totalMinor,
    required this.percentage,
  });

  final Category category;
  final int totalMinor;
  final double percentage;
}

@DriftAccessor(tables: [Transactions, Categories])
class ReportDao extends DatabaseAccessor<AppDatabase> with _$ReportDaoMixin {
  ReportDao(super.db);

  /// Computes total Income and Expense in [start, end), strictly excluding
  /// wallet-to-wallet transfers.
  Stream<PeriodSummary> watchPeriodSummary(
    DateTime start,
    DateTime end, {
    int? walletId,
  }) {
    final walletFilter = walletId != null ? 'AND wallet_id = ?' : '';
    final variables = <Variable<Object>>[
      Variable.withDateTime(start),
      Variable.withDateTime(end),
      if (walletId != null) Variable.withInt(walletId),
    ];

    return customSelect(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN tx_type = 'income' THEN amount_minor ELSE 0 END), 0) AS total_income,
        COALESCE(SUM(CASE WHEN tx_type = 'expense' THEN amount_minor ELSE 0 END), 0) AS total_expense
      FROM transactions
      WHERE transaction_date >= ? AND transaction_date < ?
        AND tx_type IN ('income', 'expense')
        $walletFilter
      ''',
      variables: variables,
      readsFrom: {transactions},
    ).watchSingle().map((row) {
      return PeriodSummary(
        incomeMinor: row.read<int>('total_income'),
        expenseMinor: row.read<int>('total_expense'),
      );
    });
  }

  Stream<List<CategoryBreakdown>> watchCategoryBreakdown({
    required DateTime start,
    required DateTime end,
    required String txType, // 'expense' | 'income'
  }) {
    return customSelect(
      '''
      SELECT c.*, SUM(t.amount_minor) AS cat_total
      FROM transactions t
      INNER JOIN categories c ON c.id = t.category_id
      WHERE t.transaction_date >= ? AND t.transaction_date < ?
        AND t.tx_type = ?
      GROUP BY c.id
      ORDER BY cat_total DESC
      ''',
      variables: [
        Variable.withDateTime(start),
        Variable.withDateTime(end),
        Variable.withString(txType),
      ],
      readsFrom: {transactions, categories},
    ).watch().map((rows) {
      final grandTotal = rows.fold<int>(
        0,
        (sum, r) => sum + r.read<int>('cat_total'),
      );
      return rows.map((r) {
        final total = r.read<int>('cat_total');
        final pct = grandTotal == 0 ? 0.0 : (total / grandTotal) * 100.0;
        return CategoryBreakdown(
          category: categories.map(r.data),
          totalMinor: total,
          percentage: pct,
        );
      }).toList();
    });
  }
}
