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
- Phase 10 (V1.0) — Project Planner : ✅ (nouveau module "Projets" — voiture, travaux,
  immobilier, voyage, mariage, gros achat, autre —, accessible depuis une carte dédiée sur
  l'accueil qui devient automatiquement "Projet prioritaire" dès qu'un projet actif existe ;
  moteur de faisabilité déterministe et testé indépendamment de l'UI [`ProjectFeasibilityService`]
  qui répond à "Puis-je réellement réaliser ce projet ?" avec un score sur 100 multi-critères —
  jamais un simple `apport / prix` — et identifie explicitement ce qui bloque, ce qui va
  s'améliorer [crédits actifs proches de leur fin], le chemin recommandé et des scénarios
  alternatifs [`ProjectScenarioService`] ; simulateur interactif qui ne modifie jamais les
  vraies données tant que l'utilisateur ne choisit pas explicitement d'enregistrer ; feuille de
  route calculée uniquement à partir d'événements financiers réels et connus ; fiche projet,
  liste avec archivage, formulaire de création/modification ; voir la section dédiée
  "Project Feasibility Score" ci-dessous pour le détail de la formule)
- Phase 11 (V1.1) — Safe Projects : ✅ (multi-projets — plusieurs projets actifs en parallèle,
  chacun indépendant, avec priorité utilisateur Haute/Moyenne/Basse, duplication ; le Project
  Planner répond désormais aussi à "Est-ce que ce projet reste sain pour mon budget ?", pas
  seulement "est-ce mathématiquement faisable" — nouveau **Financial Safety Score** distinct
  du score de faisabilité : reste à vivre avant/après, taux d'endettement avant/après avec
  repères BudgetPilot internes [jamais une décision bancaire], marge consommée par le projet ;
  les deux scores restent toujours affichés côte à côte, jamais masqués par un résumé global ;
  le chemin recommandé privilégie désormais la sécurité financière — jamais le scénario au
  score de faisabilité le plus élevé s'il resterait dangereux pour le budget ; bloqueurs
  enrichis et classés par importance [1 à 3 maximum] ; voir la section dédiée "Financial
  Safety Score" ci-dessous pour le détail de la formule)
- Statistiques avancées, synchronisation bancaire : à venir

## Project Planner — Project Feasibility Score (V1.0)

Le module **Projets** répond à une question que BudgetPilot ne posait pas encore :
*"Puis-je réellement réaliser ce projet ?"* — pas seulement "combien ai-je économisé pour
lui". Il réutilise entièrement les données déjà suivies par l'application (argent libre,
revenus, charges fixes, crédits actifs, mensualités, dates de fin, capital restant) : le
Project Planner n'a pas sa propre source de vérité financière, il l'exploite.

### Le score n'est pas `apport / prix`

Le Project Feasibility Score (`ProjectFeasibilityService.evaluate`, dans
`lib/domain/calculations/project_feasibility_service.dart`) combine six facteurs
indépendants, chacun noté sur 100 puis pondéré :

| Facteur | Pondération | Ce qu'il mesure |
|---|---|---|
| A — Capacité mensuelle | 0.25 | Impact mensuel du projet (mensualité + coûts supplémentaires) rapporté à l'argent libre actuel |
| B — Marge de sécurité | 0.20 | Ce qu'il reste après le projet, comparé à la marge de sécurité cible (§ ci-dessous) |
| C — Apport / besoin de financement | 0.20 | Part du prix déjà couverte par l'apport disponible |
| D — Pression des crédits actuels | 0.15 | Poids des mensualités de crédits déjà en cours par rapport à l'argent libre |
| E — Évolution future connue | 0.10 | Capacité que les crédits en cours vont libérer à leur échéance |
| F — Horizon du projet | 0.10 | Compatibilité entre la date souhaitée (si renseignée) et le moment où le projet deviendrait réaliste |

Le score final est la moyenne pondérée de ces six facteurs, arrondie et bornée à
`[0, 100]`. Les pondérations sont des constantes documentées
(`kWeightCapacity`, `kWeightSafetyMargin`, …) — jamais dispersées dans le calcul.

