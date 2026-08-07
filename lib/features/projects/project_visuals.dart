import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/calculations/project_feasibility_service.dart';
import '../../domain/calculations/project_safety_service.dart';

/// Couleur associée à un [FeasibilityLevel] — rouge réservé au seul cas
/// réellement problématique (<40), jamais utilisé pour une simple prudence.
Color feasibilityLevelColor(FeasibilityLevel level) {
  switch (level) {
    case FeasibilityLevel.veryDifficult:
      return const Color(0xFFD9524A);
    case FeasibilityLevel.fragile:
      return const Color(0xFFF2A93B);
    case FeasibilityLevel.feasible:
      return const Color(0xFFD9B036);
    case FeasibilityLevel.comfortable:
      return const Color(0xFF3FBE7A);
    case FeasibilityLevel.veryComfortable:
      return const Color(0xFF2FA968);
  }
}

/// Couleur associée à un [FinancialSafetyLevel] (V1.1) — vert = sain, jaune
/// = acceptable, orange = tendu, rouge réservé au risque réellement élevé.
Color financialSafetyLevelColor(FinancialSafetyLevel level) {
  switch (level) {
    case FinancialSafetyLevel.critical:
      return const Color(0xFFD9524A);
    case FinancialSafetyLevel.tense:
      return const Color(0xFFF2A93B);
    case FinancialSafetyLevel.acceptable:
      return const Color(0xFFD9B036);
    case FinancialSafetyLevel.healthy:
      return const Color(0xFF3FBE7A);
  }
}

/// Couleur associée à un [DebtRatioBand] (V1.1) — mêmes codes couleur que
/// [financialSafetyLevelColor], jamais présentée comme une décision
/// bancaire (voir doc `project_safety_service.dart`).
Color debtRatioBandColor(DebtRatioBand band) {
  switch (band) {
    case DebtRatioBand.high:
      return const Color(0xFFD9524A);
    case DebtRatioBand.tense:
      return const Color(0xFFF2A93B);
    case DebtRatioBand.watch:
      return const Color(0xFFD9B036);
    case DebtRatioBand.comfortable:
      return const Color(0xFF3FBE7A);
  }
}

/// Icône représentative d'une catégorie de projet.
IconData projectCategoryIcon(String category) {
  switch (category) {
    case ProjectCategory.car:
      return Icons.directions_car_rounded;
    case ProjectCategory.renovation:
      return Icons.construction_rounded;
    case ProjectCategory.realEstate:
      return Icons.home_work_rounded;
    case ProjectCategory.travel:
      return Icons.flight_takeoff_rounded;
    case ProjectCategory.wedding:
      return Icons.favorite_rounded;
    case ProjectCategory.bigPurchase:
      return Icons.shopping_bag_rounded;
    case ProjectCategory.other:
    default:
      return Icons.flag_rounded;
  }
}

/// Emoji représentatif d'une catégorie de projet — utilisé dans les listes
/// compactes (§13).
String projectCategoryEmoji(String category) {
  switch (category) {
    case ProjectCategory.car:
      return '🚗';
    case ProjectCategory.renovation:
      return '🛠️';
    case ProjectCategory.realEstate:
      return '🏠';
    case ProjectCategory.travel:
      return '✈️';
    case ProjectCategory.wedding:
      return '💍';
    case ProjectCategory.bigPurchase:
      return '🛍️';
    case ProjectCategory.other:
    default:
      return '🎯';
  }
}

/// Libellé lisible d'une catégorie de projet.
String projectCategoryLabel(String category) {
  switch (category) {
    case ProjectCategory.car:
      return 'Voiture';
    case ProjectCategory.renovation:
      return 'Travaux';
    case ProjectCategory.realEstate:
      return 'Immobilier';
    case ProjectCategory.travel:
      return 'Voyage';
    case ProjectCategory.wedding:
      return 'Mariage';
    case ProjectCategory.bigPurchase:
      return 'Gros achat';
    case ProjectCategory.other:
    default:
      return 'Autre';
  }
}

/// Libellé lisible d'une priorité de projet (V1.1).
String projectPriorityLabel(String priority) {
  switch (priority) {
    case ProjectPriority.high:
      return 'Haute';
    case ProjectPriority.low:
      return 'Basse';
    case ProjectPriority.medium:
    default:
      return 'Moyenne';
  }
}

/// Libellé lisible d'un mode de financement.
String projectFinancingModeLabel(String mode) {
  switch (mode) {
    case ProjectFinancingMode.cash:
      return 'Comptant';
    case ProjectFinancingMode.financed:
      return 'Financement';
    case ProjectFinancingMode.mixed:
      return 'Mixte';
    case ProjectFinancingMode.undetermined:
    default:
      return 'Indéterminé';
  }
}
