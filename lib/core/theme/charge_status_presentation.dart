import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'app_theme.dart';

/// Présentation visuelle (libellé, couleur, icône) d'un statut de charge
/// fixe — centralisée pour éviter de dupliquer le mapping dans chaque écran
/// qui affiche des charges (tableau de bord, liste des charges).
class ChargeStatusPresentation {
  final String label;
  final Color color;
  final IconData icon;

  const ChargeStatusPresentation({required this.label, required this.color, required this.icon});

  factory ChargeStatusPresentation.of(String status, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case ChargeStatus.aVenir:
        return ChargeStatusPresentation(
          label: 'À venir',
          color: colorScheme.onSurfaceVariant,
          icon: Icons.schedule_outlined,
        );
      case ChargeStatus.aVerifierAujourdhui:
        return const ChargeStatusPresentation(
          label: "Aujourd'hui",
          color: BudgetColors.warning,
          icon: Icons.today_outlined,
        );
      case ChargeStatus.aConfirmer:
        return const ChargeStatusPresentation(
          label: 'À confirmer',
          color: BudgetColors.danger,
          icon: Icons.error_outline,
        );
      case ChargeStatus.prelevee:
        return const ChargeStatusPresentation(
          label: 'Prélevée',
          color: BudgetColors.positive,
          icon: Icons.check_circle_outline,
        );
      case ChargeStatus.suspendue:
        return ChargeStatusPresentation(
          label: 'Suspendue',
          color: colorScheme.outline,
          icon: Icons.pause_circle_outline,
        );
      case ChargeStatus.incident:
        return const ChargeStatusPresentation(
          label: 'Incident',
          color: BudgetColors.danger,
          icon: Icons.warning_amber_outlined,
        );
      default:
        return ChargeStatusPresentation(
          label: status,
          color: colorScheme.onSurfaceVariant,
          icon: Icons.schedule_outlined,
        );
    }
  }
}
