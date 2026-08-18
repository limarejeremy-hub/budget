import '../../core/constants/app_constants.dart';
import '../entities/fixed_expense_entity.dart';

/// Champs de tri disponibles pour la liste des charges fixes (V1.2, §1).
enum ChargeSortField { date, amount, name, category, status }

/// Ordre de "sévérité" utilisé pour le tri par statut — les charges qui
/// demandent le plus d'attention en premier, jamais un ordre alphabétique.
const List<String> _statusSeverityOrder = [
  ChargeStatus.incident,
  ChargeStatus.aConfirmer,
  ChargeStatus.aVerifierAujourdhui,
  ChargeStatus.aVenir,
  ChargeStatus.prelevee,
  ChargeStatus.suspendue,
];

int _statusRank(String status) {
  final index = _statusSeverityOrder.indexOf(status);
  return index == -1 ? _statusSeverityOrder.length : index;
}

/// Compare deux charges par nom de catégorie — une charge sans catégorie
/// (ou dont la catégorie est inconnue) est toujours placée en dernier, quel
/// que soit le sens du tri, jamais mélangée arbitrairement parmi les
/// catégories nommées.
int _compareCategory(
  FixedExpenseEntity a,
  FixedExpenseEntity b,
  Map<int, String> categoryNames,
  bool ascending,
) {
  final aName = a.categoryId == null ? null : categoryNames[a.categoryId];
  final bName = b.categoryId == null ? null : categoryNames[b.categoryId];
  if (aName == null && bName == null) return 0;
  if (aName == null) return 1;
  if (bName == null) return -1;
  final comparison = _foldDiacritics(aName.toLowerCase()).compareTo(_foldDiacritics(bName.toLowerCase()));
  return ascending ? comparison : -comparison;
}

/// Réduit les caractères accentués français à leur lettre de base pour le
/// tri alphabétique ("Électricité" trie avec les "E", jamais après les "Z"
/// à cause de l'ordre Unicode brut des caractères accentués).
String _foldDiacritics(String input) {
  const replacements = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ÿ': 'y',
    'œ': 'oe',
  };
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(replacements[char] ?? char);
  }
  return buffer.toString();
}

/// Trie une liste de charges fixes selon [field] et [ascending] — pur, sans
/// dépendance Flutter, réutilisable par la page Charges (fonctionne après
/// une recherche/un filtre déjà appliqués, jamais couplé à eux) et testable
/// indépendamment de l'UI. [categoryNames] associe `categoryId` à son nom
/// pour le tri "Catégorie".
List<FixedExpenseEntity> sortCharges(
  List<FixedExpenseEntity> charges, {
  required ChargeSortField field,
  required bool ascending,
  Map<int, String> categoryNames = const {},
}) {
  final sorted = [...charges]..sort((a, b) {
      // Le tri par catégorie gère lui-même le sens du tri : une charge sans
      // catégorie reste toujours en dernier (jamais inversée avec le reste).
      if (field == ChargeSortField.category) return _compareCategory(a, b, categoryNames, ascending);

      final comparison = switch (field) {
        ChargeSortField.date => a.expectedDate.compareTo(b.expectedDate),
        ChargeSortField.amount => a.effectiveAmountCents.compareTo(b.effectiveAmountCents),
        ChargeSortField.name => _foldDiacritics(a.name.toLowerCase()).compareTo(_foldDiacritics(b.name.toLowerCase())),
        ChargeSortField.category => 0, // traité ci-dessus
        ChargeSortField.status => _statusRank(a.status).compareTo(_statusRank(b.status)),
      };
      return ascending ? comparison : -comparison;
    });
  return sorted;
}

/// Une catégorie de charge fixe réellement utilisée, avec son nom résolu —
/// `categoryId == null` représente les charges sans catégorie. Jamais une
/// liste codée en dur : toujours dérivée des charges existantes.
class ChargeCategoryOption {
  final int? categoryId;
  final String name;
  const ChargeCategoryOption({required this.categoryId, required this.name});
}

/// Catégories réellement utilisées parmi [charges] (jamais une liste codée
/// en dur), triées par nom alphabétique (insensible aux accents) pour un
/// menu déroulant prévisible — voir [categoryTotals] pour un classement par
/// coût.
List<ChargeCategoryOption> usedChargeCategories(
  List<FixedExpenseEntity> charges, {
  required Map<int, String> categoryNames,
}) {
  final ids = charges.map((c) => c.categoryId).toSet();
  final options = ids.map((id) {
    final name = id == null ? 'Sans catégorie' : (categoryNames[id] ?? 'Sans catégorie');
    return ChargeCategoryOption(categoryId: id, name: name);
  }).toList()
    ..sort((a, b) => _foldDiacritics(a.name.toLowerCase()).compareTo(_foldDiacritics(b.name.toLowerCase())));
  return options;
}

/// Coût total mensuel d'une catégorie de charges fixes.
class CategoryChargeTotal {
  final int? categoryId;
  final String categoryName;
  final int totalCents;
  const CategoryChargeTotal({required this.categoryId, required this.categoryName, required this.totalCents});
}

/// Coût total mensuel de chaque catégorie réellement utilisée — LA seule
/// formule de total par catégorie, réutilisée à la fois par l'en-tête de
/// catégorie sélectionnée et par le classement. Reprend
/// `effectiveAmountCents` (montant réel si connu, sinon montant prévu) et
/// exclut les charges inactives ou suspendues, exactement comme
/// `BudgetCalculationService.calculateTotalFixedExpenses` — jamais un
/// nouveau calcul du montant d'une charge. Exclut aussi les charges
/// reportées au prochain cycle (§ "Affectation manuelle d'une charge au
/// prochain cycle", §9) : elles restent consultables dans leur catégorie
/// (badge "Prochain cycle"), mais ne participent plus au total du cycle
/// actuel. Chaque charge (y compris liée à un crédit) n'est comptée qu'une
/// seule fois, dans sa seule catégorie. Trié du plus coûteux au moins
/// coûteux ("classement par coût").
List<CategoryChargeTotal> categoryTotals(
  List<FixedExpenseEntity> charges, {
  required Map<int, String> categoryNames,
}) {
  final eligible = charges.where((c) => c.isActive && c.status != ChargeStatus.suspendue && !c.deferredToNextCycle);
  final totals = <int?, int>{};
  for (final charge in eligible) {
    totals.update(
      charge.categoryId,
      (sum) => sum + charge.effectiveAmountCents,
      ifAbsent: () => charge.effectiveAmountCents,
    );
  }
  final result = totals.entries.map((entry) {
    final id = entry.key;
    final name = id == null ? 'Sans catégorie' : (categoryNames[id] ?? 'Sans catégorie');
    return CategoryChargeTotal(categoryId: id, categoryName: name, totalCents: entry.value);
  }).toList()
    ..sort((a, b) => b.totalCents.compareTo(a.totalCents));
  return result;
}
