import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/dashboard_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/date_picker_field.dart';
import '../../core/widgets/euro_amount_field.dart';
import '../../core/widgets/form_actions_row.dart';
import '../../domain/entities/credit_entity.dart';

/// Formulaire de création / modification d'un crédit. Passer [existing]
/// pour éditer un crédit existant, sinon un nouveau crédit est créé.
class CreditFormPage extends ConsumerStatefulWidget {
  final CreditEntity? existing;
  const CreditFormPage({super.key, this.existing});

  @override
  ConsumerState<CreditFormPage> createState() => _CreditFormPageState();
}

class _CreditFormPageState extends ConsumerState<CreditFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _initialAmountController;
  late final TextEditingController _remainingCapitalController;
  late final TextEditingController _monthlyPaymentController;
  late final TextEditingController _rateController;
  late final TextEditingController _remainingInstallmentsController;
  late final TextEditingController _creditTypeController;
  late final TextEditingController _penaltyController;
  late final TextEditingController _notesController;
  late DateTime _startDate;
  late DateTime _expectedEndDate;
  late bool _earlyRepaymentAllowed;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _initialAmountController = TextEditingController(
      text: existing == null ? '' : (existing.initialAmountCents / 100).toStringAsFixed(2),
    );
    _remainingCapitalController = TextEditingController(
      text: existing == null ? '' : (existing.remainingCapitalCents / 100).toStringAsFixed(2),
    );
    _monthlyPaymentController = TextEditingController(
      text: existing == null ? '' : (existing.monthlyPaymentCents / 100).toStringAsFixed(2),
    );
    _rateController = TextEditingController(
      text: existing?.annualRatePercent == null ? '' : existing!.annualRatePercent!.toString(),
    );
    _remainingInstallmentsController =
        TextEditingController(text: existing == null ? '' : existing.remainingInstallments.toString());
    _creditTypeController = TextEditingController(text: existing?.creditType ?? '');
    _penaltyController = TextEditingController(
      text: existing?.earlyRepaymentPenaltyCents == null
          ? ''
          : (existing!.earlyRepaymentPenaltyCents! / 100).toStringAsFixed(2),
    );
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _startDate = existing?.startDate ?? DateTime.now();
    _expectedEndDate = existing?.expectedEndDate ?? DateTime.now().add(const Duration(days: 365));
    _earlyRepaymentAllowed = existing?.earlyRepaymentAllowed ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _initialAmountController.dispose();
    _remainingCapitalController.dispose();
    _monthlyPaymentController.dispose();
    _rateController.dispose();
    _remainingInstallmentsController.dispose();
    _creditTypeController.dispose();
    _penaltyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final repository = ref.read(cycleRepositoryProvider);
    final initialCents = EuroAmountField.parseCents(_initialAmountController.text)!;
    final remainingCents = EuroAmountField.parseCents(_remainingCapitalController.text)!;
    final monthlyCents = EuroAmountField.parseCents(_monthlyPaymentController.text)!;
    final penaltyCents = EuroAmountField.parseCents(_penaltyController.text);
    final rate = double.tryParse(_rateController.text.trim().replaceAll(',', '.'));
    final remainingInstallments = int.parse(_remainingInstallmentsController.text.trim());
    final creditType = _creditTypeController.text.trim().isEmpty ? null : _creditTypeController.text.trim();
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

    try {
      if (_isEditing) {
        await repository.updateCredit(
          id: widget.existing!.id,
          name: _nameController.text.trim(),
          initialAmountCents: initialCents,
          remainingCapitalCents: remainingCents,
          monthlyPaymentCents: monthlyCents,
          annualRatePercent: rate,
          startDate: _startDate,
          expectedEndDate: _expectedEndDate,
          remainingInstallments: remainingInstallments,
          creditType: creditType,
          earlyRepaymentAllowed: _earlyRepaymentAllowed,
          earlyRepaymentPenaltyCents: penaltyCents,
          notes: notes,
        );
      } else {
        await repository.createCredit(
          name: _nameController.text.trim(),
          initialAmountCents: initialCents,
          remainingCapitalCents: remainingCents,
          monthlyPaymentCents: monthlyCents,
          annualRatePercent: rate,
          startDate: _startDate,
          expectedEndDate: _expectedEndDate,
          remainingInstallments: remainingInstallments,
          creditType: creditType,
          earlyRepaymentAllowed: _earlyRepaymentAllowed,
          earlyRepaymentPenaltyCents: penaltyCents,
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
      appBar: AppBar(title: Text(_isEditing ? 'Modifier le crédit' : 'Nouveau crédit')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom (ex : Voiture, Prêt immobilier)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              EuroAmountField(controller: _initialAmountController, label: 'Montant initial emprunté'),
              const SizedBox(height: AppSpacing.lg),
              EuroAmountField(controller: _remainingCapitalController, label: 'Capital restant dû'),
              const SizedBox(height: AppSpacing.lg),
              EuroAmountField(controller: _monthlyPaymentController, label: 'Mensualité'),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _rateController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: const InputDecoration(labelText: 'Taux annuel % (facultatif)'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  return double.tryParse(v.trim().replaceAll(',', '.')) == null ? 'Taux invalide' : null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _remainingInstallmentsController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Mensualités restantes'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Champ requis';
                  return int.tryParse(v.trim()) == null ? 'Nombre invalide' : null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              DatePickerField(
                label: 'Date de début',
                value: _startDate,
                onChanged: (d) => setState(() => _startDate = d),
              ),
              const SizedBox(height: AppSpacing.lg),
              DatePickerField(
                label: 'Date de fin prévue',
                value: _expectedEndDate,
                firstDate: DateTime(_startDate.year - 5),
                onChanged: (d) => setState(() => _expectedEndDate = d),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _creditTypeController,
                decoration: const InputDecoration(labelText: 'Type de crédit (facultatif)'),
              ),
              const SizedBox(height: AppSpacing.lg),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Remboursement anticipé autorisé'),
                value: _earlyRepaymentAllowed,
                onChanged: (v) => setState(() => _earlyRepaymentAllowed = v),
              ),
              if (_earlyRepaymentAllowed) ...[
                const SizedBox(height: AppSpacing.sm),
                EuroAmountField(
                  controller: _penaltyController,
                  label: 'Pénalité de remboursement anticipé',
                  required: false,
                ),
              ],
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
