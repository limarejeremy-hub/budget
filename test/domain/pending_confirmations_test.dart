import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/domain/calculations/dashboard_view_builder.dart';
import 'package:budgetpilot/domain/calculations/pending_confirmations.dart';
import 'package:budgetpilot/domain/entities/fixed_expense_entity.dart';

void main() {
  const builder = DashboardViewBuilder();
  final today = DateTime(2026, 8, 15);

  test('regroupe les charges du jour et les alertes, sans doublon', () {
    final data = builder.build(
      cycleId: 1,
      cycleStart: DateTime(2026, 8, 1),
      cycleEnd: DateTime(2026, 8, 31),
      incomes: const [],
      fixedExpenses: [
        FixedExpenseEntity(
          id: 1,
          cycleId: 1,
          name: 'Orange',
          expectedAmountCents: 7000,
          expectedDate: today,
          status: ChargeStatus.aVerifierAujourdhui,
        ),
        FixedExpenseEntity(
          id: 2,
          cycleId: 1,
          name: 'Ancien impayé',
          expectedAmountCents: 5000,
          expectedDate: DateTime(2026, 8, 1),
          status: ChargeStatus.aConfirmer,
        ),
      ],
      variableExpenses: const [],
      savings: const [],
      now: today,
    );

    final pending = pendingConfirmations(data);
    expect(pending.map((e) => e.id), containsAll([1, 2]));
    expect(pending, hasLength(2));
  });

  test('exclut les charges déjà prélevées ou ignorées', () {
    final data = builder.build(
      cycleId: 1,
      cycleStart: DateTime(2026, 8, 1),
      cycleEnd: DateTime(2026, 8, 31),
      incomes: const [],
      fixedExpenses: [
        FixedExpenseEntity(
          id: 1,
          cycleId: 1,
          name: 'Confirmée',
          expectedAmountCents: 7000,
          expectedDate: today,
          status: ChargeStatus.prelevee,
        ),
        FixedExpenseEntity(
          id: 2,
          cycleId: 1,
          name: 'Ignorée',
          expectedAmountCents: 5000,
          expectedDate: today,
          status: ChargeStatus.suspendue,
        ),
      ],
      variableExpenses: const [],
      savings: const [],
      now: today,
    );

    expect(pendingConfirmations(data), isEmpty);
  });

  test('trie par date d\'échéance', () {
    final data = builder.build(
      cycleId: 1,
      cycleStart: DateTime(2026, 8, 1),
      cycleEnd: DateTime(2026, 8, 31),
      incomes: const [],
      fixedExpenses: [
        FixedExpenseEntity(
          id: 1,
          cycleId: 1,
          name: 'Plus tardive',
          expectedAmountCents: 7000,
          expectedDate: DateTime(2026, 8, 20),
          status: ChargeStatus.aConfirmer,
        ),
        FixedExpenseEntity(
          id: 2,
          cycleId: 1,
          name: 'Plus ancienne',
          expectedAmountCents: 5000,
          expectedDate: DateTime(2026, 8, 1),
          status: ChargeStatus.aConfirmer,
        ),
      ],
      variableExpenses: const [],
      savings: const [],
      now: today,
    );

    final pending = pendingConfirmations(data);
    expect(pending.map((e) => e.name), ['Plus ancienne', 'Plus tardive']);
  });
}
