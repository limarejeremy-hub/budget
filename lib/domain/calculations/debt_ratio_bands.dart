/// -----------------------------------------------------------------------
/// Lecture BudgetPilot du taux d'endettement — repères internes,
/// centralisés et documentés, **jamais** présentés comme une règle
/// d'acceptation bancaire. Seule source utilisée par tous les écrans
/// (Accueil, Crédits, Projets, Simulations, Scénarios) qui affichent une
/// couleur ou un libellé pour un taux d'endettement.
/// -----------------------------------------------------------------------
const double kDebtRatioComfortable = 0.30; // <= : 🟢 confortable
const double kDebtRatioWatch = 0.35; // <= : 🟡 à surveiller
const double kDebtRatioTense = 0.40; // <= : 🟠 tendu
// > kDebtRatioTense : 🔴 risque élevé

enum DebtRatioBand { comfortable, watch, tense, high }

DebtRatioBand debtRatioBandFor(double ratio) {
  if (ratio <= kDebtRatioComfortable) return DebtRatioBand.comfortable;
  if (ratio <= kDebtRatioWatch) return DebtRatioBand.watch;
  if (ratio <= kDebtRatioTense) return DebtRatioBand.tense;
  return DebtRatioBand.high;
}

String debtRatioBandLabel(DebtRatioBand band) {
  switch (band) {
    case DebtRatioBand.comfortable:
      return 'Confortable';
    case DebtRatioBand.watch:
      return 'À surveiller';
    case DebtRatioBand.tense:
      return 'Tendu';
    case DebtRatioBand.high:
      return 'Risque élevé';
  }
}

String debtRatioBandEmoji(DebtRatioBand band) {
  switch (band) {
    case DebtRatioBand.comfortable:
      return '🟢';
    case DebtRatioBand.watch:
      return '🟡';
    case DebtRatioBand.tense:
      return '🟠';
    case DebtRatioBand.high:
      return '🔴';
  }
}
