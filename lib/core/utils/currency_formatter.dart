import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class CurrencyFormatter {
  const CurrencyFormatter._();

  static String format(
    int amountMinor,
    CurrencyPreset preset, {
    bool showPlus = false,
  }) {
    final isNegative = amountMinor < 0;
    final absMinor = amountMinor.abs();
    final divisor = preset.decimalDigits == 0 ? 1 : 100;
    final value = absMinor / divisor;

    final numberFormat = NumberFormat.currency(
      locale: preset.decimalDigits == 0 ? 'id_ID' : 'en_US',
      symbol: '',
      decimalDigits: preset.decimalDigits,
    );

    final formattedNumber = numberFormat.format(value).trim();
    final prefix = isNegative
        ? '-'
        : (showPlus && amountMinor > 0 ? '+' : '');
    final space = preset.symbol.length > 1 ? ' ' : '';
    return '$prefix${preset.symbol}$space$formattedNumber';
  }

  static int parseToMinor(String raw, CurrencyPreset preset) {
    final cleaned = raw.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return 0;
    final parsed = double.tryParse(cleaned) ?? 0;
    final multiplier = preset.decimalDigits == 0 ? 1 : 100;
    return (parsed * multiplier).round();
  }

  static String minorToInputString(int amountMinor, CurrencyPreset preset) {
    if (amountMinor == 0) return '';
    if (preset.decimalDigits == 0) {
      return amountMinor.toString();
    }
    final major = amountMinor / 100.0;
    if (amountMinor % 100 == 0) {
      return major.toInt().toString();
    }
    return major.toStringAsFixed(2);
  }
}
