import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart' show Icons;

import 'daos/bill_dao.dart';
import 'daos/category_dao.dart';
import 'daos/report_dao.dart';
import 'daos/transaction_dao.dart';
import 'daos/wallet_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Wallets, Categories, RecurringBills, Transactions],
  daos: [WalletDao, CategoryDao, TransactionDao, BillDao, ReportDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'money_manager_db');
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await _seedDefaults();
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _seedDefaults() async {
    await into(wallets).insert(
      WalletsCompanion.insert(
        name: 'Cash',
        walletType: const Value('cash'),
        initialBalanceMinor: const Value(0),
        iconCodePoint: Icons.account_balance_wallet_rounded.codePoint,
        colorValue: 0xFF0D9488,
        sortOrder: const Value(0),
      ),
    );

    final defaultCategories = [
      // Expense
      ('Food', 'expense', Icons.restaurant_rounded.codePoint, 0xFFF97316, 0),
      ('Transport', 'expense', Icons.directions_car_rounded.codePoint, 0xFF2563EB, 1),
      ('Shopping', 'expense', Icons.shopping_bag_rounded.codePoint, 0xFF9333EA, 2),
      ('Bills', 'expense', Icons.receipt_long_rounded.codePoint, 0xFFE11D48, 3),
      ('Health', 'expense', Icons.medical_services_rounded.codePoint, 0xFF0891B2, 4),
      ('Entertainment', 'expense', Icons.movie_rounded.codePoint, 0xFFD97706, 5),
      // Income
      ('Salary', 'income', Icons.payments_rounded.codePoint, 0xFF0D9488, 0),
      ('Bonus', 'income', Icons.trending_up_rounded.codePoint, 0xFF16A34A, 1),
      ('Gift', 'income', Icons.card_giftcard_rounded.codePoint, 0xFF4F46E5, 2),
      ('Other', 'income', Icons.more_horiz_rounded.codePoint, 0xFF475569, 3),
    ];

    for (final cat in defaultCategories) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: cat.$1,
          categoryType: cat.$2,
          iconCodePoint: cat.$3,
          colorValue: cat.$4,
          isSystemDefault: const Value(true),
          sortOrder: Value(cat.$5),
        ),
      );
    }
  }
}
