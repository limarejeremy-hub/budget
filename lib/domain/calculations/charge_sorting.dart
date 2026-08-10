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

/// Les charges les plus coûteuses — "Charges les plus importantes" (V1.2,
/// §1), montant décroissant, parmi les charges réellement actives (exclut
/// les charges inactives et suspendues, qui ne pèsent pas sur le budget
/// courant). Vide si aucune charge n'est éligible.
List<FixedExpenseEntity> topCharges(List<FixedExpenseEntity> charges, {int count = 3}) {
  final eligible = charges.where((c) => c.isActive && c.status != ChargeStatus.suspendue).toList()
    ..sort((a, b) => b.effectiveAmountCents.compareTo(a.effectiveAmountCents));
  return eligible.take(count).toList();
}
