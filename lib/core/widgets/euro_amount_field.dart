import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Champ de saisie d'un montant en euros (virgule ou point accepté),
/// converti en centimes. [required] impose un montant strictement positif ;
/// sinon le champ peut rester vide (montant réel facultatif par exemple).
/// [allowNegative] autorise en plus zéro et les montants négatifs (ex : un
/// solde bancaire déclaré peut être à découvert) — `false` par défaut pour
/// tous les autres montants de l'application (revenus, charges, apports...),
/// qui n'ont jamais de sens négatif.
class EuroAmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  final bool allowNegative;
  final String? Function(String?)? extraValidator;

  const EuroAmountField({
    super.key,
    required this.controller,
    required this.label,
    this.required = true,
    this.allowNegative = false,
    this.extraValidator,
  });

  static int? parseCents(String input) {
    final normalized = input.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    final value = double.tryParse(normalized);
    if (value == null) return null;
    return (value * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: true, signed: allowNegative),
      inputFormatters: [
        FilteringTextInputFormatter.allow(allowNegative ? RegExp(r'[-0-9.,]') : RegExp(r'[0-9.,]')),
      ],
      decoration: InputDecoration(
        labelText: required ? label : '$label (facultatif)',
        suffixText: '€',
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) {
          if (required) return 'Montant requis';
          return extraValidator?.call(value);
        }
        final cents = parseCents(text);
        if (cents == null) return 'Montant invalide';
        if (!allowNegative && cents <= 0) return 'Le montant doit être supérieur à 0';
        return extraValidator?.call(value);
      },
    );
  }
}
