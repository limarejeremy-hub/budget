import '../../core/constants/app_constants.dart';

/// Détermine automatiquement le statut d'une charge fixe selon sa date prévue.
/// Ne s'applique qu'aux charges non confirmées manuellement : "prelevee" est
/// fixé par l'utilisateur (confirmation), tout comme "suspendue" et "incident"
/// qui restent des actions manuelles hors de ce service.
class ChargeStatusService {
  const ChargeStatusService();

  String computeStatus({
    required DateTime expectedDate,
    required bool isConfirmed,
    DateTime? now,
  }) {
    if (isConfirmed) return ChargeStatus.prelevee;

    final today = now ?? DateTime.now();
    final expectedDay = DateTime(expectedDate.year, expectedDate.month, expectedDate.day);
    final currentDay = DateTime(today.year, today.month, today.day);

    if (expectedDay.isAfter(currentDay)) return ChargeStatus.aVenir;
    if (expectedDay.isAtSameMomentAs(currentDay)) return ChargeStatus.aVerifierAujourdhui;
    return ChargeStatus.aConfirmer;
  }
}
