import 'package:flutter/material.dart';

class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.canvas,
    required this.surfaceCard,
    required this.cardBorder,
    required this.mutedText,
    required this.income,
    required this.incomeSoft,
    required this.expense,
    required this.expenseSoft,
    required this.transfer,
    required this.transferSoft,
    required this.warning,
    required this.warningSoft,
    required this.dockBackground,
    required this.dockActive,
  });

  final Color canvas;
  final Color surfaceCard;
  final Color cardBorder;
  final Color mutedText;
  final Color income;
  final Color incomeSoft;
  final Color expense;
  final Color expenseSoft;
  final Color transfer;
  final Color transferSoft;
  final Color warning;
  final Color warningSoft;
  final Color dockBackground;
  final Color dockActive;

  static const light = AppSemanticColors(
    canvas: Color(0xFFF5F6F8),
    surfaceCard: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFEAECF0),
    mutedText: Color(0xFF64748B),
    income: Color(0xFF0D9488),
    incomeSoft: Color(0xFFE6F7F5),
    expense: Color(0xFFE11D48),
    expenseSoft: Color(0xFFFDECEE),
    transfer: Color(0xFF4F46E5),
    transferSoft: Color(0xFFEEF2FF),
    warning: Color(0xFFD97706),
    warningSoft: Color(0xFFFEF3C7),
    dockBackground: Color(0xFFFFFFFF),
    dockActive: Color(0xFF141B29),
  );

  static const dark = AppSemanticColors(
    canvas: Color(0xFF0F141E),
    surfaceCard: Color(0xFF18202F),
    cardBorder: Color(0xFF273247),
    mutedText: Color(0xFF94A3B8),
    income: Color(0xFF2DD4BF),
    incomeSoft: Color(0xFF132E2D),
    expense: Color(0xFFFB7185),
    expenseSoft: Color(0xFF331B24),
    transfer: Color(0xFF818CF8),
    transferSoft: Color(0xFF1F2242),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF332814),
    dockBackground: Color(0xFF18202F),
    dockActive: Color(0xFFF8FAFC),
  );

  @override
  ThemeExtension<AppSemanticColors> copyWith({
    Color? canvas,
    Color? surfaceCard,
    Color? cardBorder,
    Color? mutedText,
    Color? income,
    Color? incomeSoft,
    Color? expense,
    Color? expenseSoft,
    Color? transfer,
    Color? transferSoft,
    Color? warning,
    Color? warningSoft,
    Color? dockBackground,
    Color? dockActive,
  }) {
    return AppSemanticColors(
      canvas: canvas ?? this.canvas,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      cardBorder: cardBorder ?? this.cardBorder,
      mutedText: mutedText ?? this.mutedText,
      income: income ?? this.income,
      incomeSoft: incomeSoft ?? this.incomeSoft,
      expense: expense ?? this.expense,
      expenseSoft: expenseSoft ?? this.expenseSoft,
      transfer: transfer ?? this.transfer,
      transferSoft: transferSoft ?? this.transferSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      dockBackground: dockBackground ?? this.dockBackground,
      dockActive: dockActive ?? this.dockActive,
    );
  }

  @override
  ThemeExtension<AppSemanticColors> lerp(
    covariant ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      income: Color.lerp(income, other.income, t)!,
      incomeSoft: Color.lerp(incomeSoft, other.incomeSoft, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      expenseSoft: Color.lerp(expenseSoft, other.expenseSoft, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      transferSoft: Color.lerp(transferSoft, other.transferSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      dockBackground: Color.lerp(dockBackground, other.dockBackground, t)!,
      dockActive: Color.lerp(dockActive, other.dockActive, t)!,
    );
  }
}

extension AppThemeX on BuildContext {
  AppSemanticColors get appColors =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    const primary = Color(0xFF141B29);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppSemanticColors.light.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        surface: AppSemanticColors.light.surfaceCard,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: primary,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppSemanticColors.light.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppSemanticColors.light.cardBorder),
        ),
      ),
      extensions: const [AppSemanticColors.light],
    );
  }

  static ThemeData dark() {
    const primary = Color(0xFFF8FAFC);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppSemanticColors.dark.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2DD4BF),
        primary: primary,
        surface: AppSemanticColors.dark.surfaceCard,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: primary,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppSemanticColors.dark.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppSemanticColors.dark.cardBorder),
        ),
      ),
      extensions: const [AppSemanticColors.dark],
    );
  }
}
