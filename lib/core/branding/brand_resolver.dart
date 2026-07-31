import 'brand_catalog.dart';

/// Reconnaît une marque à partir d'un nom saisi librement par l'utilisateur
/// (ex : "Abonnement Netflix" → Netflix), par correspondance de
/// sous-chaîne insensible à la casse et aux accents simples. Renvoie `null`
/// si aucune marque du catalogue ne correspond — l'appelant doit alors
/// utiliser une icône générique de secours.
Brand? resolveBrand(String? name) {
  if (name == null || name.trim().isEmpty) return null;
  final normalized = _normalize(name);

  for (final brand in kBrandCatalog) {
    for (final matcher in brand.matchers) {
      if (normalized.contains(_normalize(matcher))) return brand;
    }
  }
  return null;
}

String _normalize(String input) => input.toLowerCase().trim();
