import 'package:flutter/material.dart';

/// Rangée "Annuler" / "Enregistrer" affichée en bas de chaque formulaire.
class FormActionsRow extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final String saveLabel;

  const FormActionsRow({
    super.key,
    required this.onCancel,
    required this.onSave,
    this.saveLabel = 'Enregistrer',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            child: const Text('Annuler'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: onSave,
            child: Text(saveLabel),
          ),
        ),
      ],
    );
  }
}
