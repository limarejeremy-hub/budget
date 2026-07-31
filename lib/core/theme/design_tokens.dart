import 'package:flutter/material.dart';

/// Rayons de bordure centralisés — évite les valeurs codées en dur dispersées
/// dans les widgets.
class AppRadii {
  AppRadii._();
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
}

/// Échelle d'espacement centralisée (base 4px).
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Couleurs des icônes rondes de catégorie dans le résumé du cycle.
class CategoryColors {
  CategoryColors._();
  static const Color income = Color(0xFF4C8DFF); // bleu — revenus
  static const Color fixedExpense = Color(0xFFF2A93B); // orange — charges
  static const Color variableExpense = Color(0xFF3FBE7A); // vert — dépenses
  static const Color saving = Color(0xFFA07CF2); // violet — épargne
  static const Color credit = Color(0xFFB08968); // cuivre — crédits (ni alarmiste, ni rouge vif)
}

/// Dégradé "or" premium de la carte Argent Libre, et couleurs d'accent
/// assorties (texte, couronne décorative) selon la luminosité du thème.
class GoldGradient {
  GoldGradient._();

  static const List<Color> dark = [Color(0xFF2B2313), Color(0xFF4A3A17), Color(0xFF6E501F)];
  static const List<Color> light = [Color(0xFFFBF2D9), Color(0xFFF2DDA9), Color(0xFFE7C476)];

  static const Color accentDark = Color(0xFFE9C978);
  static const Color accentLight = Color(0xFF8A6416);

  static List<Color> forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static Color accentForBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? accentDark : accentLight;
}

/// Ombres portées centralisées.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> card(Brightness brightness) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.35 : 0.08),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> subtle(Brightness brightness) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.25 : 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
}

/// Durées d'animation centralisées — cohérence des micro-interactions
/// (tap, transitions de page, changement de valeur) dans toute l'app.
class AppDurations {
  AppDurations._();
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 450);
  static const Duration pageTransition = Duration(milliseconds: 280);
}

/// Courbes d'animation centralisées.
class AppCurves {
  AppCurves._();
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutQuint;
}
