import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import '../../data/database/daos/bill_dao.dart';
import '../../data/database/daos/wallet_dao.dart';
import '../../data/services/backup_service.dart';
import '../../data/services/settings_service.dart';
import '../utils/date_utils.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseProvider));
});

final walletsProvider = StreamProvider<List<WalletWithBalance>>((ref) {
  return ref.watch(databaseProvider).walletDao.watchWalletsWithBalances();
});

final allWalletsProvider = StreamProvider<List<WalletWithBalance>>((ref) {
  return ref
      .watch(databaseProvider)
      .walletDao
      .watchWalletsWithBalances(includeArchived: true);
});

final totalNetWorthProvider = Provider<int>((ref) {
  final wallets = ref.watch(walletsProvider).valueOrNull ?? [];
  return wallets.fold<int>(0, (sum, w) => sum + w.balanceMinor);
});

final expenseCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref
      .watch(databaseProvider)
      .categoryDao
      .watchCategories(categoryType: 'expense');
});

final incomeCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref
      .watch(databaseProvider)
      .categoryDao
      .watchCategories(categoryType: 'income');
});

final activeBillsProvider = StreamProvider<List<RecurringBillDetail>>((ref) {
  return ref.watch(databaseProvider).billDao.watchBills(isActive: true);
});

final pausedBillsProvider = StreamProvider<List<RecurringBillDetail>>((ref) {
  return ref.watch(databaseProvider).billDao.watchBills(isActive: false);
});

final dueBillsProvider = Provider<List<RecurringBillDetail>>((ref) {
  final active = ref.watch(activeBillsProvider).valueOrNull ?? [];
  final todayEnd = AppDateUtils.dateOnly(DateTime.now()).add(
    const Duration(days: 3),
  );
  return active
      .where((b) => !b.bill.nextDueDate.isAfter(todayEnd))
      .toList();
});
