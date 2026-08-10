import 'package:flutter/material.dart';

/// Choix proposé lors de la suppression d'une charge fixe liée à un crédit
/// (V0.9.1) — supprimer uniquement la mensualité affichée, ou le crédit
/// entier (et donc toutes ses charges, historique compris).
enum DeleteLinkedChargeChoice { chargeOnly, chargeAndCredit }

/// Affiche le choix "Supprimer uniquement la charge mensuelle" ou
/// "Supprimer aussi le crédit" pour une charge fixe liée à un crédit.
/// Renvoie `null` si l'utilisateur annule.
Future<DeleteLinkedChargeChoice?> showDeleteLinkedChargeDialog(
  BuildContext context, {
  required String chargeName,
}) {
  return showDialog<DeleteLinkedChargeChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Supprimer "$chargeName" ?'),
      content: const Text(
        'Cette charge est liée à un crédit. Veux-tu supprimer uniquement cette mensualité, ou le crédit entier (et toutes ses charges) ?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(DeleteLinkedChargeChoice.chargeOnly),
          child: const Text('Supprimer uniquement la charge mensuelle'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(DeleteLinkedChargeChoice.chargeAndCredit),
          style: FilledButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          child: const Text('Supprimer aussi le crédit'),
        ),
      ],
    ),
  );
}
