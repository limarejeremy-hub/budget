# Conservation des données — BudgetPilot

Ce document explique précisément dans quels cas les données locales de
BudgetPilot (cycles, revenus, charges fixes, dépenses variables, épargnes,
crédits) sont conservées d'une version de l'app à l'autre, dans quels cas
elles peuvent être perdues, et pourquoi.

## Où sont stockées les données

Toutes les données sont dans une seule base SQLite locale, gérée par Drift :
fichier `budgetpilot.sqlite`, dans le répertoire "Documents" applicatif
d'Android (`getApplicationDocumentsDirectory()`, généralement
`/data/data/com.budgetpilot.app/app_flutter/`). Ce répertoire appartient
exclusivement à l'application, identifiée par son `applicationId`
(`com.budgetpilot.app`).

Il n'y a **aucune synchronisation cloud** : la seule copie des données est ce
fichier, sur l'appareil. C'est pourquoi la fonction de sauvegarde manuelle
(export/import JSON, dans Paramètres) est le filet de sécurité recommandé.

## ✅ Les données SONT conservées quand…

- **Vous installez une mise à jour de l'APK par-dessus l'application
  existante** (`adb install -r`, ou en ouvrant un nouvel APK depuis l'appareil
  alors que BudgetPilot est déjà installé), **à condition que** :
  1. le nouvel APK a le **même `applicationId`** (`com.budgetpilot.app`,
     jamais modifié) ;
  2. le nouvel APK est signé avec la **même clé de signature** (voir
     `android/app/build.gradle` et la section Signature ci-dessous).

  Dans ce cas, Android traite l'installation comme une **mise à jour** : le
  répertoire de données de l'app (et donc `budgetpilot.sqlite`) n'est **jamais
  touché**. C'est le comportement standard d'Android, pas une garantie ajoutée
  par le code de l'app — mais l'app ne fait rien qui pourrait le compromettre
  (voir la liste des garanties de code ci-dessous).
- L'application redémarre normalement (crash, mise en arrière-plan, reboot du
  téléphone) : le fichier SQLite est rouvert tel quel, rien n'est recréé ni
  vidé au démarrage (`lib/main.dart` n'appelle jamais de seed ou de purge
  automatique).
- Une mise à jour introduit un changement de schéma de base de données
  (nouvelle colonne, nouvelle table) : Drift exécute une **migration
  incrémentale** (`AppDatabase.migration`, `onUpgrade`) qui modifie le schéma
  en place, sans jamais supprimer ni recréer les tables existantes. Testé par
  `test/data/migration_test.dart`.

### Garanties de code (vérifiées par les tests)

- Aucun appel à `destructiveMigration` — la stratégie de migration Drift
  (`AppDatabase.migration`) n'utilise que `onCreate` (première installation)
  et `onUpgrade` avec des étapes additives (`addColumn`, jamais de `DROP
  TABLE`/`DELETE` implicite).
- Aucune suppression ou réinitialisation automatique de la base au démarrage.
  Le seed de données de démonstration (`DemoDataSeeder`) n'est **jamais**
  appelé automatiquement — uniquement depuis le menu développeur caché de
  Paramètres (7 appuis sur le numéro de version), qui n'est pas dans le
  parcours normal.
- Le nom de fichier SQLite (`budgetpilot.sqlite`) et son emplacement
  (répertoire "Documents" applicatif) ne changent jamais entre les versions.
- `test/data/persistence_test.dart` vérifie qu'une base fermée puis rouverte
  (même fichier) conserve intégralement un cycle, un revenu et une charge.
