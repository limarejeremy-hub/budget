import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/widgets/date_picker_field.dart';
import '../../core/widgets/euro_amount_field.dart';
import '../../core/widgets/form_actions_row.dart';
import '../../data/local/cycle_repository.dart';
import '../../data/local/database.dart';
import '../../domain/calculations/cycle_close_service.dart';

const _cycleCloseService = CycleCloseService();

/// Construit la page de création du prochain cycle à partir de l'historique
/// des cycles : préemplie (dates sans chevauchement, solde suggéré) à partir
/// du dernier cycle clôturé s'il y en a un, sinon un cycle vierge. Point
/// d'entrée unique réutilisé partout où l'utilisateur peut se retrouver
/// sans cycle actif (accueil, Paramètres > Cycle) — garantit qu'il n'est
/// jamais bloqué, y compris après une clôture interrompue avant la
/// validation du cycle suivant (§ correctif "démarrage du cycle suivant").
CycleCreationPage nextCycleCreationPage(List<BudgetCycle> cycles) {
  final closedCycles = cycles.where((c) => c.status == CycleStatus.ferme);
  final lastClosed = closedCycles.isEmpty ? null : closedCycles.first; // déjà trié du plus récent au plus ancien
  if (lastClosed == null) return const CycleCreationPage();

  final start = _cycleCloseService.nextCycleStartDate(lastClosed.endDate);
  final end = _cycleCloseService.nextCycleEndDate(
    previousStartDate: lastClosed.startDate,
    previousEndDate: lastClosed.endDate,
    newStartDate: start,
  );
  return CycleCreationPage(
    initialStartDate: start,
    initialEndDate: end,
    suggestedBalanceCents: lastClosed.finalRealRemainingCents,
    previousCycleId: lastClosed.id,
  );
}

/// Parcours de création du premier cycle, ou du cycle suivant après clôture
/// (finalisation du moteur de cycle) : dates, nom optionnel, solde bancaire
/// facultatif. Quand [initialStartDate]/[initialEndDate] sont fournies
/// (venant du cycle qui vient d'être clôturé), les champs sont préremplis
/// mais restent librement modifiables avant validation. [previousCycleId],
/// quand fourni, déclenche la recopie des revenus/charges/épargnes
/// récurrents de ce cycle précédent dans le nouveau.
class CycleCreationPage extends ConsumerStatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final int? suggestedBalanceCents;
  final int? previousCycleId;

  const CycleCreationPage({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    this.suggestedBalanceCents,
    this.previousCycleId,
  });

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
    if (widget.initialStartDate != null && widget.initialEndDate != null) {
      _startDate = widget.initialStartDate!;
      _endDate = widget.initialEndDate!;
    } else {
      final now = DateTime.now();
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = _startDate.add(const Duration(days: 30));
    }
    // Suggestion éditable uniquement — jamais recopiée sans que
    // l'utilisateur valide explicitement le formulaire (§12).
    final suggested = widget.suggestedBalanceCents;
    if (suggested != null) {
      _balanceController.text = (suggested / 100).toStringAsFixed(2);
    }
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
        copyRecurringFromCycleId: widget.previousCycleId,
      );
      if (mounted) Navigator.of(context).pop();
    } on CycleAlreadyOpenException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
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
                widget.previousCycleId == null
                    ? 'Un cycle représente une période budgétaire (ex : du 27 du mois au 26 du '
                        'mois suivant). Vous pourrez ensuite ajouter vos revenus, charges, '
                        'dépenses et épargnes.'
                    : 'Vos revenus, charges fixes et épargnes récurrents actifs sont repris '
                        'automatiquement — les dépenses variables repartent toujours à 0 €.',
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
                ),
              ),
              const SizedBox(height: 16),
              EuroAmountField(
                controller: _balanceController,
                label: 'Solde bancaire déclaré',
                required: false,
                allowNegative: true,
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
