import 'package:flutter/material.dart';

/// Couleurs d'état utilisées partout dans l'app (reste réel, statuts de charges).
class BudgetColors {
  BudgetColors._();

  static const Color positive = Color(0xFF2E7D5B); // vert — confortable
  static const Color warning = Color(0xFFC9822C); // orange — à surveiller
  static const Color danger = Color(0xFFB3413E); // rouge — négatif / incident
}

class AppTheme {
  AppTheme._();

  static const Color _seed = Color(0xFF2E4A5E);

  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
    );
  }

  /// Renvoie la couleur d'état correspondant à un ratio (reste réel / revenus).
  /// vert > 20%, orange entre 5% et 20%, rouge < 5% ou négatif.
  static Color colorForRemainingRatio(double ratio) {
    if (ratio < 0.05) return BudgetColors.danger;
    if (ratio < 0.20) return BudgetColors.warning;
    return BudgetColors.positive;
  }
}
