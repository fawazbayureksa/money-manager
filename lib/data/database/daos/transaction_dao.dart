import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'transaction_dao.g.dart';

class TransactionDetail {
  const TransactionDetail({
    required this.transaction,
    required this.wallet,
    this.destinationWallet,
    this.category,
  });

  final Transaction transaction;
  final Wallet wallet;
  final Wallet? destinationWallet;
  final Category? category;
}

@DriftAccessor(tables: [Transactions, Wallets, Categories])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  Stream<List<TransactionDetail>> watchTransactions({
    DateTime? start,
    DateTime? end,
    int? walletId,
    int? categoryId,
    String? txType,
    String? searchQuery,
  }) {
    final destWallets = alias(wallets, 'dest_wallets');
    final query = select(transactions).join([
      innerJoin(wallets, wallets.id.equalsExp(transactions.walletId)),
      leftOuterJoin(
        destWallets,
        destWallets.id.equalsExp(transactions.destinationWalletId),
      ),
      leftOuterJoin(
        categories,
        categories.id.equalsExp(transactions.categoryId),
      ),
    ]);

    if (start != null) {
      query.where(transactions.transactionDate.isBiggerOrEqualValue(start));
    }
    if (end != null) {
      query.where(transactions.transactionDate.isSmallerThanValue(end));
    }
    if (walletId != null) {
      query.where(
        transactions.walletId.equals(walletId) |
            transactions.destinationWalletId.equals(walletId),
      );
    }
    if (categoryId != null) {
      query.where(transactions.categoryId.equals(categoryId));
    }
    if (txType != null) {
      query.where(transactions.txType.equals(txType));
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim()}%';
      query.where(transactions.note.like(q) | categories.name.like(q));
    }

    query.orderBy([
      OrderingTerm.desc(transactions.transactionDate),
      OrderingTerm.desc(transactions.id),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionDetail(
          transaction: row.readTable(transactions),
          wallet: row.readTable(wallets),
          destinationWallet: row.readTableOrNull(destWallets),
          category: row.readTableOrNull(categories),
        );
      }).toList();
    });
  }

  Future<int> createTransaction(TransactionsCompanion entry) {
    return into(transactions).insert(entry);
  }

  Future<bool> updateTransaction(TransactionsCompanion entry) {
    return update(transactions).replace(entry);
  }

  Future<int> deleteTransaction(int id) {
    return (delete(transactions)..where((t) => t.id.equals(id))).go();
  }
}
