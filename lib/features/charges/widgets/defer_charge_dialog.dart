import 'package:flutter/material.dart';

/// Confirmation avant "Reporter au prochain cycle" (§1) — le seul geste qui
/// exige une confirmation explicite ; l'action inverse ("Ramener au cycle
/// actuel") s'applique immédiatement, sans dialogue, comme demandé.
Future<bool> confirmDeferToNextCycle(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Reporter au prochain cycle'),
      content: const Text(
        'Cette échéance ne sera plus comptée dans le budget du cycle actuel. '
        'Elle sera automatiquement affectée au prochain cycle.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Reporter'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
