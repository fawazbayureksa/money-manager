import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/constants/app_constants.dart';
import 'package:money_manager/core/utils/currency_formatter.dart';
import 'package:money_manager/core/utils/date_utils.dart';
import 'package:money_manager/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('CurrencyFormatter formats and parses 2-decimal and 0-decimal currencies', () {
    final usd = currencyPresetByCode('USD');
    final idr = currencyPresetByCode('IDR');

    expect(CurrencyFormatter.format(125050, usd), '\$1,250.50');
    expect(CurrencyFormatter.parseToMinor('12.34', usd), 1234);

    expect(CurrencyFormatter.format(150000, idr), 'Rp 150.000');
    expect(CurrencyFormatter.parseToMinor('150000', idr), 150000);
  });

  test('AppDateUtils.advanceDueDate clamps end-of-month safely', () {
    final jan31 = DateTime(2025, 1, 31);
    expect(
      AppDateUtils.advanceDueDate(jan31, BillFrequency.monthly),
      DateTime(2025, 2, 28),
    );

    final jan31Leap = DateTime(2024, 1, 31);
    expect(
      AppDateUtils.advanceDueDate(jan31Leap, BillFrequency.monthly),
      DateTime(2024, 2, 29),
    );
  });

  test('Multi-wallet balances and reports exclude transfers from income/expense', () async {
    // Default Cash wallet is seeded with id 1. Add Bank wallet (id 2).
    final bankId = await db.walletDao.createWallet(
      WalletsCompanion.insert(
        name: 'Bank',
        walletType: const Value('bank'),
        initialBalanceMinor: const Value(100000), // $1,000.00
        iconCodePoint: Icons.account_balance_rounded.codePoint,
        colorValue: 0xFF4F46E5,
      ),
    );

    final now = DateTime(2026, 5, 10, 12, 0);

    // Income +$500.00 to Bank
    await db.transactionDao.createTransaction(
      TransactionsCompanion.insert(
        txType: 'income',
        amountMinor: 50000,
        walletId: bankId,
        transactionDate: now,
      ),
    );

    // Expense -$120.00 from Bank
    await db.transactionDao.createTransaction(
      TransactionsCompanion.insert(
        txType: 'expense',
        amountMinor: 12000,
        walletId: bankId,
        transactionDate: now,
      ),
    );

    // Transfer $200.00 from Bank -> Cash (id 1)
    await db.transactionDao.createTransaction(
      TransactionsCompanion.insert(
        txType: 'transfer',
        amountMinor: 20000,
        walletId: bankId,
        destinationWalletId: const Value(1),
        transactionDate: now,
      ),
    );

    final wallets = await db.walletDao.watchWalletsWithBalances().first;
    final cash = wallets.firstWhere((w) => w.wallet.id == 1);
    final bank = wallets.firstWhere((w) => w.wallet.id == bankId);

    expect(cash.balanceMinor, 20000); // 0 + 200.00
    expect(bank.balanceMinor, 118000); // 1000 + 500 - 120 - 200 = 1180.00

    final summary = await db.reportDao
        .watchPeriodSummary(
          DateTime(2026, 5, 1),
          DateTime(2026, 6, 1),
        )
        .first;
    expect(summary.incomeMinor, 50000);
    expect(summary.expenseMinor, 12000);
  });

  test('Recurring bill markAsPaid logs expense and advances nextDueDate', () async {
    final cats = await db.categoryDao.getAllCategories();
    final expenseCat = cats.firstWhere((c) => c.categoryType == 'expense');

    final billId = await db.billDao.createBill(
      RecurringBillsCompanion.insert(
        title: 'Internet',
        amountMinor: 4500,
        walletId: 1,
        categoryId: expenseCat.id,
        frequency: 'monthly',
        nextDueDate: DateTime(2026, 1, 31),
      ),
    );

    final bills = await db.billDao.watchBills(isActive: true).first;
    final detail = bills.firstWhere((b) => b.bill.id == billId);

    await db.billDao.markAsPaid(
      detail.bill,
      paidAt: DateTime(2026, 1, 31, 9, 0),
    );

    final updatedBills = await db.billDao.watchBills(isActive: true).first;
    final updated = updatedBills.firstWhere((b) => b.bill.id == billId);
    expect(updated.bill.nextDueDate, DateTime(2026, 2, 28));

    final txs = await db.transactionDao.watchTransactions().first;
    expect(txs.length, 1);
    expect(txs.first.transaction.recurringBillId, billId);
    expect(txs.first.transaction.amountMinor, 4500);
    expect(txs.first.transaction.txType, 'expense');
  });
}
