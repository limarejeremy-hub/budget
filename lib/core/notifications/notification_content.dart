import '../../domain/entities/credit_entity.dart';
import '../../domain/entities/fixed_expense_entity.dart';
import '../formatting/currency_formatter.dart';

/// Constructeurs de texte purs pour les notifications V0.9 — aucune
/// dépendance au plugin de notifications ni à Android, entièrement
/// testables.
class NotificationContent {
  const NotificationContent._();

  static (String title, String body) morningSummary(int count) {
    if (count <= 0) {
      return ("Aujourd'hui", "Aucune opération prévue aujourd'hui.");
    }
    final label = count > 1 ? 'opérations' : 'opération';
    return ("Aujourd'hui", 'Tu as $count $label aujourd\'hui.');
  }

  static (String title, String body) bigChargeReminder(FixedExpenseEntity charge) {
    return (charge.name, formatCentsAsEuro(charge.effectiveAmountCents));
  }

  static (String title, String body) eveningReminder(int remainingCount) {
    final label = remainingCount > 1 ? 'prélèvements' : 'prélèvement';
    return ('À confirmer', 'Il reste encore $remainingCount $label à confirmer.');
  }

  static (String title, String body) creditFinished(CreditEntity credit) {
    return (
      '🎉 Bravo !',
      'Tu viens de récupérer ${formatCentsAsEuro(credit.monthlyPaymentCents)}/mois '
          '(crédit "${credit.name}" terminé).',
    );
  }

  static (String title, String body) creditAutoUpdated(CreditEntity credit) {
    final n = credit.remainingInstallments;
    return (
      'Crédit mis à jour',
      'Le crédit ${credit.name} vient de passer à $n mensualité${n > 1 ? 's' : ''} '
          'restante${n > 1 ? 's' : ''}.',
    );
  }
}