Niveaux affichés :

| Score | Niveau |
|---|---|
| 0–39 | 🔴 Très difficile actuellement |
| 40–59 | 🟠 Fragile |
| 60–74 | 🟡 Envisageable |
| 75–89 | 🟢 Réalisable |
| 90–100 | 🟢 Très confortable |

### Marge de sécurité

BudgetPilot ne considère jamais que 100 % de l'argent libre peut être consommé par un
projet. La marge de sécurité cible est `kSafetyMarginRatio` (20 %) de l'argent libre actuel
— un ratio, pas un seuil fixe caché — et influence directement le facteur B.

### Hypothèses de financement — jamais silencieuses

Quand un projet nécessite un financement (`prix cible − apport = besoin de financement`),
la mensualité est estimée :

- avec la formule d'amortissement classique si un taux est renseigné ;
- sinon avec une estimation simplifiée `capital / durée` (linéaire, sans intérêts) —
  signalée explicitement (`isRateEstimated`) partout où elle est affichée ;
- si ni durée ni mensualité maximale ne sont connues, une durée par défaut de 60 mois est
  utilisée et signalée (`isDurationEstimated`).

### Ce qui va s'améliorer, chemin recommandé, feuille de route

Le moteur détecte les crédits actifs qui se termineront prochainement et recalcule le score
"après" leur fin. Le moteur de scénarios (`ProjectScenarioService`) explore ensuite plusieurs
leviers réalistes — attendre la fin d'un crédit, augmenter l'apport, solder un petit crédit,
réduire le montant du projet, étendre l'horizon — et propose un **chemin recommandé** qui
n'est jamais simplement celui qui maximise le score : l'effort, le délai et l'argent mobilisé
sont pris en compte. Solder un crédit n'est jamais recommandé automatiquement — le module
affiche une comparaison réelle entre l'argent utilisé pour solder, la mensualité libérée et
le gain sur le projet, et laisse la décision à l'utilisateur. La feuille de route n'affiche
que des événements financiers réels et connus (fins de crédits) — jamais une projection
inventée.

### Ce que le score n'est pas

Le score de faisabilité est une estimation interne à BudgetPilot, jamais une décision
bancaire, une capacité d'emprunt officielle ou un conseil financier réglementé. Cette
précision est affichée sur chaque fiche projet :

> Estimation BudgetPilot basée sur les données enregistrées dans l'application.

### Limites connues

