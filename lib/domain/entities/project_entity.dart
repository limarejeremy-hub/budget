import '../../core/constants/app_constants.dart';

/// Entité pure — aucune dépendance à Drift. Montants en centimes.
///
/// Un projet ne stocke que ce que l'utilisateur a saisi (les INPUTS) :
/// jamais un score de faisabilité ou une trajectoire calculée, toujours
/// dérivés à la volée par `ProjectFeasibilityService` à partir des données
/// financières courantes — pour ne jamais afficher un résultat obsolète
/// après un changement de revenu, de charge ou de crédit.
class ProjectEntity {
  final int id;
  final String name;

  /// Une des valeurs de [ProjectCategory].
  final String category;

  /// Prix / budget cible du projet.
  final int targetAmountCents;

  /// Date souhaitée pour la réalisation du projet — facultative.
  final DateTime? desiredDate;

  /// Apport déjà disponible (épargne mobilisable dédiée à ce projet).
  final int availableContributionCents;

  /// Apport cible souhaité, si différent de l'apport disponible actuel —
  /// facultatif.
  final int? desiredContributionCents;

  /// Une des valeurs de [ProjectFinancingMode].
  final String financingMode;

  /// Mensualité maximale que l'utilisateur souhaite ne pas dépasser —
  /// facultative.
  final int? maxMonthlyPaymentCents;

  /// Durée de financement souhaitée, en mois — facultative.
  final int? desiredDurationMonths;

  /// Taux annuel estimé du financement, en % — facultatif.
  final double? estimatedRatePercent;

  /// Coûts mensuels supplémentaires induits par le projet une fois réalisé
  /// (ex : assurance, entretien, carburant pour un véhicule) — facultatifs,
  /// saisis comme un montant global par l'utilisateur.
  final int? extraMonthlyCostCents;

  final String? notes;

  /// `false` = projet archivé (toujours conservé, jamais supprimé
  /// silencieusement).
  final bool isActive;

  /// Une des valeurs de [ProjectPriority] — utilisée pour choisir le projet
  /// mis en avant sur la Home quand plusieurs projets sont actifs (V1.1).
  final String priority;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectEntity({
    required this.id,
    required this.name,
    required this.category,
    required this.targetAmountCents,
    this.desiredDate,
    this.availableContributionCents = 0,
    this.desiredContributionCents,
    required this.financingMode,
    this.maxMonthlyPaymentCents,
    this.desiredDurationMonths,
    this.estimatedRatePercent,
    this.extraMonthlyCostCents,
    this.notes,
    this.isActive = true,
    this.priority = ProjectPriority.medium,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Coûts mensuels supplémentaires, jamais `null` (0 par défaut) — pratique
  /// pour les calculs, qui ne doivent jamais tester la nullité séparément.
  int get effectiveExtraMonthlyCostCents => extraMonthlyCostCents ?? 0;

  bool get isCashOnly => financingMode == ProjectFinancingMode.cash;
}
