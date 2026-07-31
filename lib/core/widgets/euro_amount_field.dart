import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Champ de saisie d'un montant en euros (virgule ou point accepté),
/// converti en centimes. [required] impose un montant strictement positif ;
/// sinon le champ peut rester vide (montant réel facultatif par exemple).
class EuroAmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  final String? Function(String?)? extraValidator;

  const EuroAmountField({
    super.key,
    required this.controller,
    required this.label,
    this.required = true,
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
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
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
        if (cents <= 0) return 'Le montant doit être supérieur à 0';
        return extraValidator?.call(value);
      },
    );
  }
}
