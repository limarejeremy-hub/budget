import '../entities/fixed_expense_entity.dart';
import '../entities/income_entity.dart';
import '../entities/saving_entity.dart';

/// Modèle de vue prêt à afficher — construit par [DashboardViewBuilder].
class DashboardViewData {
  final int cycleId;
  final DateTime cycleStart;
  final DateTime cycleEnd;
  final int totalIncomeCents;
  final int totalFixedExpensesCents;
  final int totalVariableExpensesCents;
  final int totalSavingsCents;
  final int realRemainingCents;
  final double remainingRatio;
  final int unconfirmedChargesCount;
  final int unconfirmedChargesTotalCents;
  final FixedExpenseEntity? nextChargeToCheck;

  /// Les prochaines charges fixes non confirmées (au plus 3), triées par
  /// date prévue — même liste que [nextChargeToCheck] (son premier élément),
  /// simplement exposée en totalité pour l'affichage "Prochaines échéances".
  final List<FixedExpenseEntity> upcomingCharges;
  final int? declaredBankBalanceCents;

  /// Charges fixes dont la date prévue est aujourd'hui — section
  /// "Aujourd'hui" du tableau de bord.
  final List<FixedExpenseEntity> todayFixedExpenses;

  /// Revenus attendus aujourd'hui — section "Aujourd'hui".
  final List<IncomeEntity> todayIncomes;

  /// Charges nécessitant une attention immédiate (incident ou à confirmer /
  /// en retard), toutes dates confondues — alertes de la section
  /// "Aujourd'hui".
  final List<FixedExpenseEntity> alerts;

  /// Nombre de saisies actives par catégorie — affiché sous chaque carte du
  /// résumé du cycle (ex : "3 prélèvements"), jamais de pourcentage.
  final int incomesCount;
  final int fixedExpensesCount;
  final int variableExpensesCount;
  final int savingsCount;

  /// Opérations planifiées dans les 7 prochains jours (hors aujourd'hui,
  /// déjà couvert par [todayFixedExpenses]/[todayIncomes]) — section
  /// "Cette semaine".
  final List<FixedExpenseEntity> thisWeekFixedExpenses;
  final List<IncomeEntity> thisWeekIncomes;
  final List<SavingEntity> thisWeekSavings;

  const DashboardViewData({
    required this.cycleId,
    required this.cycleStart,
    required this.cycleEnd,
    required this.totalIncomeCents,
    required this.totalFixedExpensesCents,
    required this.totalVariableExpensesCents,
    required this.totalSavingsCents,
    required this.realRemainingCents,
    required this.remainingRatio,
    required this.unconfirmedChargesCount,
    required this.unconfirmedChargesTotalCents,
    this.nextChargeToCheck,
    this.upcomingCharges = const [],
    this.declaredBankBalanceCents,
    this.todayFixedExpenses = const [],
    this.todayIncomes = const [],
    this.alerts = const [],
    this.incomesCount = 0,
    this.fixedExpensesCount = 0,
    this.variableExpensesCount = 0,
    this.savingsCount = 0,
    this.thisWeekFixedExpenses = const [],
    this.thisWeekIncomes = const [],
    this.thisWeekSavings = const [],
  });

  /// Nombre de jours restants dans le cycle (inclut aujourd'hui, jamais
  /// négatif) — utilisé par la barre de progression du cycle.
  int daysRemaining({DateTime? now}) {
    final today = _dayOnly(now ?? DateTime.now());
    final end = _dayOnly(cycleEnd);
    if (!end.isAfter(today)) return 0;
    return end.difference(today).inDays;
  }

  /// Progression du cycle entre 0.0 (début) et 1.0 (fin ou au-delà).
  double cycleProgress({DateTime? now}) {
    final today = _dayOnly(now ?? DateTime.now());
    final start = _dayOnly(cycleStart);
    final end = _dayOnly(cycleEnd);
    final totalDays = end.difference(start).inDays;
    if (totalDays <= 0) return 1;
    final elapsed = today.difference(start).inDays;
    return (elapsed / totalDays).clamp(0.0, 1.0);
  }

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
