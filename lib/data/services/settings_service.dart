import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class AppSettings {
  const AppSettings({
    required this.currencyCode,
    required this.themeMode,
  });

  final String currencyCode;
  final ThemeMode themeMode;

  CurrencyPreset get currency => currencyPresetByCode(currencyCode);

  AppSettings copyWith({
    String? currencyCode,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      currencyCode: currencyCode ?? this.currencyCode,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._prefs)
      : super(
          AppSettings(
            currencyCode: _prefs.getString(_keyCurrency) ?? 'USD',
            themeMode: ThemeMode.values.firstWhere(
              (m) => m.name == (_prefs.getString(_keyTheme) ?? 'system'),
              orElse: () => ThemeMode.system,
            ),
          ),
        );

  static const _keyCurrency = 'currency_code';
  static const _keyTheme = 'theme_mode';

  final SharedPreferences _prefs;

  Future<void> setCurrencyCode(String code) async {
    await _prefs.setString(_keyCurrency, code);
    state = state.copyWith(currencyCode: code);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_keyTheme, mode.name);
    state = state.copyWith(themeMode: mode);
  }
}
