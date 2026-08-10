import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/providers/shell_providers.dart';

void main() {
  test('shellTabIndexProvider démarre sur l\'onglet Accueil (0)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(shellTabIndexProvider), 0);
  });

  test(
      'shellTabIndexProvider peut être ramené sur Accueil depuis n\'importe quel onglet — '
      'utilisé par "Repartir de zéro" pour revenir automatiquement à la création du premier cycle', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(shellTabIndexProvider.notifier).state = 4; // onglet Paramètres
    expect(container.read(shellTabIndexProvider), 4);

    container.read(shellTabIndexProvider.notifier).state = 0;
    expect(container.read(shellTabIndexProvider), 0);
  });
}
