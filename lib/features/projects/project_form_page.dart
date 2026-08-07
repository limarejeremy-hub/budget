import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/date_picker_field.dart';
import '../../core/widgets/euro_amount_field.dart';
import '../../core/widgets/form_actions_row.dart';
import '../../domain/entities/project_entity.dart';
import 'project_visuals.dart';

/// Formulaire de création / modification d'un projet (V1.0 — Project
/// Planner). Ne persiste que les informations saisies par l'utilisateur —
/// jamais un score ou une trajectoire, toujours recalculés à la volée.
class ProjectFormPage extends ConsumerStatefulWidget {
  final ProjectEntity? existing;
  const ProjectFormPage({super.key, this.existing});

  @override
  ConsumerState<ProjectFormPage> createState() => _ProjectFormPageState();
}

class _ProjectFormPageState extends ConsumerState<ProjectFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _targetAmountController;
  late final TextEditingController _availableContributionController;
  late final TextEditingController _desiredContributionController;
  late final TextEditingController _maxMonthlyPaymentController;
  late final TextEditingController _desiredDurationController;
  late final TextEditingController _rateController;
  late final TextEditingController _extraMonthlyCostController;
  late final TextEditingController _notesController;

  late String _category;
  late String _financingMode;
  late bool _hasDesiredDate;
  late DateTime _desiredDate;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _targetAmountController = TextEditingController(
      text: existing == null ? '' : (existing.targetAmountCents / 100).toStringAsFixed(2),
    );
    _availableContributionController = TextEditingController(
      text: (existing == null || existing.availableContributionCents <= 0)
          ? ''
          : (existing.availableContributionCents / 100).toStringAsFixed(2),
    );
    _desiredContributionController = TextEditingController(
      text: existing?.desiredContributionCents == null
          ? ''
          : (existing!.desiredContributionCents! / 100).toStringAsFixed(2),
    );
    _maxMonthlyPaymentController = TextEditingController(
      text:
          existing?.maxMonthlyPaymentCents == null ? '' : (existing!.maxMonthlyPaymentCents! / 100).toStringAsFixed(2),
    );
    _desiredDurationController = TextEditingController(text: existing?.desiredDurationMonths?.toString() ?? '');
    _rateController = TextEditingController(text: existing?.estimatedRatePercent?.toString() ?? '');
    _extraMonthlyCostController = TextEditingController(
      text: existing?.extraMonthlyCostCents == null ? '' : (existing!.extraMonthlyCostCents! / 100).toStringAsFixed(2),
    );
    _notesController = TextEditingController(text: existing?.notes ?? '');

    _category = existing?.category ?? ProjectCategory.other;
    _financingMode = existing?.financingMode ?? ProjectFinancingMode.undetermined;
    _hasDesiredDate = existing?.desiredDate != null;
    _desiredDate = existing?.desiredDate ?? DateTime.now().add(const Duration(days: 365));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _availableContributionController.dispose();
    _desiredContributionController.dispose();
    _maxMonthlyPaymentController.dispose();
    _desiredDurationController.dispose();
    _rateController.dispose();
    _extraMonthlyCostController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _showsFinancingFields => _financingMode != ProjectFinancingMode.cash;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final repository = ref.read(cycleRepositoryProvider);
    final targetAmount = EuroAmountField.parseCents(_targetAmountController.text)!;
    final availableContribution = EuroAmountField.parseCents(_availableContributionController.text) ?? 0;
    final desiredContribution = EuroAmountField.parseCents(_desiredContributionController.text);
    final maxMonthlyPayment = EuroAmountField.parseCents(_maxMonthlyPaymentController.text);
    final desiredDuration = int.tryParse(_desiredDurationController.text.trim());
    final rate = double.tryParse(_rateController.text.trim().replaceAll(',', '.'));
    final extraMonthlyCost = EuroAmountField.parseCents(_extraMonthlyCostController.text);
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
    final desiredDate = _hasDesiredDate ? _desiredDate : null;

    try {
      if (_isEditing) {
        await repository.updateProject(
          id: widget.existing!.id,
          name: _nameController.text.trim(),
          category: _category,
          targetAmountCents: targetAmount,
          desiredDate: desiredDate,
          availableContributionCents: availableContribution,
          desiredContributionCents: desiredContribution,
          financingMode: _financingMode,
          maxMonthlyPaymentCents: maxMonthlyPayment,
          desiredDurationMonths: desiredDuration,
          estimatedRatePercent: rate,
          extraMonthlyCostCents: extraMonthlyCost,
          notes: notes,
        );
      } else {
        await repository.createProject(
          name: _nameController.text.trim(),
          category: _category,
          targetAmountCents: targetAmount,
          desiredDate: desiredDate,
          availableContributionCents: availableContribution,
          desiredContributionCents: desiredContribution,
          financingMode: _financingMode,
          maxMonthlyPaymentCents: maxMonthlyPayment,
          desiredDurationMonths: desiredDuration,
          estimatedRatePercent: rate,
          extraMonthlyCostCents: extraMonthlyCost,
          notes: notes,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Modifier le projet' : 'Nouveau projet')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom du projet'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items: [
                  for (final category in ProjectCategory.all)
                    DropdownMenuItem(value: category, child: Text(projectCategoryLabel(category))),
                ],
                onChanged: (value) => setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: AppSpacing.lg),
              EuroAmountField(controller: _targetAmountController, label: 'Prix / budget cible'),
              const SizedBox(height: AppSpacing.lg),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date souhaitée'),
                value: _hasDesiredDate,
                onChanged: (v) => setState(() => _hasDesiredDate = v),
              ),
              if (_hasDesiredDate) ...[
                const SizedBox(height: AppSpacing.sm),
                DatePickerField(
                  label: 'Date souhaitée',
                  value: _desiredDate,
                  onChanged: (d) => setState(() => _desiredDate = d),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              EuroAmountField(
                controller: _availableContributionController,
                label: 'Apport disponible',
                required: false,
              ),
              const SizedBox(height: AppSpacing.lg),
              EuroAmountField(
                controller: _desiredContributionController,
                label: 'Apport souhaité',
                required: false,
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: _financingMode,
                decoration: const InputDecoration(labelText: 'Mode envisagé'),
                items: [
                  for (final mode in ProjectFinancingMode.all)
                    DropdownMenuItem(value: mode, child: Text(projectFinancingModeLabel(mode))),
                ],
                onChanged: (value) => setState(() => _financingMode = value ?? _financingMode),
              ),
              if (_showsFinancingFields) ...[
                const SizedBox(height: AppSpacing.lg),
                EuroAmountField(
                  controller: _maxMonthlyPaymentController,
                  label: 'Mensualité maximale souhaitée',
                  required: false,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _desiredDurationController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Durée de financement souhaitée (mois, facultatif)'),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _rateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(labelText: 'Taux annuel estimé % (facultatif)'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return double.tryParse(v.trim().replaceAll(',', '.')) == null ? 'Taux invalide' : null;
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              EuroAmountField(
                controller: _extraMonthlyCostController,
                label: 'Coûts mensuels supplémentaires',
                required: false,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes (facultatif)'),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.xxl),
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
