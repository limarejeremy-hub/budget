import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Champ "date" en lecture seule qui ouvre un [showDatePicker] au tap.
class DatePickerField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const DatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat('d MMMM yyyy', 'fr_FR').format(value);

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: firstDate ?? DateTime(value.year - 5),
          lastDate: lastDate ?? DateTime(value.year + 5),
          locale: const Locale('fr', 'FR'),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(formatted),
      ),
    );
  }
}
