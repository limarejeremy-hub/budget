import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/formatting/currency_formatter.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/euro_amount_field.dart';
import '../../../domain/calculations/credit_calculation_service.dart';
import '../../../domain/entities/credit_entity.dart';

const _presetAmountsCents = [50000, 100000, 250000]; // 500 € / 1 000 € / 2 500 €

/// Ouvre le simulateur "et si je versais X € ?" : compare l'impact d'un même
/// versement exceptionnel sur chacun des crédits actifs. Ne recommande
/// jamais une option précise — présente toujours les résultats côte à côte,
/// classés par impact estimé, en laissant l'utilisateur choisir.
Future<void> showCreditRepaymentSimulatorSheet(
  BuildContext context, {
  required List<CreditEntity> credits,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CreditRepaymentSimulatorSheet(credits: credits),
  );
}

class _CreditRepaymentSimulatorSheet extends StatefulWidget {
  final List<CreditEntity> credits;
  const _CreditRepaymentSimulatorSheet({required this.credits});

  @override
  State<_CreditRepaymentSimulatorSheet> createState() => _CreditRepaymentSimulatorSheetState();
}

class _CreditRepaymentSimulatorSheetState extends State<_CreditRepaymentSimulatorSheet> {
  final _customController = TextEditingController();
  int? _amountCents;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _selectPreset(int cents) {
    setState(() {
      _amountCents = cents;
      _customController.clear();
    });
  }

  void _onCustomChanged(String _) {
    setState(() => _amountCents = EuroAmountField.parseCents(_customController.text));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final options = (_amountCents == null || _amountCents! <= 0)
        ? const <CreditRepaymentOption>[]
        : simulateAcrossActiveCredits(credits: widget.credits, extraPaymentCents: _amountCents!);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xl + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Simuler un remboursement', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                "BudgetPilot compare l'impact de ce versement sur chacun de tes crédits actifs — à toi de choisir.",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final cents in _presetAmountsCents)
                    ChoiceChip(
                      label: Text(formatCentsAsEuro(cents)),
                      selected: _amountCents == cents,
                      onSelected: (_) => _selectPreset(cents),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _customController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: const InputDecoration(labelText: 'Ou montant personnalisé', suffixText: '€'),
                onChanged: _onCustomChanged,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_amountCents == null || _amountCents! <= 0)
                Text(
                  'Choisis ou saisis un montant pour voir les options.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                )
              else if (options.isEmpty)
                const Text('Aucun crédit actif à simuler.')
              else
                for (final (index, option) in options.indexed) ...[
                  _OptionCard(index: index, option: option),
                  const SizedBox(height: AppSpacing.sm),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final int index;
  final CreditRepaymentOption option;
  const _OptionCard({required this.index, required this.option});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Option ${index + 1} — ${option.wouldBeFullyRepaid ? 'Terminer' : 'Réduire'} ${option.credit.name}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (option.wouldBeFullyRepaid)
            _CheckLine('récupération de ${formatCentsAsEuro(option.monthlyPaymentFreedCents)}/mois'),
          if (option.monthsSaved > 0)
            _CheckLine('gain de ${option.monthsSaved} mensualité${option.monthsSaved > 1 ? 's' : ''}'),
          if (option.estimatedInterestSavedCents != null && option.estimatedInterestSavedCents! > 0)
            _CheckLine("économie d'intérêts estimée : ${formatCentsAsEuro(option.estimatedInterestSavedCents!)}"),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Estimation simplifiée, hors intérêts composés et pénalités.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  final String text;
  const _CheckLine(this.text);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, size: 14, color: CategoryColors.credit),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurface)),
          ),
        ],
      ),
    );
  }
}
