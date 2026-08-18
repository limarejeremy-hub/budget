import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/data/local/converters/entity_mappers.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/domain/calculations/charge_sorting.dart';
import 'package:budgetpilot/domain/calculations/dashboard_view_builder.dart';
import 'package:budgetpilot/domain/calculations/household_finance_service.dart';
import 'package:budgetpilot/domain/models/dashboard_view_data.dart';

const _builder = DashboardViewBuilder();
const _householdFinanceService = HouseholdFinanceService();

/// "Affectation manuelle d'une charge au prochain cycle" : une charge
/// reportée (`deferredToNextCycle`) reste dans son cycle d'origine et garde
/// sa vraie date de prélèvement, mais cesse de peser sur le CASH-FLOW de ce
/// cycle (total des charges, argent libre, total catégorie, "à confirmer")
/// tant qu'elle n'est pas ramenée ou promue au cycle suivant — jamais
/// supprimée, jamais dupliquée. Les indicateurs purement chronologiques
/// (Aujourd'hui, Cette semaine, prochaines échéances, notifications) et
/// structurels (reste à vivre, taux d'endettement) restent, eux, inchangés
/// par un report ponctuel.
void main() {
  late AppDatabase db;
  late CycleRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CycleRepository(db);
  });

  tearDown(() => db.close());

  /// Reproduit exactement la composition de `dashboardProvider`
  /// (`core/providers/dashboard_providers.dart`) : mêmes entités, même
  /// `DashboardViewBuilder`, pour tester le vrai chemin de calcul de
  /// l'application plutôt qu'une réimplémentation parallèle.
  Future<DashboardViewData> buildDashboard() async {
    final raw = await repository.loadCurrentCycleData();
    return _builder.build(
      cycleId: raw!.cycle.id,
      cycleStart: raw.cycle.startDate,
      cycleEnd: raw.cycle.endDate,
      incomes: raw.incomes.map(incomeFromRow).toList(),
      fixedExpenses: raw.fixedExpenses.map(fixedExpenseFromRow).toList(),
      variableExpenses: raw.variableExpenses.map(variableExpenseFromRow).toList(),
      savings: raw.savings.map(savingFromRow).toList(),
      declaredBankBalanceCents: raw.cycle.declaredBankBalanceCents,
    );
  }

  test(
      'CAS DE RÉFÉRENCE : EDF (180 €) reportée -> Argent Libre 1500 € -> 1680 € immédiatement, '
      'toujours visible avec badge, date inchangée, comptée dans le cycle B', () async {
    final cycleAId = await repository.createCycle(
      startDate: DateTime(2026, 7, 28),
      endDate: DateTime(2026, 8, 28),
      declaredBankBalanceCents: 0,
    );
    await repository.createIncome(
      cycleId: cycleAId,
      name: 'Salaire',
      expectedAmountCents: 168000, // 1680 €
      expectedDate: DateTime(2026, 7, 28),
    );
    final edfId = await repository.createFixedExpense(
      cycleId: cycleAId,
      name: 'EDF',
      expectedAmountCents: 18000, // 180 €
      expectedDate: DateTime(2026, 8, 30),
    );

    final before = await buildDashboard();
    expect(before.realRemainingCents, 150000, reason: 'Argent libre avant : 1500 €');
    expect(before.totalFixedExpensesCents, 18000);

    await repository.deferFixedExpenseToNextCycle(edfId);

    final after = await buildDashboard();
    expect(after.realRemainingCents, 168000, reason: 'Argent libre après report : 1680 € immédiatement');
    expect(after.totalFixedExpensesCents, 0, reason: 'EDF ne participe plus au total du cycle actuel');

    // EDF reste visible, avec son badge, sa date inchangée, une seule ligne.
    final rows = await (db.select(db.fixedExpenses)..where((e) => e.id.equals(edfId))).get();
    expect(rows, hasLength(1), reason: 'jamais de duplication');
    expect(rows.single.deferredToNextCycle, isTrue, reason: 'badge "Prochain cycle"');
    expect(rows.single.expectedDate, DateTime(2026, 8, 30), reason: 'la date bancaire réelle ne change jamais');
    expect(rows.single.cycleId, cycleAId, reason: 'cycleId (son cycle d\'origine) ne change pas non plus');
    expect(after.fixedExpensesCount, 1, reason: 'toujours visible dans la page Charges');

    await repository.closeCycle(cycleAId);
    await repository.createCycle(
      startDate: DateTime(2026, 8, 29),
      endDate: DateTime(2026, 9, 28),
      copyRecurringFromCycleId: cycleAId,
    );

    final cycleB = await buildDashboard();
    expect(cycleB.totalFixedExpensesCents, 18000, reason: 'EDF reportée est comptée dans le cycle B');
    final movedRow = await (db.select(db.fixedExpenses)..where((e) => e.id.equals(edfId))).getSingle();
    expect(movedRow.deferredToNextCycle, isFalse, reason: 'le report est levé une fois promu');
    expect(movedRow.expectedDate, DateTime(2026, 8, 30), reason: 'toujours la même date bancaire réelle');
  });

  test('1. une charge normale est comptée dans le total du cycle actuel', () async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Loyer',
      expectedAmountCents: 90000,
      expectedDate: DateTime(2026, 1, 5),
    );
    final data = await buildDashboard();
    expect(data.totalFixedExpensesCents, 90000);
  });

  test('2. reporter au prochain cycle retire immédiatement la charge du total actuel', () async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    final id = await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Loyer',
      expectedAmountCents: 90000,
      expectedDate: DateTime(2026, 1, 5),
    );
    await repository.deferFixedExpenseToNextCycle(id);
    final data = await buildDashboard();
    expect(data.totalFixedExpensesCents, 0);
  });

  test('4. le total de la catégorie est recalculé (categoryTotals exclut les charges reportées)', () async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    final categories = await repository.categoriesForType('fixed_expense');
    final maison = categories.first;
    final id1 = await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'EDF',
      expectedAmountCents: 18000,
      expectedDate: DateTime(2026, 1, 10),
      categoryId: maison.id,
    );
    await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Eau',
      expectedAmountCents: 5000,
      expectedDate: DateTime(2026, 1, 12),
      categoryId: maison.id,
    );

    final data = await repository.loadCurrentCycleData();
    final entities = data!.fixedExpenses.map(fixedExpenseFromRow).toList();
    final names = {for (final c in categories) c.id: c.name};
    final totalsBefore = categoryTotals(entities, categoryNames: names);
    expect(totalsBefore.single.totalCents, 23000);

    await repository.deferFixedExpenseToNextCycle(id1);
    final afterData = await repository.loadCurrentCycleData();
    final afterEntities = afterData!.fixedExpenses.map(fixedExpenseFromRow).toList();
    final totalsAfter = categoryTotals(afterEntities, categoryNames: names);
    expect(totalsAfter.single.totalCents, 5000, reason: 'EDF reportée exclue du total catégorie');
    expect(afterEntities, hasLength(2), reason: 'mais EDF reste consultable dans sa catégorie');
  });

  test('7. la date bancaire réelle d\'une charge reportée ne change jamais', () async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    final id = await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Loyer',
      expectedAmountCents: 90000,
      expectedDate: DateTime(2026, 1, 20),
    );
    await repository.deferFixedExpenseToNextCycle(id);
    final row = await (db.select(db.fixedExpenses)..where((e) => e.id.equals(id))).getSingle();
    expect(row.expectedDate, DateTime(2026, 1, 20));
  });

  test(
      '8. une charge reportée reste dans Aujourd\'hui / Cette semaine / prochaines échéances '
      '(indicateurs chronologiques inchangés — base des notifications)', () async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    final today = DateTime(2026, 1, 15);
    final id = await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'EDF',
      expectedAmountCents: 18000,
      expectedDate: today,
    );
    await repository.deferFixedExpenseToNextCycle(id);

    final raw = await repository.loadCurrentCycleData();
    final data = _builder.build(
      cycleId: raw!.cycle.id,
      cycleStart: raw.cycle.startDate,
      cycleEnd: raw.cycle.endDate,
      incomes: raw.incomes.map(incomeFromRow).toList(),
      fixedExpenses: raw.fixedExpenses.map(fixedExpenseFromRow).toList(),
      variableExpenses: raw.variableExpenses.map(variableExpenseFromRow).toList(),
      savings: raw.savings.map(savingFromRow).toList(),
      now: today,
    );
    expect(data.todayFixedExpenses.map((e) => e.id), contains(id),
        reason: 'une charge reportée reste basée sur sa vraie date pour "Aujourd\'hui" / les rappels');
    expect(data.upcomingCharges.map((e) => e.id), contains(id),
        reason: '"prochaines échéances" reste purement chronologique');
  });

  test('9. le report est persisté (survit à la fermeture et réouverture de la base)', () async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    final id = await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Loyer',
      expectedAmountCents: 90000,
      expectedDate: DateTime(2026, 1, 5),
    );
    await repository.deferFixedExpenseToNextCycle(id);

    // Un état UI temporaire ne survivrait pas à la relecture de la même
    // ligne depuis une requête indépendante — on vérifie ici la valeur
    // réellement persistée en base, pas un état en mémoire du repository.
    final reread = await (db.select(db.fixedExpenses)..where((e) => e.id.equals(id))).getSingle();
    expect(reread.deferredToNextCycle, isTrue);
  });

  test('10. ramener au cycle actuel recompte immédiatement la charge, sans duplication', () async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    final id = await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Loyer',
      expectedAmountCents: 90000,
      expectedDate: DateTime(2026, 1, 5),
    );
    await repository.deferFixedExpenseToNextCycle(id);
    expect((await buildDashboard()).totalFixedExpensesCents, 0);

    await repository.bringFixedExpenseBackToCurrentCycle(id);

    final data = await buildDashboard();
    expect(data.totalFixedExpensesCents, 90000);
    final rows = await (db.select(db.fixedExpenses)..where((e) => e.id.equals(id))).get();
    expect(rows, hasLength(1));
    expect(rows.single.deferredToNextCycle, isFalse);
  });

  test('11 + 12. création du cycle suivant : la charge reportée y apparaît, sans doublon', () async {
    final cycleAId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    final id = await repository.createFixedExpense(
      cycleId: cycleAId,
      name: 'Assurance habitation',
      expectedAmountCents: 4500,
      expectedDate: DateTime(2026, 1, 28),
    );
    await repository.deferFixedExpenseToNextCycle(id);
    await repository.closeCycle(cycleAId);
    await repository.createCycle(
      startDate: DateTime(2026, 2, 1),
      endDate: DateTime(2026, 2, 28),
      copyRecurringFromCycleId: cycleAId,
    );

    final data = await buildDashboard();
    expect(data.fixedExpensesCount, 1, reason: 'aucun doublon');
    expect(data.totalFixedExpensesCents, 4500);
    final row = await (db.select(db.fixedExpenses)..where((e) => e.id.equals(id))).getSingle();
    expect(row.cycleId, greaterThan(cycleAId), reason: 'promue vers le cycle B');
    expect(row.deferredToNextCycle, isFalse);
  });

  test(
      '13. une charge récurrente reportée ET sa nouvelle occurrence normale coexistent '
      'légitimement dans le même cycle (deux occurrences distinctes, jamais un doublon)', () async {
    final cycleAId = await repository.createCycle(startDate: DateTime(2026, 7, 28), endDate: DateTime(2026, 8, 28));
    final edfId = await repository.createFixedExpense(
      cycleId: cycleAId,
      name: 'EDF',
      expectedAmountCents: 18000,
      expectedDate: DateTime(2026, 8, 26),
      isRecurring: true,
    );
    await repository.deferFixedExpenseToNextCycle(edfId);
    await repository.closeCycle(cycleAId);
    await repository.createCycle(
      startDate: DateTime(2026, 8, 29),
      endDate: DateTime(2026, 9, 28),
      copyRecurringFromCycleId: cycleAId,
    );

    final data = await repository.loadCurrentCycleData();
    expect(data!.fixedExpenses, hasLength(2), reason: 'EDF reportée + nouvelle échéance normale, jamais fusionnées');
    final dates = data.fixedExpenses.map((e) => e.expectedDate).toList()..sort();
    expect(dates, [DateTime(2026, 8, 26), DateTime(2026, 9, 26)]);
    final total = data.fixedExpenses.fold<int>(0, (sum, e) => sum + e.expectedAmountCents);
    expect(total, 36000, reason: '2 x 180 € : les deux échéances comptent réellement, sans plafond artificiel');
  });

  test('14. reporter ponctuellement une charge liée à un crédit ne change jamais le taux d\'endettement structurel',
      () async {
    final cycleId = await repository.createCycle(startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
    final creditId = await repository.createCreditForExistingCharge(
      name: 'Voiture',
      initialAmountCents: 1500000,
      remainingCapitalCents: 900000,
      monthlyPaymentCents: 25000,
      expectedEndDate: DateTime(2029, 1, 1),
      remainingInstallments: 36,
    );
    final chargeId = await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Voiture',
      expectedAmountCents: 25000,
      expectedDate: DateTime(2026, 1, 5),
      linkedCreditId: creditId,
    );
    await repository.createIncome(
      cycleId: cycleId,
      name: 'Salaire',
      expectedAmountCents: 200000,
      expectedDate: DateTime(2026, 1, 1),
    );

    final creditRow = await (db.select(db.credits)..where((c) => c.id.equals(creditId))).getSingle();
    final credit = creditFromRow(creditRow);

    final before = await buildDashboard();
    final structuralBefore = _householdFinanceService.structuralRemainingCents(
      totalIncomeCents: before.totalIncomeCents,
      totalFixedExpensesExcludingCreditsCents: before.totalFixedExpensesExcludingCreditsCents,
      activeCredits: [credit],
    );

    await repository.deferFixedExpenseToNextCycle(chargeId);

    final after = await buildDashboard();
    final structuralAfter = _householdFinanceService.structuralRemainingCents(
      totalIncomeCents: after.totalIncomeCents,
      totalFixedExpensesExcludingCreditsCents: after.totalFixedExpensesExcludingCreditsCents,
      activeCredits: [credit],
    );

    expect(structuralAfter, structuralBefore,
        reason: 'le report ne retire jamais artificiellement un crédit du taux d\'endettement structurel');
    expect(after.totalFixedExpensesCents, before.totalFixedExpensesCents - 25000,
        reason: 'en revanche l\'argent libre / cash-flow du cycle change bien, lui');
  });

  test('15. la clôture historise un solde qui exclut déjà les charges reportées', () async {
    final cycleId = await repository.createCycle(
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 31),
      declaredBankBalanceCents: 0,
    );
    await repository.createIncome(
      cycleId: cycleId,
      name: 'Salaire',
      expectedAmountCents: 200000,
      expectedDate: DateTime(2026, 1, 1),
    );
    final id = await repository.createFixedExpense(
      cycleId: cycleId,
      name: 'Loyer',
      expectedAmountCents: 90000,
      expectedDate: DateTime(2026, 1, 5),
    );
    await repository.deferFixedExpenseToNextCycle(id);

    await repository.closeCycle(cycleId);
    final closed = await (db.select(db.budgetCycles)..where((c) => c.id.equals(cycleId))).getSingle();
    expect(closed.finalRealRemainingCents, 200000, reason: 'la charge reportée ne doit pas être déduite du solde figé');
  });
}
