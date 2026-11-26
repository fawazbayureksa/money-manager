import 'package:flutter/material.dart';

class CurrencyPreset {
  const CurrencyPreset({
    required this.code,
    required this.symbol,
    required this.name,
    required this.decimalDigits,
  });

  final String code;
  final String symbol;
  final String name;
  final int decimalDigits;
}

const List<CurrencyPreset> kCurrencyPresets = [
  CurrencyPreset(code: 'USD', symbol: '\$', name: 'US Dollar', decimalDigits: 2),
  CurrencyPreset(code: 'IDR', symbol: 'Rp', name: 'Indonesian Rupiah', decimalDigits: 0),
  CurrencyPreset(code: 'EUR', symbol: '€', name: 'Euro', decimalDigits: 2),
  CurrencyPreset(code: 'GBP', symbol: '£', name: 'British Pound', decimalDigits: 2),
  CurrencyPreset(code: 'JPY', symbol: '¥', name: 'Japanese Yen', decimalDigits: 0),
  CurrencyPreset(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar', decimalDigits: 2),
  CurrencyPreset(code: 'MYR', symbol: 'RM', name: 'Malaysian Ringgit', decimalDigits: 2),
  CurrencyPreset(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar', decimalDigits: 2),
];

CurrencyPreset currencyPresetByCode(String code) {
  return kCurrencyPresets.firstWhere(
    (c) => c.code == code,
    orElse: () => kCurrencyPresets.first,
  );
}

const List<Color> kSwatchColors = [
  Color(0xFF0D9488), // Teal
  Color(0xFF4F46E5), // Indigo
  Color(0xFFE11D48), // Rose
  Color(0xFFF97316), // Orange
  Color(0xFF2563EB), // Blue
  Color(0xFF9333EA), // Purple
  Color(0xFF16A34A), // Green
  Color(0xFFD97706), // Amber
  Color(0xFF0891B2), // Cyan
  Color(0xFF475569), // Slate
];

const List<IconData> kAppIcons = [
  // Wallets
  Icons.account_balance_wallet_rounded,
  Icons.account_balance_rounded,
  Icons.smartphone_rounded,
  Icons.savings_rounded,
  Icons.credit_card_rounded,
  // Expenses
  Icons.restaurant_rounded,
  Icons.coffee_rounded,
  Icons.directions_car_rounded,
  Icons.shopping_bag_rounded,
  Icons.receipt_long_rounded,
  Icons.medical_services_rounded,
  Icons.movie_rounded,
  Icons.home_rounded,
  Icons.flight_rounded,
  Icons.school_rounded,
  Icons.pets_rounded,
  Icons.fitness_center_rounded,
  Icons.bolt_rounded,
  Icons.wifi_rounded,
  // Income
  Icons.payments_rounded,
  Icons.work_rounded,
  Icons.card_giftcard_rounded,
  Icons.trending_up_rounded,
  Icons.redeem_rounded,
  Icons.more_horiz_rounded,
];

/// Resolves a stored [codePoint] to a compile-time constant [IconData]
/// so Flutter icon tree-shaking works safely in release builds.
IconData appIconFromCode(int codePoint) {
  for (final icon in kAppIcons) {
    if (icon.codePoint == codePoint) return icon;
  }
  return Icons.category_rounded;
}
