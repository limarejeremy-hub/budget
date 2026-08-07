class AppConstants {
  AppConstants._();

  static const String appName = 'BudgetPilot';
  static const String defaultCurrency = 'EUR';
  static const String defaultLocale = 'fr_FR';

  /// Jour du mois qui démarre un nouveau cycle (27 par défaut).
  static const int defaultCycleStartDay = 27;
}

/// Statuts possibles pour un revenu.
class IncomeStatus {
  IncomeStatus._();
  static const String prevu = 'prevu';
  static const String recu = 'recu';
  static const String partiellementRecu = 'partiellement_recu';
  static const String annule = 'annule';
}

/// Statuts possibles pour une charge fixe.
class ChargeStatus {
  ChargeStatus._();
  static const String aVenir = 'a_venir';
  static const String aVerifierAujourdhui = 'a_verifier_aujourdhui';
  static const String aConfirmer = 'a_confirmer';
  static const String prelevee = 'prelevee';
  static const String suspendue = 'suspendue';
  static const String incident = 'incident';
}

/// Statuts possibles pour une épargne.
class SavingStatus {
  SavingStatus._();
  static const String prevu = 'prevu';
  static const String effectue = 'effectue';
  static const String annule = 'annule';
  static const String suspendue = 'suspendue';
}

/// Types d'entité pour les catégories et templates récurrents.
class EntityType {
  EntityType._();
  static const String income = 'income';
  static const String fixedExpense = 'fixed_expense';
  static const String variableExpense = 'variable_expense';
  static const String saving = 'saving';
}

/// Catégories possibles pour un projet (V1.0 — Project Planner).
class ProjectCategory {
  ProjectCategory._();
  static const String car = 'voiture';
  static const String renovation = 'travaux';
  static const String realEstate = 'immobilier';
  static const String travel = 'voyage';
  static const String wedding = 'mariage';
  static const String bigPurchase = 'gros_achat';
  static const String other = 'autre';

  static const List<String> all = [
    car,
    renovation,
    realEstate,
    travel,
    wedding,
    bigPurchase,
    other,
  ];
}

/// Mode de financement envisagé pour un projet.
class ProjectFinancingMode {
  ProjectFinancingMode._();
  static const String cash = 'comptant';
  static const String financed = 'financement';
  static const String mixed = 'mixte';
  static const String undetermined = 'indetermine';

  static const List<String> all = [cash, financed, mixed, undetermined];
}
