import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'wallet_dao.g.dart';

class WalletWithBalance {
  const WalletWithBalance({
    required this.wallet,
    required this.balanceMinor,
    required this.transactionCount,
  });

  final Wallet wallet;
  final int balanceMinor;
  final int transactionCount;
}

@DriftAccessor(tables: [Wallets, Transactions])
class WalletDao extends DatabaseAccessor<AppDatabase> with _$WalletDaoMixin {
  WalletDao(super.db);

  Stream<List<WalletWithBalance>> watchWalletsWithBalances({
    bool includeArchived = false,
  }) {
    final walletQuery = select(wallets)
      ..orderBy([
        (w) => OrderingTerm.asc(w.isArchived),
        (w) => OrderingTerm.asc(w.sortOrder),
        (w) => OrderingTerm.asc(w.id),
      ]);
    if (!includeArchived) {
      walletQuery.where((w) => w.isArchived.equals(false));
    }

    // Watch both wallets and transactions so balances update reactively.
    return customSelect(
      '''
      SELECT w.*,
        COALESCE((
          SELECT SUM(CASE
            WHEN t.tx_type = 'income' AND t.wallet_id = w.id THEN t.amount_minor
            WHEN t.tx_type = 'expense' AND t.wallet_id = w.id THEN -t.amount_minor
            WHEN t.tx_type = 'transfer' AND t.wallet_id = w.id THEN -t.amount_minor
            WHEN t.tx_type = 'transfer' AND t.destination_wallet_id = w.id THEN t.amount_minor
            ELSE 0
          END)
          FROM transactions t
          WHERE t.wallet_id = w.id OR t.destination_wallet_id = w.id
        ), 0) AS net_delta,
        (
          SELECT COUNT(*)
          FROM transactions t
          WHERE t.wallet_id = w.id OR t.destination_wallet_id = w.id
        ) AS tx_count
      FROM wallets w
      ${includeArchived ? '' : 'WHERE w.is_archived = 0'}
      ORDER BY w.is_archived ASC, w.sort_order ASC, w.id ASC
      ''',
      readsFrom: {wallets, transactions},
    ).watch().map((rows) {
      return rows.map((row) {
        final wallet = wallets.map(row.data);
        final netDelta = row.read<int>('net_delta');
        final txCount = row.read<int>('tx_count');
        return WalletWithBalance(
          wallet: wallet,
          balanceMinor: wallet.initialBalanceMinor + netDelta,
          transactionCount: txCount,
        );
      }).toList();
    });
  }

  Future<List<Wallet>> getAllWallets() {
    return (select(wallets)
          ..orderBy([
            (w) => OrderingTerm.asc(w.sortOrder),
            (w) => OrderingTerm.asc(w.id),
          ]))
        .get();
  }

  Future<int> createWallet(WalletsCompanion entry) {
    return into(wallets).insert(entry);
  }

  Future<bool> updateWallet(WalletsCompanion entry) {
    return update(wallets).replace(entry);
  }

  Future<void> setArchived(int walletId, bool archived) {
    return (update(wallets)..where((w) => w.id.equals(walletId)))
        .write(WalletsCompanion(isArchived: Value(archived)));
  }

  Future<void> deleteWalletWithTransactions(int walletId) {
    return transaction(() async {
      await (delete(transactions)
            ..where(
              (t) =>
                  t.walletId.equals(walletId) |
                  t.destinationWalletId.equals(walletId),
            ))
          .go();
      await (delete(wallets)..where((w) => w.id.equals(walletId))).go();
    });
  }
}
