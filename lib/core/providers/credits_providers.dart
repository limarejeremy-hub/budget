import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/converters/entity_mappers.dart';
import '../../data/local/database.dart';
import '../../domain/entities/credit_entity.dart';
import 'dashboard_providers.dart';

/// Tous les crédits (actifs et terminés) — indépendants du cycle courant.
final creditsProvider = StreamProvider.autoDispose<List<CreditEntity>>((ref) {
  final repository = ref.watch(cycleRepositoryProvider);
  return repository.watchCredits().map((rows) => rows.map(creditFromRow).toList());
});

/// Charges fixes de catégorie "Crédit" sans crédit lié (cas hérité ou
/// incohérence à corriger) — section "Crédits à compléter" de la page
/// Crédits.
final unlinkedCreditChargesProvider = StreamProvider.autoDispose<List<FixedExpense>>((ref) {
  final repository = ref.watch(cycleRepositoryProvider);
  return repository.watchUnlinkedCreditCharges();
});
