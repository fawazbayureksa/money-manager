import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../categories/categories_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colors = context.appColors;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionLabel(title: 'Preferences'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.currency_exchange_rounded),
                  title: const Text('Currency'),
                  subtitle: Text(
                    '${settings.currency.name} (${settings.currency.symbol})',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickCurrency(context, ref, settings.currencyCode),
                ),
                Divider(height: 1, color: colors.cardBorder),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Appearance'),
                  subtitle: Text(_themeLabel(settings.themeMode)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickTheme(context, ref, settings.themeMode),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel(title: 'Data & Categories'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Manage Categories'),
                  subtitle: const Text('Add, edit, or archive categories'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CategoriesScreen(),
                      ),
                    );
                  },
                ),
                Divider(height: 1, color: colors.cardBorder),
                Builder(
                  builder: (tileContext) => ListTile(
                    leading: const Icon(Icons.upload_file_outlined),
                    title: const Text('Export Backup (JSON)'),
                    subtitle: const Text('Save all wallets, bills & transactions'),
                    onTap: () => _exportBackup(tileContext, ref),
                  ),
                ),
                Divider(height: 1, color: colors.cardBorder),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Restore Backup (JSON)'),
                  subtitle: const Text('Replace local data from a backup file'),
                  onTap: () => _restoreBackup(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '100% Offline • Data stays on your device',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.mutedText,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  Future<void> _pickCurrency(
    BuildContext context,
    WidgetRef ref,
    String currentCode,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return ListView.builder(
          shrinkWrap: true,
          itemCount: kCurrencyPresets.length,
          itemBuilder: (_, index) {
            final preset = kCurrencyPresets[index];
            final selected = preset.code == currentCode;
            return ListTile(
              leading: CircleAvatar(
                child: Text(
                  preset.symbol,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              title: Text('${preset.name} (${preset.code})'),
              subtitle: Text(
                preset.decimalDigits == 0 ? 'No decimals' : '2 decimals',
              ),
              trailing: selected
                  ? const Icon(Icons.check_circle_rounded)
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setCurrencyCode(preset.code);
                Navigator.pop(ctx);
              },
            );
          },
        );
      },
    );
  }

  Future<void> _pickTheme(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ThemeMode.values.map((mode) {
              return ListTile(
                title: Text(_themeLabel(mode)),
                trailing: mode == current
                    ? const Icon(Icons.check_circle_rounded)
                    : null,
                onTap: () {
                  ref.read(settingsProvider.notifier).setThemeMode(mode);
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final box = context.findRenderObject() as RenderBox?;
    final Rect shareOrigin;
    if (box != null && box.hasSize && !box.size.isEmpty) {
      shareOrigin = box.localToGlobal(Offset.zero) & box.size;
    } else {
      final screenSize = MediaQuery.sizeOf(context);
      shareOrigin = Rect.fromLTWH(
        0,
        0,
        screenSize.width > 0 ? screenSize.width : 1,
        screenSize.height > 0 ? screenSize.height / 2 : 1,
      );
    }

    try {
      final file = await ref.read(backupServiceProvider).exportToJsonFile();
      final xFile = XFile(file.path, mimeType: 'application/json');
      try {
        await Share.shareXFiles(
          [xFile],
          text: 'Money Manager Offline Backup',
          sharePositionOrigin: shareOrigin,
        );
      } on PlatformException {
        final bytes = await file.readAsBytes();
        final savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Backup (JSON)',
          fileName: file.uri.pathSegments.last,
          type: FileType.custom,
          allowedExtensions: ['json'],
          bytes: bytes,
        );
        if (savedPath != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup saved successfully')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
          'This will replace your current wallets, categories, recurring bills, and transactions with the backup file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final jsonStr = await File(result.files.single.path!).readAsString();
      await ref.read(backupServiceProvider).restoreFromJsonString(jsonStr);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.appColors.mutedText,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
