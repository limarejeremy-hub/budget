import '../../../core/constants/app_constants.dart';
import '../../../domain/calculations/charge_status_service.dart';
import '../../../domain/entities/credit_entity.dart';
import '../../../domain/entities/fixed_expense_entity.dart';
import '../../../domain/entities/income_entity.dart';
import '../../../domain/entities/saving_entity.dart';
import '../../../domain/entities/variable_expense_entity.dart';
import '../database.dart';

const _chargeStatusService = ChargeStatusService();
const _manualChargeStatuses = {
  ChargeStatus.prelevee,
  ChargeStatus.suspendue,
  ChargeStatus.incident,
};

IncomeEntity incomeFromRow(Income row) => IncomeEntity(
      id: row.id,
      cycleId: row.cycleId,
      name: row.name,
      expectedAmountCents: row.expectedAmountCents,
      actualAmountCents: row.actualAmountCents,
      expectedDate: row.expectedDate,
      status: row.status,
      categoryId: row.categoryId,
      isRecurring: row.isRecurring,
      isActive: row.isActive,
    );

/// Le statut affiché est recalculé selon la date du jour via
/// [ChargeStatusService], sauf si la charge est déjà dans un état manuel
/// (prelevee / suspendue / incident) — ces états ne sont jamais écrasés.
FixedExpenseEntity fixedExpenseFromRow(FixedExpense row, {DateTime? now}) {
  final effectiveStatus = _manualChargeStatuses.contains(row.status)
      ? row.status
      : _chargeStatusService.computeStatus(
          expectedDate: row.expectedDate,
          isConfirmed: false,
          now: now,
        );

  return FixedExpenseEntity(
    id: row.id,
    cycleId: row.cycleId,
    name: row.name,
    expectedAmountCents: row.expectedAmountCents,
    actualAmountCents: row.actualAmountCents,
    expectedDate: row.expectedDate,
    status: effectiveStatus,
    categoryId: row.categoryId,
    isRecurring: row.isRecurring,
    isActive: row.isActive,
  );
}

VariableExpenseEntity variableExpenseFromRow(VariableExpense row) => VariableExpenseEntity(
      id: row.id,
      cycleId: row.cycleId,
      name: row.name,
      amountCents: row.amountCents,
      date: row.date,
      categoryId: row.categoryId,
    );

SavingEntity savingFromRow(Saving row) => SavingEntity(
      id: row.id,
      cycleId: row.cycleId,
      name: row.name,
      expectedAmountCents: row.expectedAmountCents,
      actualAmountCents: row.actualAmountCents,
      expectedDate: row.expectedDate,
      status: row.status,
      isRecurring: row.isRecurring,
      isActive: row.isActive,
    );

CreditEntity creditFromRow(Credit row) => CreditEntity(
      id: row.id,
      name: row.name,
      initialAmountCents: row.initialAmountCents,
      remainingCapitalCents: row.remainingCapitalCents,
      monthlyPaymentCents: row.monthlyPaymentCents,
      annualRatePercent: row.annualRatePercent,
      startDate: row.startDate,
      expectedEndDate: row.expectedEndDate,
      remainingInstallments: row.remainingInstallments,
      creditType: row.creditType,
      earlyRepaymentAllowed: row.earlyRepaymentAllowed,
      earlyRepaymentPenaltyCents: row.earlyRepaymentPenaltyCents,
      notes: row.notes,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      organisme: row.organisme,
      colorValue: row.colorValue,
      iconCodePoint: row.iconCodePoint,
    );
