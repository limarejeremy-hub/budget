import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/domain/calculations/charge_sorting.dart';
import 'package:budgetpilot/domain/entities/fixed_expense_entity.dart';

void main() {
  final today = DateTime(2026, 8, 1);

  FixedExpenseEntity charge({
    required int id,
    required String name,
    required int cents,
    DateTime? date,
    String status = ChargeStatus.aVenir,
    int? categoryId,
    bool isActive = true,
  }) =>
      FixedExpenseEntity(
        id: id,
        cycleId: 1,
        name: name,
        expectedAmountCents: cents,
        expectedDate: date ?? today,
        status: status,
        categoryId: categoryId,
        isActive: isActive,
      );

  final loyer = charge(id: 1, name: 'Loyer', cents: 95000, date: DateTime(2026, 8, 5), categoryId: 1);
  final creditAuto = charge(id: 2, name: 'Crédit auto', cents: 28000, date: DateTime(2026, 8, 10), categoryId: 2);
  final electricite = charge(id: 3, name: 'Électricité', cents: 14500, date: DateTime(2026, 8, 1), categoryId: 3);
  final all = [loyer, creditAuto, electricite];
  const categoryNames = {1: 'Logement', 2: 'Crédit', 3: 'Énergie'};

  group('sortCharges', () {
    test('tri montant décroissant', () {
      final sorted = sortCharges(all, field: ChargeSortField.amount, ascending: false);
      expect(sorted.map((c) => c.name), ['Loyer', 'Crédit auto', 'Électricité']);
    });

    test('tri montant croissant', () {
      final sorted = sortCharges(all, field: ChargeSortField.amount, ascending: true);
      expect(sorted.map((c) => c.name), ['Électricité', 'Crédit auto', 'Loyer']);
    });

    test('tri date : plus proche d\'abord (ascendant)', () {
      final sorted = sortCharges(all, field: ChargeSortField.date, ascending: true);
      expect(sorted.map((c) => c.name), ['Électricité', 'Loyer', 'Crédit auto']);
    });

    test('tri date : plus lointaine d\'abord (descendant)', () {
      final sorted = sortCharges(all, field: ChargeSortField.date, ascending: false);
      expect(sorted.map((c) => c.name), ['Crédit auto', 'Loyer', 'Électricité']);
    });

    test('tri nom A -> Z', () {
      final sorted = sortCharges(all, field: ChargeSortField.name, ascending: true);
      expect(sorted.map((c) => c.name), ['Crédit auto', 'Électricité', 'Loyer']);
    });

    test('tri catégorie utilise les noms fournis, alphabétique', () {
      final sorted = sortCharges(all, field: ChargeSortField.category, ascending: true, categoryNames: categoryNames);
      // Crédit, Énergie, Logement (ordre alphabétique des noms de catégorie).
      expect(sorted.map((c) => c.name), ['Crédit auto', 'Électricité', 'Loyer']);
    });

    test('tri catégorie : une charge sans catégorie est toujours en dernier', () {
      final sansCategorie = charge(id: 4, name: 'Divers', cents: 5000, categoryId: null);
      final sorted = sortCharges(
        [...all, sansCategorie],
        field: ChargeSortField.category,
        ascending: true,
        categoryNames: categoryNames,
      );
      expect(sorted.last.name, 'Divers');

      final sortedDesc = sortCharges(
        [...all, sansCategorie],
        field: ChargeSortField.category,
        ascending: false,
        categoryNames: categoryNames,
      );
      expect(sortedDesc.last.name, 'Divers');
    });

    test('tri statut : les charges les plus urgentes (incident, à confirmer) en premier', () {
      final incident = charge(id: 5, name: 'Assurance', cents: 6000, status: ChargeStatus.incident);
      final prelevee = charge(id: 6, name: 'Internet', cents: 3500, status: ChargeStatus.prelevee);
      final sorted = sortCharges([prelevee, incident], field: ChargeSortField.status, ascending: true);
      expect(sorted.map((c) => c.name), ['Assurance', 'Internet']);
    });

    test('compatibilité recherche + tri : trie uniquement le sous-ensemble déjà filtré par la recherche', () {
      const query = 'é'; // matche "Crédit auto" et "Électricité"
      final filtered = all.where((c) => c.name.toLowerCase().contains(query)).toList();
      final sorted = sortCharges(filtered, field: ChargeSortField.amount, ascending: false);
      expect(sorted.map((c) => c.name), ['Crédit auto', 'Électricité']);
    });

    test('ne modifie jamais la liste reçue en entrée (nouvelle liste retournée)', () {
      final original = [...all];
      sortCharges(all, field: ChargeSortField.amount, ascending: true);
      expect(all.map((c) => c.id), original.map((c) => c.id));
    });
  });

  group('topCharges', () {
    test('les 3 charges les plus coûteuses, montant décroissant', () {
      final top = topCharges(all);
      expect(top.map((c) => c.name), ['Loyer', 'Crédit auto', 'Électricité']);
    });

    test('exclut les charges inactives et suspendues', () {
      final suspendue = charge(id: 7, name: 'Salle de sport', cents: 990000, status: ChargeStatus.suspendue);
      final inactive = charge(id: 8, name: 'Ancien abonnement', cents: 500000, isActive: false);
      final top = topCharges([...all, suspendue, inactive]);
      expect(top.map((c) => c.name), ['Loyer', 'Crédit auto', 'Électricité']);
    });

    test('limite à count éléments (par défaut 3)', () {
      final many = [
        ...all,
        charge(id: 9, name: 'Internet', cents: 4000),
        charge(id: 10, name: 'Téléphone', cents: 2500),
      ];
      expect(topCharges(many), hasLength(3));
    });

    test('vide si aucune charge éligible', () {
      expect(topCharges(const []), isEmpty);
    });
  });
}
