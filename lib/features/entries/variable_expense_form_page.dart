import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/providers/entries_providers.dart';
import '../../core/widgets/date_picker_field.dart';
import '../../core/widgets/euro_amount_field.dart';
import '../../core/widgets/form_actions_row.dart';
import '../../domain/entities/variable_expense_entity.dart';

/// Formulaire de création / modification d'une dépense variable.
class VariableExpenseFormPage extends ConsumerStatefulWidget {
  final int cycleId;
  final VariableExpenseEntity? existing;

  const VariableExpenseFormPage({super.key, required this.cycleId, this.existing});

  @override
  ConsumerState<VariableExpenseFormPage> createState() => _VariableExpenseFormPageState();
}

class _VariableExpenseFormPageState extends ConsumerState<VariableExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _nameController;
  late DateTime _date;
  int? _categoryId;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _amountController = TextEditingController(
      text: existing == null ? '' : (existing.amountCents / 100).toStringAsFixed(2),
    );
    _nameController = TextEditingController(text: existing?.name ?? '');
    _date = existing?.date ?? DateTime.now();
    _categoryId = existing?.categoryId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final repository = ref.read(cycleRepositoryProvider);
    final amountCents = EuroAmountField.parseCents(_amountController.text)!;
    final name = _nameController.text.trim().isEmpty ? null : _nameController.text.trim();

    try {
      if (_isEditing) {
        await repository.updateVariableExpense(
          id: widget.existing!.id,
          name: name,
          amountCents: amountCents,
          date: _date,
          categoryId: _categoryId,
        );
      } else {
        await repository.createVariableExpense(
          cycleId: widget.cycleId,
          name: name,
          amountCents: amountCents,
          date: _date,
          categoryId: _categoryId,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesForTypeProvider(EntityType.variableExpense));

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Modifier la dépense' : 'Nouvelle dépense')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              EuroAmountField(controller: _amountController, label: 'Montant'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom ou description (facultatif)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DatePickerField(
                label: 'Date',
                value: _date,
                onChanged: (d) => setState(() => _date = d),
              ),
              const SizedBox(height: 16),
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => const SizedBox.shrink(),
                data: (categories) => DropdownButtonFormField<int?>(
                  initialValue: _categoryId,
                  decoration:
                      const InputDecoration(labelText: 'Catégorie', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Aucune catégorie')),
                    for (final category in categories)
                      DropdownMenuItem<int?>(value: category.id, child: Text(category.name)),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
              ),
              const SizedBox(height: 24),
              FormActionsRow(
                onCancel: () => Navigator.of(context).pop(),
                onSave: _saving ? () {} : _save,
                saveLabel: _saving ? 'Enregistrement…' : 'Enregistrer',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
