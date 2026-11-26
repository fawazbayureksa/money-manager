import 'package:drift/drift.dart';
import '../../../core/utils/date_utils.dart';
import '../app_database.dart';
import '../tables.dart';

part 'bill_dao.g.dart';

class RecurringBillDetail {
  const RecurringBillDetail({
    required this.bill,
    required this.wallet,
    required this.category,
  });

  final RecurringBill bill;
  final Wallet wallet;
  final Category category;
}

@DriftAccessor(tables: [RecurringBills, Wallets, Categories, Transactions])
class BillDao extends DatabaseAccessor<AppDatabase> with _$BillDaoMixin {
  BillDao(super.db);

  Stream<List<RecurringBillDetail>> watchBills({bool? isActive}) {
    final query = select(recurringBills).join([
      innerJoin(wallets, wallets.id.equalsExp(recurringBills.walletId)),
      innerJoin(categories, categories.id.equalsExp(recurringBills.categoryId)),
    ]);

    if (isActive != null) {
      query.where(recurringBills.isActive.equals(isActive));
    }

    query.orderBy([
      OrderingTerm.asc(recurringBills.nextDueDate),
      OrderingTerm.asc(recurringBills.id),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return RecurringBillDetail(
          bill: row.readTable(recurringBills),
          wallet: row.readTable(wallets),
          category: row.readTable(categories),
        );
      }).toList();
    });
  }

  Future<int> createBill(RecurringBillsCompanion entry) {
    return into(recurringBills).insert(entry);
  }

  Future<bool> updateBill(RecurringBillsCompanion entry) {
    return update(recurringBills).replace(entry);
  }

  Future<void> setBillActive(int billId, bool active) {
    return (update(recurringBills)..where((b) => b.id.equals(billId)))
        .write(RecurringBillsCompanion(isActive: Value(active)));
  }

  Future<int> deleteBill(int billId) {
    return (delete(recurringBills)..where((b) => b.id.equals(billId))).go();
  }

  /// Atomically logs an Expense transaction for [bill] and advances [nextDueDate].
  Future<void> markAsPaid(
    RecurringBill bill, {
    int? overrideAmountMinor,
    DateTime? paidAt,
  }) {
    final now = paidAt ?? DateTime.now();
    final freq = BillFrequency.values.firstWhere(
      (e) => e.name == bill.frequency,
      orElse: () => BillFrequency.monthly,
    );
    final nextDue = AppDateUtils.advanceDueDate(bill.nextDueDate, freq);

    return transaction(() async {
      await into(transactions).insert(
        TransactionsCompanion.insert(
          txType: 'expense',
          amountMinor: overrideAmountMinor ?? bill.amountMinor,
          walletId: bill.walletId,
          categoryId: Value(bill.categoryId),
          recurringBillId: Value(bill.id),
          note: Value(
            bill.note.isEmpty ? bill.title : '${bill.title} • ${bill.note}',
          ),
          transactionDate: now,
        ),
      );

      await (update(recurringBills)..where((b) => b.id.equals(bill.id))).write(
        RecurringBillsCompanion(nextDueDate: Value(nextDue)),
      );
    });
  }
}