- Le simulateur interactif (§15) permet aujourd'hui de tester un autre apport ou un autre
  prix cible sans jamais modifier les vraies données tant que l'enregistrement n'est pas
  explicitement demandé ; il ne couvre pas encore l'ensemble des leviers de simulation
  possibles (mensualité cible, durée, date, remboursement anticipé d'un crédit).
- La projection de croissance de l'apport dans le temps (§11) n'est activée que si une
  capacité d'épargne régulière fiable est fournie au moteur — BudgetPilot n'invente jamais
  cette capacité si elle n'est pas connue avec certitude.

## Project Planner — Financial Safety Score (V1.1)

Le score de faisabilité (V1.0) répond à "est-ce mathématiquement possible ?". Il ne répond
pas à une question tout aussi essentielle : *"est-ce que ce projet reste sain pour mon
budget ?"*. La V1.1 — **Safe Projects** — ajoute un second score, indépendant, qui répond à
celle-là : le **Financial Safety Score**
(`ProjectSafetyService`, dans `lib/domain/calculations/project_safety_service.dart`).

Les deux scores sont **toujours affichés côte à côte** — fiche projet, liste des projets,
carte "Projet prioritaire" de l'accueil, simulateur — jamais l'un sans l'autre, et jamais
remplacés silencieusement par un résumé unique. Un score de faisabilité élevé ne garantit
jamais un bon score de sécurité : un projet peut être finançable tout en fragilisant
fortement le budget.

### Formule du Financial Safety Score

Trois critères, chacun sur 0-100, combinés en une moyenne pondérée (constantes
`kSafetyWeight*`, documentées dans le code) :

| Critère | Pondération | Ce qu'il mesure |
|---|---|---|
| Taux d'endettement après projet | 0.40 | Mensualités de crédits actifs + mensualité de financement du projet, rapportées au revenu |
| Reste à vivre relatif au revenu | 0.35 | Part du revenu consommée par l'impact mensuel du projet (mensualité + coûts supplémentaires) — jamais un montant fixe seul (§5) |
| Baisse relative du reste à vivre | 0.25 | Écart entre le reste à vivre avant et après le projet, rapporté au reste à vivre actuel |

Niveaux affichés (mêmes couleurs que le reste de l'application — vert/jaune/orange/rouge) :

| Score | Niveau |
|---|---|
| 0–39 | 🔴 Risque élevé |
| 40–59 | 🟠 Tendue |
| 60–79 | 🟡 Acceptable |
| 80–100 | 🟢 Saine |

### Reste à vivre — jamais recalculé indépendamment

`ProjectSafetyService` réutilise l'argent libre déjà calculé par
`BudgetCalculationService`/`DashboardViewBuilder` comme "reste à vivre actuel" — il ne le
recalcule jamais. Le "reste à vivre après projet" est simplement ce montant moins l'impact
mensuel du projet.

### Taux d'endettement — repères internes, jamais une décision bancaire

Le taux d'endettement (mensualités de crédits actifs + mensualité de financement du projet,
divisées par le revenu mensuel) est comparé à des repères **internes à BudgetPilot**,
centralisés dans le code (`kDebtRatioComfortable` = 30 %, `kDebtRatioWatch` = 35 %,
`kDebtRatioTense` = 40 %) :

| Taux | Lecture BudgetPilot |
|---|---|
| ≤ 30 % | 🟢 Confortable |
| ≤ 35 % | 🟡 À surveiller |
| ≤ 40 % | 🟠 Tendu |
| > 40 % | 🔴 Risque élevé |

**Ces seuils ne sont jamais présentés comme une règle d'acceptation bancaire ou une capacité
d'emprunt officielle** — chaque affichage du taux d'endettement le rappelle explicitement.
Les coûts mensuels supplémentaires du projet (assurance, entretien…) ne sont **jamais**
comptés dans le taux d'endettement : ce ne sont pas des dettes, ils pèsent uniquement sur le
reste à vivre.

### Jamais de double comptage Charge/Crédit

Une mensualité de crédit n'est jamais comptée deux fois. L'argent libre transmis au moteur
est déjà net des mensualités de crédit (elles apparaissent une seule fois, comme charge fixe
liée). Le taux d'endettement réutilise ces mêmes mensualités depuis le Crédit Manager, mais
dans un calcul séparé (rapportées au revenu, pas soustraites du reste à vivre une deuxième
fois) — testé explicitement (`test/domain/project_safety_service_test.dart`).

### Le chemin recommandé privilégie la sécurité

Depuis la V1.1, chaque scénario (`ProjectScenarioService`) recalcule aussi sa sécurité
financière, son taux d'endettement et son reste à vivre — pas seulement sa faisabilité. Le
chemin recommandé exclut désormais les scénarios dont la sécurité financière resterait faible
(`kMinRecommendedSafetyScore` = 60), même si l'un d'eux atteint un score de faisabilité plus
élevé : un projet n'est jamais recommandé uniquement parce qu'il "passe" mathématiquement.

### Multi-projets et priorité

Depuis la V1.1, BudgetPilot n'a plus jamais un seul projet à la fois : la page Projets
affiche tous les projets actifs, chacun indépendant (CRUD complet, archivage, duplication).
Chaque projet a une priorité utilisateur (Haute / Moyenne / Basse). Le projet mis en avant
sur l'accueil ("Projet prioritaire") est choisi dans cet ordre : priorité utilisateur, puis
faisabilité, puis date cible la plus proche — jamais un choix arbitraire, et jamais une
limitation à un seul projet dans l'application elle-même (uniquement sur la mise en avant de
l'accueil).

### Ce que le score n'est pas

Comme le score de faisabilité, le Financial Safety Score est une estimation interne à
BudgetPilot — jamais une décision bancaire, une capacité d'emprunt officielle ni un conseil
financier réglementé.
