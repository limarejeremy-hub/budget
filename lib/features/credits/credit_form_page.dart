import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/dashboard_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/date_picker_field.dart';
import '../../core/widgets/euro_amount_field.dart';
import '../../core/widgets/form_actions_row.dart';
import '../../domain/entities/credit_entity.dart';
import 'credit_visuals.dart';

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
  late final TextEditingController _organismeController;
  late final TextEditingController _initialAmountController;
  late final TextEditingController _remainingCapitalController;
  late final TextEditingController _monthlyPaymentController;
  late final TextEditingController _rateController;
  late final TextEditingController _remainingInstallmentsController;
  late final TextEditingController _creditTypeController;
  late final TextEditingController _penaltyController;
  late final TextEditingController _paymentDayController;
  late final TextEditingController _insuranceController;
  late final TextEditingController _notesController;
  late DateTime _startDate;
  late DateTime _expectedEndDate;
  late bool _earlyRepaymentAllowed;
  late Color? _selectedColor;
  late IconData? _selectedIcon;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _organismeController = TextEditingController(text: existing?.organisme ?? '');
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
    _paymentDayController =
        TextEditingController(text: existing?.paymentDayOfMonth == null ? '' : existing!.paymentDayOfMonth.toString());
    _insuranceController = TextEditingController(
      text: existing?.insuranceCents == null ? '' : (existing!.insuranceCents! / 100).toStringAsFixed(2),
    );
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _startDate = existing?.startDate ?? DateTime.now();
    _expectedEndDate = existing?.expectedEndDate ?? DateTime.now().add(const Duration(days: 365));
    _earlyRepaymentAllowed = existing?.earlyRepaymentAllowed ?? true;
    _selectedColor = existing?.colorValue == null ? null : Color(existing!.colorValue!);
    _selectedIcon = existing?.iconCodePoint == null
        ? null
        : creditIconPalette.firstWhere(
            (icon) => icon.codePoint == existing!.iconCodePoint,
            orElse: () => creditIconPalette.first,
          );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _organismeController.dispose();
    _initialAmountController.dispose();
    _remainingCapitalController.dispose();
    _monthlyPaymentController.dispose();
    _rateController.dispose();
    _remainingInstallmentsController.dispose();
    _creditTypeController.dispose();
    _penaltyController.dispose();
    _paymentDayController.dispose();
    _insuranceController.dispose();
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
    final insuranceCents = EuroAmountField.parseCents(_insuranceController.text);
    final paymentDayOfMonth = int.tryParse(_paymentDayController.text.trim());
    final rate = double.tryParse(_rateController.text.trim().replaceAll(',', '.'));
    final remainingInstallments = int.parse(_remainingInstallmentsController.text.trim());
    final creditType = _creditTypeController.text.trim().isEmpty ? null : _creditTypeController.text.trim();
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
    final organisme = _organismeController.text.trim().isEmpty ? null : _organismeController.text.trim();
    final colorValue = _selectedColor?.toARGB32();
    final iconCodePoint = _selectedIcon?.codePoint;

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
          organisme: organisme,
          colorValue: colorValue,
          iconCodePoint: iconCodePoint,
          paymentDayOfMonth: paymentDayOfMonth,
          insuranceCents: insuranceCents,
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
          organisme: organisme,
          colorValue: colorValue,
          iconCodePoint: iconCodePoint,
          paymentDayOfMonth: paymentDayOfMonth,
          insuranceCents: insuranceCents,
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
              TextFormField(
                controller: _organismeController,
                decoration: const InputDecoration(labelText: 'Organisme (facultatif)'),
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
              TextFormField(
                controller: _paymentDayController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Jour de prélèvement (facultatif)'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final day = int.tryParse(v.trim());
                  return (day == null || day < 1 || day > 31) ? 'Jour invalide (1-31)' : null;
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
              EuroAmountField(
                controller: _insuranceController,
                label: 'Assurance mensuelle',
                required: false,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Couleur (facultatif)', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  for (final color in creditColorPalette) ...[
                    _ColorSwatch(
                      key: ValueKey('credit_color_${color.toARGB32()}'),
                      color: color,
                      selected: (_selectedColor ?? creditColorPalette.first) == color,
                      onTap: () => setState(() => _selectedColor = color),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Icône (facultatif)', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  for (final icon in creditIconPalette) ...[
                    _IconOption(
                      key: ValueKey('credit_icon_${icon.codePoint}'),
                      icon: icon,
                      selected: (_selectedIcon ?? creditIconPalette.first) == icon,
                      onTap: () => setState(() => _selectedIcon = icon),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ],
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

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ColorSwatch({super.key, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2) : null,
        ),
        child: selected ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
      ),
    );
  }
}

class _IconOption extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _IconOption({super.key, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: selected ? CategoryColors.credit.withValues(alpha: 0.2) : colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: CategoryColors.credit, width: 2) : null,
        ),
        child: Icon(icon, size: 18, color: selected ? CategoryColors.credit : colorScheme.onSurfaceVariant),
      ),
    );
  }
}
