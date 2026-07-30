# BudgetPilot

Application Flutter de suivi budgétaire mensuel personnel — cycle du 27 au 26,
centrée sur le calcul du "reste réel" (Argent Libre).

Cible V1 : Android uniquement.

## Démarrage

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Tests

```bash
flutter test
```

## État du projet

- Phase 1 — Socle : ✅ (base Drift, thème, navigation, service de calcul, service de statut des charges)
- Phase 2 — Tableau de bord : ✅ (Argent Libre, résumé du cycle, section "À surveiller", bouton "+")
- Phase 3 — Saisie réelle : ✅ (création de cycle, ajout/modification/suppression des revenus,
  charges fixes, dépenses variables et épargnes, écrans Charges/Dépenses/Historique/Paramètres)
- Statistiques avancées, export, synchronisation bancaire, refonte visuelle : à venir
