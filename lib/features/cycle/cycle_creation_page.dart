import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/dashboard_providers.dart';
import '../../core/widgets/date_picker_field.dart';
import '../../core/widgets/euro_amount_field.dart';
import '../../core/widgets/form_actions_row.dart';

/// Parcours de création du premier cycle (ou d'un nouveau cycle) : dates,
/// nom optionnel, solde bancaire facultatif.
class CycleCreationPage extends ConsumerStatefulWidget {
  const CycleCreationPage({super.key});

  @override
  ConsumerState<CycleCreationPage> createState() => _CycleCreationPageState();
}

class _CycleCreationPageState extends ConsumerState<CycleCreationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  late DateTime _startDate;
  late DateTime _endDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = _startDate.add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_endDate.isAfter(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La date de fin doit être après la date de début')),
      );
      return;
    }

    setState(() => _saving = true);
    final repository = ref.read(cycleRepositoryProvider);
    final name = _nameController.text.trim().isEmpty ? null : _nameController.text.trim();
    final balanceCents = EuroAmountField.parseCents(_balanceController.text);

    try {
      await repository.createCycle(
        startDate: _startDate,
        endDate: _endDate,
        name: name,
        declaredBankBalanceCents: balanceCents,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer mon cycle budgétaire')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Un cycle représente une période budgétaire (ex : du 27 du mois au 26 du '
                'mois suivant). Vous pourrez ensuite ajouter vos revenus, charges, '
                'dépenses et épargnes.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              DatePickerField(
                label: 'Date de début',
                value: _startDate,
                onChanged: (d) => setState(() => _startDate = d),
              ),
              const SizedBox(height: 16),
              DatePickerField(
                label: 'Date de fin',
                value: _endDate,
                onChanged: (d) => setState(() => _endDate = d),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du cycle (facultatif)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              EuroAmountField(
                controller: _balanceController,
                label: 'Solde bancaire déclaré',
                required: false,
              ),
              const SizedBox(height: 24),
              FormActionsRow(
                onCancel: () => Navigator.of(context).pop(),
                onSave: _saving ? () {} : _save,
                saveLabel: _saving ? 'Création…' : 'Créer le cycle',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
