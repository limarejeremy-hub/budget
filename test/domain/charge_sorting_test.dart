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

  group('usedChargeCategories (correction UX, §1 : génération dynamique)', () {
    test('renvoie uniquement les catégories réellement utilisées, jamais une liste codée en dur', () {
      final options = usedChargeCategories(all, categoryNames: categoryNames);
      expect(options.map((o) => o.name), ['Crédit', 'Énergie', 'Logement']);
    });

    test('une catégorie non utilisée par aucune charge n\'apparaît jamais', () {
      final onlyLoyer = [loyer];
      final options = usedChargeCategories(onlyLoyer, categoryNames: categoryNames);
      expect(options.map((o) => o.name), ['Logement']);
    });

    test('les charges sans catégorie apparaissent comme "Sans catégorie"', () {
      final sansCategorie = charge(id: 4, name: 'Divers', cents: 5000, categoryId: null);
      final options = usedChargeCategories([sansCategorie], categoryNames: categoryNames);
      expect(options.single.categoryId, isNull);
      expect(options.single.name, 'Sans catégorie');
    });

    test('triées par ordre alphabétique, insensible aux accents', () {
      final options = usedChargeCategories(all, categoryNames: categoryNames);
      expect(options.map((o) => o.categoryId), [2, 3, 1]); // Crédit, Énergie, Logement
    });
  });

  group('categoryTotals (correction UX, §2/§3 : coût réel du groupe, classement)', () {
    test('calcule le total mensuel de chaque catégorie à partir des charges enregistrées', () {
      final maison1 = charge(id: 10, name: 'Crédit Maison', cents: 45300, categoryId: 1);
      final maison2 = charge(id: 11, name: 'Fenêtres', cents: 36900, categoryId: 1);
      final totals = categoryTotals([maison1, maison2], categoryNames: {1: 'Maison'});
      expect(totals.single.categoryName, 'Maison');
      expect(totals.single.totalCents, 45300 + 36900);
    });

    test('classement du plus coûteux au moins coûteux', () {
      final totals = categoryTotals(all, categoryNames: categoryNames);
      expect(totals.map((t) => t.categoryName), ['Logement', 'Crédit', 'Énergie']);
      expect(totals.map((t) => t.totalCents), [95000, 28000, 14500]);
    });

    test('exclut les charges inactives et suspendues du total (comme calculateTotalFixedExpenses)', () {
      final active = charge(id: 20, name: 'Loyer', cents: 90000, categoryId: 1);
      final suspendue =
          charge(id: 21, name: 'Salle de sport', cents: 50000, categoryId: 1, status: ChargeStatus.suspendue);
      final inactive = charge(id: 22, name: 'Ancien abonnement', cents: 30000, categoryId: 1, isActive: false);
      final totals = categoryTotals([active, suspendue, inactive], categoryNames: {1: 'Maison'});
      expect(totals.single.totalCents, 90000);
    });

    test('absence de double comptage : une charge liée à un crédit n\'est comptée qu\'une seule fois', () {
      final linked = FixedExpenseEntity(
        id: 30,
        cycleId: 1,
        name: 'Mensualité voiture',
        expectedAmountCents: 28000,
        expectedDate: today,
        categoryId: 2,
        linkedCreditId: 7,
      );
      final totals = categoryTotals([linked], categoryNames: {2: 'Crédit'});
      expect(totals.single.totalCents, 28000);
    });

    test('regroupe les charges sans catégorie sous "Sans catégorie"', () {
      final sansCategorie = charge(id: 40, name: 'Divers', cents: 5000, categoryId: null);
      final totals = categoryTotals([sansCategorie], categoryNames: categoryNames);
      expect(totals.single.categoryId, isNull);
      expect(totals.single.categoryName, 'Sans catégorie');
    });

    test('vide si aucune charge', () {
      expect(categoryTotals(const [], categoryNames: categoryNames), isEmpty);
    });
  });
}
