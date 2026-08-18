import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Onglet sélectionné dans la barre de navigation principale (`AppShell`).
/// Exposé en provider plutôt qu'en simple état local pour permettre à une
/// action ailleurs dans l'application — ex. "Repartir de zéro" dans
/// Paramètres — de ramener l'utilisateur sur l'onglet Accueil.
final shellTabIndexProvider = StateProvider<int>((ref) => 0);
