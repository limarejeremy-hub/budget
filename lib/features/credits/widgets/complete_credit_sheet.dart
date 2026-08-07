import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/currency_formatter.dart';
import '../../../core/providers/dashboard_providers.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/date_picker_field.dart';
import '../../../core/widgets/euro_amount_field.dart';
import '../../../core/widgets/form_actions_row.dart';
import '../../../domain/calculations/credit_term_calculator.dart';

const _termCalculator = CreditTermCalculator();

/// Ouvre la BottomSheet "Compléter les informations du crédit" — déclenchée
/// quand une charge fixe est enregistrée avec la catégorie "Crédit" sans
/// qu'aucun crédit existant ne lui corresponde. Le nom, la mensualité et le
/// jour de prélèvement viennent déjà de la charge : seules les informations
/// manquantes (capital, taux, organisme, mensualités restantes) sont
/// demandées. Renvoie l'id du crédit créé, ou `null` si l'utilisateur
/// annule — dans ce cas la charge ne doit jamais être enregistrée dans la
/// catégorie "Crédit" sans lien.
Future<int?> showCompleteCreditSheet(
  BuildContext context, {
  required String chargeName,
  required int monthlyPaymentCents,
  required int paymentDayOfMonth,
}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CompleteCreditSheet(
      chargeName: chargeName,
      monthlyPaymentCents: monthlyPaymentCents,
      paymentDayOfMonth: paymentDayOfMonth,
    ),
  );
}

class CompleteCreditSheet extends ConsumerStatefulWidget {
  final String chargeName;
  final int monthlyPaymentCents;
  final int paymentDayOfMonth;

  const CompleteCreditSheet({
    super.key,
    required this.chargeName,
    required this.monthlyPaymentCents,
    required this.paymentDayOfMonth,
  });

  @override
  ConsumerState<CompleteCreditSheet> createState() => _CompleteCreditSheetState();
}

class _CompleteCreditSheetState extends ConsumerState<CompleteCreditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _organismeController;
  late final TextEditingController _initialAmountController;
  late final TextEditingController _remainingCapitalController;
  late final TextEditingController _rateController;
  late final TextEditingController _remainingInstallmentsController;
  bool _saving = false;

  /// La fin du crédit se renseigne au choix — date de fin OU mensualités
  /// restantes, jamais les deux à la fois. `false` par défaut : préserve le
  /// comportement historique du champ "Mensualités restantes".
  bool _useEndDate = false;
  DateTime _endDate = DateTime.now().add(const Duration(days: 365));

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.chargeName);
    _organismeController = TextEditingController();
    _initialAmountController = TextEditingController();
    _remainingCapitalController = TextEditingController();
    _rateController = TextEditingController();
    _remainingInstallmentsController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _organismeController.dispose();
    _initialAmountController.dispose();
    _remainingCapitalController.dispose();
    _rateController.dispose();
    _remainingInstallmentsController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    if (_useEndDate && !_endDate.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('La date de fin doit être dans le futur')));
      return;
    }
    setState(() => _saving = true);

    final repository = ref.read(cycleRepositoryProvider);
    final initialCents = EuroAmountField.parseCents(_initialAmountController.text)!;
    final remainingCents = EuroAmountField.parseCents(_remainingCapitalController.text)!;
    final rate = double.tryParse(_rateController.text.trim().replaceAll(',', '.'));
    final organisme = _organismeController.text.trim().isEmpty ? null : _organismeController.text.trim();
    final now = DateTime.now();

    final int remainingInstallments;
    final DateTime expectedEndDate;
    if (_useEndDate) {
      expectedEndDate = _endDate;
      remainingInstallments = _termCalculator.monthsUntil(now, _endDate);
    } else {
      remainingInstallments = int.parse(_remainingInstallmentsController.text.trim());
      expectedEndDate =
          _termCalculator.addMonths(DateTime(now.year, now.month, widget.paymentDayOfMonth), remainingInstallments);
    }

    try {
      final creditId = await repository.createCreditForExistingCharge(
        name: _nameController.text.trim(),
        initialAmountCents: initialCents,
        remainingCapitalCents: remainingCents,
        monthlyPaymentCents: widget.monthlyPaymentCents,
        annualRatePercent: rate,
        organisme: organisme,
        expectedEndDate: expectedEndDate,
        remainingInstallments: remainingInstallments,
        paymentDayOfMonth: widget.paymentDayOfMonth,
      );
      if (mounted) Navigator.of(context).pop(creditId);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Compléter les informations du crédit', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Cette charge est catégorisée "Crédit" — quelques informations suffisent pour créer son crédit associé.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _organismeController,
                decoration: const InputDecoration(labelText: 'Organisme (facultatif)'),
              ),
              const SizedBox(height: AppSpacing.lg),
              EuroAmountField(controller: _initialAmountController, label: 'Capital initial emprunté'),
              const SizedBox(height: AppSpacing.lg),
              EuroAmountField(controller: _remainingCapitalController, label: 'Capital restant dû'),
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
              Text('Fin du crédit', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Mensualités restantes'),
                      selected: !_useEndDate,
                      onSelected: (_) => setState(() => _useEndDate = false),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Date de fin prévue'),
                      selected: _useEndDate,
                      onSelected: (_) => setState(() => _useEndDate = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_useEndDate) ...[
                DatePickerField(
                  label: 'Date de fin prévue',
                  value: _endDate,
                  firstDate: DateTime.now(),
                  onChanged: (d) => setState(() => _endDate = d),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '≈ ${_termCalculator.monthsUntil(DateTime.now(), _endDate)} mensualité(s) restante(s)',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ] else ...[
                TextFormField(
                  controller: _remainingInstallmentsController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Mensualités restantes'),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Champ requis';
                    return int.tryParse(v.trim()) == null ? 'Nombre invalide' : null;
                  },
                ),
                if (int.tryParse(_remainingInstallmentsController.text.trim()) != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Fin estimée : ${formatMonthYearFr(_termCalculator.addMonths(DateTime(DateTime.now().year, DateTime.now().month, widget.paymentDayOfMonth), int.parse(_remainingInstallmentsController.text.trim())))}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
              const SizedBox(height: AppSpacing.xxl),
              FormActionsRow(
                onCancel: () => Navigator.of(context).pop(),
                onSave: _saving ? () {} : _create,
                saveLabel: _saving ? 'Création…' : 'Créer le crédit',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