- `test/data/migration_test.dart` vérifie qu'une base simulant le schéma v1
  (avant l'ajout de la colonne `BudgetCycles.name`) migre vers le schéma
  actuel sans perdre aucune donnée existante.
- `test/data/credit_migration_test.dart` vérifie qu'une base simulant le
  schéma v2 (avant l'ajout de la table `Credits`) migre vers le schéma
  courant sans perdre aucune donnée existante, qu'une base simulant le
  schéma v3 (avant l'ajout des colonnes organisme/couleur/icône) migre vers
  v4 sans perdre les crédits déjà enregistrés, et qu'une base simulant le
  schéma v4 (avant le jour de prélèvement, l'assurance, le lien
  charge ↔ crédit et l'historique de notifications) migre vers v5 en
  **reliant automatiquement** les charges "Crédit" existantes au crédit
  correspondant (voir « Fusion Charges/Crédits (V0.9) » ci-dessous).

### Fusion Charges/Crédits (V0.9)

Depuis la V0.9, un crédit est la **source de vérité unique** de sa
mensualité : créer un crédit génère automatiquement sa charge fixe dans le
cycle en cours (catégorie « Crédit »), la modifier met à jour la charge non
encore confirmée, et le supprimer supprime toutes ses charges liées — sans
jamais dupliquer ni exiger de double saisie.

- **Schéma v4 → v5** (`AppDatabase.schemaVersion = 5`) ajoute, de façon
  strictement additive :
  - `Credits.paymentDayOfMonth` et `Credits.insuranceCents` (nullable) ;
  - `FixedExpenses.linkedCreditId` (nullable, référence `Credits.id`) — le
    lien charge ↔ crédit ;
  - la table `NotificationLogs` (historique persistant des notifications,
    voir plus bas).
- **Comptes existants (compatibilité ascendante)** : au moment de la
  migration, une fonction de réconciliation (`reconcileCreditLinkedCharges`)
  relie automatiquement chaque charge fixe de catégorie « Crédit » sans
  lien à un crédit existant du même nom (comparaison insensible à la casse
  et aux espaces). Aucun crédit ni aucune charge n'a besoin d'être ressaisi.
  La même fonction est réutilisée à la fin de **l'import de sauvegarde**
  (les identifiants de crédit ne sont pas stables d'un appareil à l'autre,
  donc `linkedCreditId` n'est jamais exporté tel quel — la réconciliation
  par nom reconstruit le lien après import).
- Une charge déjà **confirmée** (prélevée) n'est plus jamais réécrite par la
  synchronisation automatique — seul l'historique futur (charges à venir ou
  à confirmer) suit les modifications du crédit.

## Historique des notifications (V0.9)

BudgetPilot fonctionne à 100 % hors-ligne : les rappels (résumé du matin,
prélèvement important, bilan du soir, crédit terminé, mensualité mise à
jour) sont des notifications **locales** (`flutter_local_notifications`),
sans aucun serveur ni compte. Chaque notification affichée est aussi
journalisée dans la table `NotificationLogs`, qui reste la source de vérité
du centre de notifications même si la permission système est refusée ou si
le bandeau Android a déjà disparu. Cette table n'est **pas** incluse dans
l'export/import de sauvegarde : c'est un historique local, régénéré au fil
de l'usage de l'app, pas une donnée financière à transférer d'un appareil à
l'autre.

## ❌ Les données PEUVENT être perdues quand…

1. **Désinstallation de l'application** (manuelle, ou automatique si Android
   exige une désinstallation avant réinstallation — voir point 2). C'est un
   comportement du système Android, pas de l'app : à la désinstallation,
   Android supprime le répertoire de données privé de l'app (`applicationId`)
   pour éviter qu'une donnée périmée ou sensible ne soit lue par une future
   application réutilisant le même nom de package. Aucune application ne peut
   contourner ce comportement du système.
2. **Changement de clé de signature entre deux APK.** Android refuse
   d'installer un APK signé avec une clé différente par-dessus une
   installation existante du même `applicationId`
   (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). Le seul moyen de continuer est de
   désinstaller l'ancienne version — ce qui déclenche la perte décrite au
   point 1. **C'est pourquoi ce projet utilise désormais un keystore de
   release dédié et stable** (voir ci-dessous) plutôt que la clé debug, qui
   changeait potentiellement à chaque build CI.
3. **Changement d'`applicationId`.** Android considère un `applicationId`
   différent comme une application totalement différente : aucune donnée
   n'est partagée. Ne jamais changer `applicationId` dans
   `android/app/build.gradle` sans une stratégie de migration explicite (hors
   périmètre actuel).
4. **Effacement manuel du stockage de l'app** via
   Paramètres Android → Applications → BudgetPilot → Stockage → « Effacer les
   données » (ou « Effacer le cache » ne touche pas la base, mais « Effacer
   les données » oui).
5. **Réinitialisation d'usine de l'appareil**, perte/vol de l'appareil, ou
   remplacement de l'appareil sans transfert de données.
6. **Bug de migration non couvert par les tests actuels** : les tests de
   persistance/migration présents couvrent la migration v1 → v2 connue au
   moment de l'écriture, mais ne peuvent pas prouver l'absence de bug sur une
   future migration qui n'existe pas encore. Toute nouvelle migration doit
   ajouter son propre test avant d'être livrée (voir « Ajouter une future
   migration » ci-dessous).

Dans tous ces cas, la seule protection est une **sauvegarde manuelle**
récente (Paramètres → Exporter une sauvegarde), à réimporter après
réinstallation.

## Stratégie de signature des APK

- `android/app/build.gradle` signe les builds release avec la configuration
  `android/key.properties` **si ce fichier existe** (jamais commité — voir
  `.gitignore`). Ce fichier référence un keystore dédié
  (`android/app/release.jks`, également jamais commité).
- En CI (GitHub Actions), ce fichier est généré à la volée à partir de 4
  secrets du dépôt (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
  `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`), puis supprimé avec le
  runner éphémère à la fin du job. La clé privée n'est donc jamais présente
  dans le dépôt Git ni dans les logs de build.
- **Tant que ces secrets ne sont pas configurés sur le dépôt**, le build
  retombe automatiquement sur la clé **debug** générée par l'outillage
  Android — ce qui permet au projet de continuer à compiler, mais **ne
  garantit pas une signature stable d'un build CI à l'autre** (chaque
  runner GitHub Actions est une machine neuve, sans keystore debug
  préexistant). Configurez les 4 secrets pour obtenir la garantie de
  signature stable décrite dans ce document.

## Sauvegarde manuelle (export / import)

Paramètres → Sauvegarde :

- **Exporter une sauvegarde** : génère un fichier JSON local (cycles,
  revenus, charges fixes, dépenses variables, épargnes, **crédits** —
  aucune donnée bancaire sensible comme des identifiants ou des IBAN) et
  laisse l'utilisateur choisir où l'enregistrer.
- **Importer une sauvegarde** : sélectionne un fichier JSON, le valide
  (format et champs obligatoires) avant toute écriture, puis demande
  confirmation pour **fusionner** (ajouter les cycles et crédits importés
  aux données actuelles) ou **remplacer** (supprimer les données actuelles
  avant d'importer, crédits compris). L'import est transactionnel : en cas
  d'erreur, aucune donnée n'est modifiée.
- **Compatibilité ascendante** : une sauvegarde exportée par une version de
  BudgetPilot antérieure à la V0.7 (sans champ `credits`) s'importe
  normalement — le champ est simplement absent, traité comme une liste
  vide, sans erreur. Testé par `test/data/backup_test.dart`.

Aucun envoi vers un service cloud n'est effectué — le fichier reste local
jusqu'à ce que l'utilisateur choisisse de le déplacer lui-même.

## Ajouter une future migration

1. Ajouter la nouvelle colonne/table dans `lib/data/local/database.dart`.
2. Incrémenter `AppDatabase.schemaVersion`.
3. Ajouter une branche `if (from < N) { ... }` dans
   `AppDatabase.migration.onUpgrade`, avec des opérations additives
   uniquement (`addColumn`, nouvelle table via `m.createTable`, etc.) —
   jamais de suppression de données existantes.
4. Ajouter un test de migration dédié (sur le modèle de
   `test/data/migration_test.dart`) qui simule l'ancien schéma, exécute la
   migration, et vérifie qu'aucune donnée n'est perdue.
5. Mettre à jour la version attendue dans
   `test/data/persistence_test.dart` (`la version de schéma Drift actuelle...`).
