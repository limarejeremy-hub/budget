import 'package:flutter/material.dart';

/// Une marque reconnue automatiquement à partir du nom saisi par
/// l'utilisateur (ex : "Netflix", "abonnement netflix"). BudgetPilot
/// n'intègre aucune image ni logo protégé (pas d'accès réseau, pas de
/// dépendance cloud à une API de logos) : chaque marque est représentée par
/// un badge vectoriel discret (monogramme + couleur caractéristique de la
/// marque), ce qui reste léger, hors-ligne, et sans risque de droits
/// d'auteur sur des artworks tiers.
class Brand {
  final String id;
  final String displayName;
  final List<String> matchers;
  final Color color;
  final IconData? icon;

  const Brand({
    required this.id,
    required this.displayName,
    required this.matchers,
    required this.color,
    this.icon,
  });

  /// Lettre affichée dans le badge quand aucune icône dédiée n'est fournie.
  String get monogram => displayName.isEmpty ? '?' : displayName[0].toUpperCase();
}

/// Catalogue des marques reconnues — facilement extensible : il suffit
/// d'ajouter une entrée avec ses variantes de nom (en minuscules).
const List<Brand> kBrandCatalog = [
  // Streaming / abonnements
  Brand(id: 'netflix', displayName: 'Netflix', matchers: ['netflix'], color: Color(0xFFE50914)),
  Brand(id: 'disney_plus', displayName: 'Disney+', matchers: ['disney'], color: Color(0xFF113CCF)),
  Brand(id: 'prime_video', displayName: 'Prime Video', matchers: ['prime video', 'amazon prime'], color: Color(0xFF00A8E1)),
  Brand(id: 'canal_plus', displayName: 'Canal+', matchers: ['canal+', 'canal plus'], color: Color(0xFF000000)),
  Brand(id: 'spotify', displayName: 'Spotify', matchers: ['spotify'], color: Color(0xFF1DB954)),
  Brand(id: 'youtube_premium', displayName: 'YouTube Premium', matchers: ['youtube'], color: Color(0xFFFF0000)),

  // Énergie
  Brand(id: 'edf', displayName: 'EDF', matchers: ['edf'], color: Color(0xFFFF7900)),
  Brand(id: 'engie', displayName: 'Engie', matchers: ['engie'], color: Color(0xFF00AAA0)),
  Brand(id: 'totalenergies', displayName: 'TotalEnergies', matchers: ['totalenergies', 'total energies', 'total'], color: Color(0xFFD1001F)),

  // Grande distribution
  Brand(id: 'carrefour', displayName: 'Carrefour', matchers: ['carrefour'], color: Color(0xFF0066B3)),
  Brand(id: 'leclerc', displayName: 'Leclerc', matchers: ['leclerc'], color: Color(0xFF0055A4)),
  Brand(id: 'lidl', displayName: 'Lidl', matchers: ['lidl'], color: Color(0xFFFFD100)),
  Brand(id: 'auchan', displayName: 'Auchan', matchers: ['auchan'], color: Color(0xFFE2001A)),
  Brand(id: 'amazon', displayName: 'Amazon', matchers: ['amazon'], color: Color(0xFFFF9900)),

  // Tech
  Brand(id: 'apple', displayName: 'Apple', matchers: ['apple', 'itunes', 'icloud'], color: Color(0xFF555555)),
  Brand(id: 'google', displayName: 'Google', matchers: ['google'], color: Color(0xFF4285F4)),
  Brand(id: 'samsung', displayName: 'Samsung', matchers: ['samsung'], color: Color(0xFF1428A0)),

  // Automobile
  Brand(id: 'renault', displayName: 'Renault', matchers: ['renault'], color: Color(0xFFFFCC00)),
  Brand(id: 'peugeot', displayName: 'Peugeot', matchers: ['peugeot'], color: Color(0xFF1B1B1B)),
  Brand(id: 'alfa_romeo', displayName: 'Alfa Romeo', matchers: ['alfa romeo', 'alfaromeo'], color: Color(0xFFA6122E)),

  // Banques
  Brand(id: 'credit_agricole', displayName: 'Crédit Agricole', matchers: ['credit agricole', 'crédit agricole'], color: Color(0xFF00995A)),
  Brand(id: 'bnp', displayName: 'BNP Paribas', matchers: ['bnp'], color: Color(0xFF00915A)),
  Brand(id: 'banque_postale', displayName: 'La Banque Postale', matchers: ['banque postale'], color: Color(0xFFFFCD00)),
  Brand(id: 'caisse_epargne', displayName: "Caisse d'Épargne", matchers: ['caisse d\'epargne', 'caisse depargne', 'caisse d\'épargne'], color: Color(0xFFE2001A)),

  // Télécoms
  Brand(id: 'free', displayName: 'Free', matchers: ['free'], color: Color(0xFFCC0000)),
  Brand(id: 'sfr', displayName: 'SFR', matchers: ['sfr'], color: Color(0xFFE2001A)),
  Brand(id: 'bouygues', displayName: 'Bouygues Telecom', matchers: ['bouygues'], color: Color(0xFF00A9E0)),
  Brand(id: 'orange', displayName: 'Orange', matchers: ['orange'], color: Color(0xFFFF7900)),
];
