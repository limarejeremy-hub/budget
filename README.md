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

## Conservation des données

Voir [`docs/DATA_PERSISTENCE.md`](docs/DATA_PERSISTENCE.md) : quand les
données survivent à une mise à jour de l'APK, quand elles peuvent être
perdues, stratégie de signature, et sauvegarde manuelle (export/import JSON
depuis Paramètres).

## État du projet

- Phase 1 — Socle : ✅ (base Drift, thème, navigation, service de calcul, service de statut des charges)
- Phase 2 — Tableau de bord : ✅ (Argent Libre, résumé du cycle, section "À surveiller", bouton "+")
- Phase 3 — Saisie réelle : ✅ (création de cycle, ajout/modification/suppression des revenus,
  charges fixes, dépenses variables et épargnes, écrans Charges/Dépenses/Historique/Paramètres)
- Phase 4 (V0.4) — Tableau de bord cliquable et conservation des données : ✅ (détail du cycle,
  navigation depuis chaque carte, changement de statut des charges, éléments à surveiller,
  sauvegarde export/import, signature de release stable)
- Statistiques avancées, synchronisation bancaire, refonte visuelle supplémentaire : à venir
