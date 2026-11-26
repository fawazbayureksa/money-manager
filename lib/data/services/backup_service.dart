import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';

class BackupService {
  const BackupService(this.db);

  final AppDatabase db;

  Future<File> exportToJsonFile() async {
    final walletsList = await db.select(db.wallets).get();
    final categoriesList = await db.select(db.categories).get();
    final billsList = await db.select(db.recurringBills).get();
    final txList = await db.select(db.transactions).get();

    final payload = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'wallets': walletsList
          .map((w) => {
                'id': w.id,
                'name': w.name,
                'walletType': w.walletType,
                'initialBalanceMinor': w.initialBalanceMinor,
                'iconCodePoint': w.iconCodePoint,
                'colorValue': w.colorValue,
                'isArchived': w.isArchived,
                'sortOrder': w.sortOrder,
                'createdAt': w.createdAt.toIso8601String(),
              })
          .toList(),
      'categories': categoriesList
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'categoryType': c.categoryType,
                'iconCodePoint': c.iconCodePoint,
                'colorValue': c.colorValue,
                'isSystemDefault': c.isSystemDefault,
                'isArchived': c.isArchived,
                'sortOrder': c.sortOrder,
              })
          .toList(),
      'recurringBills': billsList
          .map((b) => {
                'id': b.id,
                'title': b.title,
                'amountMinor': b.amountMinor,
                'walletId': b.walletId,
                'categoryId': b.categoryId,
                'frequency': b.frequency,
                'nextDueDate': b.nextDueDate.toIso8601String(),
                'isActive': b.isActive,
                'note': b.note,
                'createdAt': b.createdAt.toIso8601String(),
              })
          .toList(),
      'transactions': txList
          .map((t) => {
                'id': t.id,
                'txType': t.txType,
                'amountMinor': t.amountMinor,
                'walletId': t.walletId,
                'destinationWalletId': t.destinationWalletId,
                'categoryId': t.categoryId,
                'recurringBillId': t.recurringBillId,
                'note': t.note,
                'transactionDate': t.transactionDate.toIso8601String(),
                'createdAt': t.createdAt.toIso8601String(),
              })
          .toList(),
    };

    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(p.join(dir.path, 'money_manager_backup_$timestamp.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return file;
  }

  Future<void> restoreFromJsonString(String jsonStr) async {
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    if (decoded['version'] != 1) {
      throw const FormatException('Unsupported backup version');
    }

    final walletsJson = (decoded['wallets'] as List).cast<Map<String, dynamic>>();
    final categoriesJson =
        (decoded['categories'] as List).cast<Map<String, dynamic>>();
    final billsJson =
        (decoded['recurringBills'] as List).cast<Map<String, dynamic>>();
    final txJson =
        (decoded['transactions'] as List).cast<Map<String, dynamic>>();

    await db.transaction(() async {
      await db.delete(db.transactions).go();
      await db.delete(db.recurringBills).go();
      await db.delete(db.categories).go();
      await db.delete(db.wallets).go();

      for (final w in walletsJson) {
        await db.into(db.wallets).insert(
              WalletsCompanion.insert(
                id: Value(w['id'] as int),
                name: w['name'] as String,
                walletType: Value(w['walletType'] as String),
                initialBalanceMinor: Value(w['initialBalanceMinor'] as int),
                iconCodePoint: w['iconCodePoint'] as int,
                colorValue: w['colorValue'] as int,
                isArchived: Value(w['isArchived'] as bool),
                sortOrder: Value(w['sortOrder'] as int),
                createdAt: Value(DateTime.parse(w['createdAt'] as String)),
              ),
            );
      }

      for (final c in categoriesJson) {
        await db.into(db.categories).insert(
              CategoriesCompanion.insert(
                id: Value(c['id'] as int),
                name: c['name'] as String,
                categoryType: c['categoryType'] as String,
                iconCodePoint: c['iconCodePoint'] as int,
                colorValue: c['colorValue'] as int,
                isSystemDefault: Value(c['isSystemDefault'] as bool),
                isArchived: Value(c['isArchived'] as bool),
                sortOrder: Value(c['sortOrder'] as int),
              ),
            );
      }

      for (final b in billsJson) {
        await db.into(db.recurringBills).insert(
              RecurringBillsCompanion.insert(
                id: Value(b['id'] as int),
                title: b['title'] as String,
                amountMinor: b['amountMinor'] as int,
                walletId: b['walletId'] as int,
                categoryId: b['categoryId'] as int,
                frequency: b['frequency'] as String,
                nextDueDate: DateTime.parse(b['nextDueDate'] as String),
                isActive: Value(b['isActive'] as bool),
                note: Value(b['note'] as String),
                createdAt: Value(DateTime.parse(b['createdAt'] as String)),
              ),
            );
      }

      for (final t in txJson) {
        await db.into(db.transactions).insert(
              TransactionsCompanion.insert(
                id: Value(t['id'] as int),
                txType: t['txType'] as String,
                amountMinor: t['amountMinor'] as int,
                walletId: t['walletId'] as int,
                destinationWalletId: Value(t['destinationWalletId'] as int?),
                categoryId: Value(t['categoryId'] as int?),
                recurringBillId: Value(t['recurringBillId'] as int?),
                note: Value(t['note'] as String),
                transactionDate: DateTime.parse(t['transactionDate'] as String),
                createdAt: Value(DateTime.parse(t['createdAt'] as String)),
              ),
            );
      }
    });
  }
}
