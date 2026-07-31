import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/branding/brand_resolver.dart';

void main() {
  test('reconnaît une marque connue, insensible à la casse', () {
    final brand = resolveBrand('Abonnement Netflix');
    expect(brand?.id, 'netflix');
    expect(brand?.displayName, 'Netflix');
  });

  test('reconnaît une marque même en minuscules ou majuscules', () {
    expect(resolveBrand('EDF')?.id, 'edf');
    expect(resolveBrand('edf électricité')?.id, 'edf');
  });

  test('reconnaît plusieurs variantes pour une même marque', () {
    expect(resolveBrand('Amazon Prime')?.id, 'prime_video');
    expect(resolveBrand('Total Energies')?.id, 'totalenergies');
  });

  test('renvoie null pour un nom non reconnu', () {
    expect(resolveBrand('Marché du coin'), isNull);
    expect(resolveBrand(''), isNull);
    expect(resolveBrand(null), isNull);
  });

  test('chaque marque du catalogue a un monogramme non vide', () {
    expect(resolveBrand('Spotify')?.monogram, 'S');
    expect(resolveBrand('Carrefour')?.monogram, 'C');
  });
}
