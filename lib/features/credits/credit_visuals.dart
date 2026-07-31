import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../domain/calculations/credit_calculation_service.dart';
import '../../domain/entities/credit_entity.dart';

/// Palette de couleurs proposées pour personnaliser un crédit — toujours en
/// harmonie avec le design system, jamais de rouge alarmiste. La première
/// valeur est la couleur crédit par défaut du thème.
const List<Color> creditColorPalette = [
  CategoryColors.credit,
  Color(0xFF4C8DFF),
  Color(0xFF3FBE7A),
  Color(0xFFA07CF2),
  Color(0xFFF2A93B),
  Color(0xFF3FA6BE),
];

/// Icônes proposées pour personnaliser un crédit. Référencées ici en `const`
/// pour rester compatibles avec le tree-shaking des icônes en build release
/// (seules les icônes réellement référencées comme `const IconData` dans le
/// code sont conservées dans la police embarquée).
const List<IconData> creditIconPalette = [
  Icons.account_balance_rounded,
  Icons.home_rounded,
  Icons.directions_car_rounded,
  Icons.smartphone_rounded,
  Icons.school_rounded,
  Icons.category_rounded,
];

/// Couleur effective d'un crédit : celle choisie par l'utilisateur, sinon la
/// couleur crédit par défaut du thème.
Color creditColorFor(CreditEntity credit) =>
    credit.colorValue == null ? CategoryColors.credit : Color(credit.colorValue!);

/// Icône effective d'un crédit : celle choisie par l'utilisateur (résolue
/// contre [creditIconPalette]), sinon l'icône par défaut.
IconData creditIconFor(CreditEntity credit) {
  if (credit.iconCodePoint == null) return Icons.account_balance_rounded;
  for (final icon in creditIconPalette) {
    if (icon.codePoint == credit.iconCodePoint) return icon;
  }
  return Icons.account_balance_rounded;
}

/// Émoji associé au score visuel ([CreditPace]) d'un crédit.
String creditPaceEmoji(CreditPace pace) {
  switch (pace) {
    case CreditPace.veryClose:
      return '🟢';
    case CreditPace.medium:
      return '🟡';
    case CreditPace.long:
      return '🟠';
    case CreditPace.veryLong:
      return '🔴';
  }
}

/// Couleur associée au score visuel ([CreditPace]) d'un crédit — en
/// harmonie avec le sens habituel des couleurs, sans jamais utiliser un
/// rouge criard alarmiste pour un simple crédit de longue durée.
Color creditPaceColor(CreditPace pace) {
  switch (pace) {
    case CreditPace.veryClose:
      return const Color(0xFF3FBE7A);
    case CreditPace.medium:
      return const Color(0xFFD9B036);
    case CreditPace.long:
      return const Color(0xFFF2A93B);
    case CreditPace.veryLong:
      return const Color(0xFFD97A5C);
  }
}
