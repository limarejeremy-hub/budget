class VariableExpenseEntity {
  final int id;
  final int cycleId;
  final String? name;
  final int amountCents;
  final DateTime date;
  final int? categoryId;

  const VariableExpenseEntity({
    required this.id,
    required this.cycleId,
    this.name,
    required this.amountCents,
    required this.date,
    this.categoryId,
  });
}
