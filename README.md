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
- Phase 5 (V0.5) — Expérience premium : ✅ (carte Argent Libre "carte bancaire" avec marque
  vectorielle BudgetPilot, montants animés, section "Aujourd'hui", barre de progression du
  cycle, listes avec recherche/tri/filtres, fiche détaillée de charge (modifier / marquer
  prélevée / dupliquer / supprimer), thème clair/sombre/système persisté, écran Documentation,
  transitions de page, design system centralisé)
- Phase 6 (V0.6) — Carte bancaire premium+ : ✅ (puce EMV et reflet animé sur la carte Argent
  Libre, résumé du cycle en décompte — jamais de pourcentage —, sections "Cette semaine" et
  "Résumé rapide", reconnaissance automatique de marques connues avec badge monogramme
  extensible et repli générique, apparition en cascade des listes, design system unifié
  (champs, dialogues, BottomSheets, boutons, chips))
- Phase 7 (V0.7) — Module Crédits : ✅ (suivi complet des crédits en cours — indépendant des
  cycles budgétaires —, carte "Crédits" cliquable sur l'accueil, CRUD complet, tri par
  priorité au choix de l'utilisateur, indicateurs comparatifs, simulation simplifiée de
  versement anticipé, crédits inclus dans la sauvegarde export/import avec compatibilité
  ascendante ; suppression de "Résumé rapide", section "Cette semaine" compacte quand vide,
  indicateur "Jour X / Y" sur la progression du cycle, finitions de la carte Argent Libre ;
  personnalisation par crédit — organisme, couleur, icône — priorité automatique par étoiles
  (jamais imposée), simulateur multi-crédits comparant l'impact d'un même versement sur
  chaque crédit actif, encart discret "Objectif conseillé" sur le tableau de bord)
- Phase 8 (V0.8) — Crédit Manager Premium : ✅ (progression intelligente — montant initial
  connu, sinon durée totale déduite des dates, sinon capital restant en dernier recours —,
  dates toujours affichées avec l'année, indicateurs en petites cartes premium (crédit le
  plus proche de la fin, plus grosse mensualité, plus coûteux, plus gros capital restant),
  simulateur de versement exceptionnel entièrement refondu — montant versé, capital restant,
  gain estimé, nouvelle fin, mensualité inchangée, encart "économies estimées" —, score visuel
  automatique par mensualités restantes (🟢🟡🟠🔴), cartes crédit enrichies — banque, badge de
  priorité, espacements et typographie premium —, architecture préparée pour la V0.9
  [décrémentation automatique des crédits] sans l'activer)
- Phase 9 (V0.9) — Smart Automation : ✅ (un crédit ne se crée qu'une fois — sa charge fixe
  mensuelle, ses notifications et ses projections sont générées automatiquement ; fusion
  Charges ⇄ Crédits par lien direct, plus aucun doublon possible, même après import d'une
  sauvegarde ou migration depuis une version antérieure ; carte "Aujourd'hui" cliquable ouvrant
  un centre de confirmations — ✅ confirmer, ✏️ modifier le montant réel, ⏰ reporter,
  ❌ ignorer — qui décrémente automatiquement le capital, les mensualités restantes et la date
  de fin d'un crédit dès qu'une mensualité est confirmée ; notifications locales Android
  (`flutter_local_notifications`, 100 % hors-ligne) avec actions directes depuis la
  notification (confirmer / rappeler dans 2 h / ignorer aujourd'hui) ; badge du nombre
  d'opérations en attente sur la carte "Aujourd'hui" et centre de notifications dédié avec
  historique persistant ; chaque nouveau cycle régénère automatiquement les charges de tous
  les crédits actifs, sans aucune ressaisie)
- Statistiques avancées, synchronisation bancaire : à venir
