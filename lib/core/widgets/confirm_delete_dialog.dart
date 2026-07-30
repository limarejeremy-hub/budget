import 'package:flutter/material.dart';

/// Affiche une boîte de confirmation avant suppression. Renvoie `true` si
/// l'utilisateur confirme.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  String message = 'Cette action est définitive.',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
