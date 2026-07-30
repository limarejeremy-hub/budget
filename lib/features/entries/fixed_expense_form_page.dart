import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/providers/entries_providers.dart';
import '../../core/widgets/date_picker_field.dart';
import '../../core/widgets/euro_amount_field.dart';
import '../../core/widgets/form_actions_row.dart';
import '../../domain/entities/fixed_expense_entity.dart';

/// Formulaire de création / modification d'une charge fixe.
/// Le statut initial est déterminé automatiquement à partir de la date
/// prévue (cf. [ChargeStatusService]) — il n'y a pas de champ à saisir.
class FixedExpenseFormPage extends ConsumerStatefulWidget {
  final int cycleId;
  final FixedExpenseEntity? existing;

  const FixedExpenseFormPage({super.key, required this.cycleId, this.existing});

  @override
  ConsumerState<FixedExpenseFormPage> createState() => _FixedExpenseFormPageState();
}

class _FixedExpenseFormPageState extends ConsumerState<FixedExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _expectedAmountController;
  late final TextEditingController _actualAmountController;
  late DateTime _expectedDate;
  int? _categoryId;
  late bool _isRecurring;
  late bool _isActive;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _expectedAmountController = TextEditingController(
      text: existing == null ? '' : (existing.expectedAmountCents / 100).toStringAsFixed(2),
    );
    _actualAmountController = TextEditingController(
      text: existing?.actualAmountCents == null
          ? ''
          : (existing!.actualAmountCents! / 100).toStringAsFixed(2),
    );
    _expectedDate = existing?.expectedDate ?? DateTime.now();
    _categoryId = existing?.categoryId;
    _isRecurring = existing?.isRecurring ?? false;
    _isActive = existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _expectedAmountController.dispose();
    _actualAmountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final repository = ref.read(cycleRepositoryProvider);
    final expectedCents = EuroAmountField.parseCents(_expectedAmountController.text)!;
    final actualCents = EuroAmountField.parseCents(_actualAmountController.text);

    try {
      if (_isEditing) {
        await repository.updateFixedExpense(
          id: widget.existing!.id,
          name: _nameController.text.trim(),
          expectedAmountCents: expectedCents,
          actualAmountCents: actualCents,
          expectedDate: _expectedDate,
          categoryId: _categoryId,
          isRecurring: _isRecurring,
          isActive: _isActive,
        );
      } else {
        await repository.createFixedExpense(
          cycleId: widget.cycleId,
          name: _nameController.text.trim(),
          expectedAmountCents: expectedCents,
          actualAmountCents: actualCents,
          expectedDate: _expectedDate,
          categoryId: _categoryId,
          isRecurring: _isRecurring,
          isActive: _isActive,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesForTypeProvider(EntityType.fixedExpense));

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Modifier la charge fixe' : 'Nouvelle charge fixe')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 16),
              EuroAmountField(controller: _expectedAmountController, label: 'Montant prévu'),
              const SizedBox(height: 16),
              EuroAmountField(
                controller: _actualAmountController,
                label: 'Montant réel',
                required: false,
              ),
              const SizedBox(height: 16),
              DatePickerField(
                label: 'Date prévue',
                value: _expectedDate,
                onChanged: (d) => setState(() => _expectedDate = d),
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
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Charge récurrente'),
                value: _isRecurring,
                onChanged: (v) => setState(() => _isRecurring = v),
              ),
              SwitchListTile(
                title: const Text('Active'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
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
