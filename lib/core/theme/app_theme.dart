import 'package:flutter/material.dart';

import 'design_tokens.dart';

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
        // Fond légèrement différencié du fond général pour bien détacher la
        // barre de navigation, tout en restant sombre.
        backgroundColor: colorScheme.surfaceContainerHigh,
        indicatorColor: colorScheme.secondaryContainer,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
      // Design system unifié : mêmes rayons, mêmes espacements sur tous les
      // champs, boutons, dialogues, BottomSheets et chips de l'app — pour
      // une finition homogène plutôt qu'un style par écran.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppRadii.xl),
            topRight: Radius.circular(AppRadii.xl),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
        side: BorderSide.none,
        backgroundColor: colorScheme.surfaceContainerHigh,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }

  /// Renvoie la couleur d'état correspondant à un ratio (reste réel / revenus).
  /// vert > 20%, orange entre 5% et 20%, rouge < 5% ou négatif.
  static Color colorForRemainingRatio(double ratio) {
    if (ratio < 0.05) return BudgetColors.danger;
    if (ratio < 0.20) return BudgetColors.warning;
    return BudgetColors.positive;
  }

  /// Libellé du badge de situation affiché sur la carte Argent Libre —
  /// mêmes seuils que [colorForRemainingRatio].
  static String statusLabelForRemainingRatio(double ratio) {
    if (ratio < 0.05) return 'Budget serré';
    if (ratio < 0.20) return 'À surveiller';
    return 'Situation confortable';
  }

  /// Icône du badge de situation — mêmes seuils que [colorForRemainingRatio].
  static IconData statusIconForRemainingRatio(double ratio) {
    if (ratio < 0.05) return Icons.error_rounded;
    if (ratio < 0.20) return Icons.warning_rounded;
    return Icons.check_circle_rounded;
  }
}
