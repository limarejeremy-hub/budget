import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/core/formatting/currency_formatter.dart';
import 'package:budgetpilot/core/providers/dashboard_providers.dart';
import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/domain/entities/fixed_expense_entity.dart';
import 'package:budgetpilot/domain/entities/income_entity.dart';
import 'package:budgetpilot/domain/models/dashboard_view_data.dart';
import 'package:budgetpilot/features/dashboard/dashboard_page.dart';

// Carte Crédits du tableau de bord : watch un provider indépendant du
// cycle (base de données réelle) — une base en mémoire est donc fournie à
// chaque test pour éviter tout accès à path_provider (indisponible en test).
late AppDatabase _db;

Widget _wrap(Widget child, List<Override> overrides) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWith((ref) => _db), ...overrides],
    child: MaterialApp(home: child),
  );
}

DashboardViewData _sampleData({
  double remainingRatio = 0.24,
  List<FixedExpenseEntity> upcomingCharges = const [],
}) {
  return DashboardViewData(
    cycleId: 1,
    cycleStart: DateTime(2026, 7, 27),
    cycleEnd: DateTime(2026, 8, 26),
    totalIncomeCents: 515000,
    totalFixedExpensesCents: 245000,
    totalVariableExpensesCents: 67700,
    totalSavingsCents: 80000,
    realRemainingCents: 122300,
    remainingRatio: remainingRatio,
    unconfirmedChargesCount: upcomingCharges.length,
    unconfirmedChargesTotalCents: 61200,
    upcomingCharges: upcomingCharges,
  );
}

Future<void> _pumpDashboard(WidgetTester tester, DashboardViewData data) async {
  // Viewport haut pour que tout le contenu du tableau de bord (désormais
  // enrichi de "Aujourd'hui", "Cette semaine" et "Résumé rapide") soit
  // construit sans dépendre du défilement dans les tests.
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(_wrap(
    const DashboardPage(),
    [dashboardProvider.overrideWith((ref) => Stream.value(data))],
  ));
  await tester.pump();
  // La carte Crédits watch un vrai provider (base en mémoire) dont la
  // première valeur arrive après un `await` réel — contrairement à
  // `dashboardProvider` ici substitué par un Stream.value synchrone, il
  // faut donc une frame supplémentaire pour qu'elle sorte de son état de
  // chargement initial.
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  setUp(() {
    _db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => _db.close());

  group('Carte Argent Libre', () {
    testWidgets('affiche le libellé et le montant formaté', (tester) async {
      final data = _sampleData();
      await _pumpDashboard(tester, data);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      expect(find.text('ARGENT LIBRE'), findsOneWidget);
      expect(find.text(formatCentsAsEuro(data.realRemainingCents)), findsOneWidget);
      expect(find.textContaining("Disponible jusqu'au"), findsOneWidget);
    });

    testWidgets('badge vert "Situation confortable" quand le ratio est confortable',
        (tester) async {
      await _pumpDashboard(tester, _sampleData(remainingRatio: 0.30));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      expect(find.text('Situation confortable'), findsOneWidget);
    });

    testWidgets('badge orange "À surveiller" quand le ratio est intermédiaire', (tester) async {
      await _pumpDashboard(tester, _sampleData(remainingRatio: 0.10));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      expect(find.text('À surveiller'), findsOneWidget);
    });

    testWidgets('badge rouge "Budget serré" quand le ratio est faible', (tester) async {
      await _pumpDashboard(tester, _sampleData(remainingRatio: 0.02));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      expect(find.text('Budget serré'), findsOneWidget);
    });
  });

  group('Résumé du cycle', () {
    testWidgets('affiche les quatre cartes avec libellé et montant', (tester) async {
      final data = _sampleData();
      await _pumpDashboard(tester, data);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      expect(find.text('Résumé du cycle'), findsOneWidget);

      expect(find.text('Revenus'), findsOneWidget);
      expect(find.text(formatCentsAsEuro(data.totalIncomeCents)), findsOneWidget);

      expect(find.text('Charges'), findsOneWidget);
      expect(find.text(formatCentsAsEuro(data.totalFixedExpensesCents)), findsOneWidget);

      expect(find.text('Dépenses'), findsOneWidget);
      expect(find.text(formatCentsAsEuro(data.totalVariableExpensesCents)), findsOneWidget);

      expect(find.text('Épargnes'), findsOneWidget);
      expect(find.text(formatCentsAsEuro(data.totalSavingsCents)), findsOneWidget);
    });

    testWidgets('affiche un décompte par catégorie, jamais un pourcentage', (tester) async {
      final data = DashboardViewData(
        cycleId: 1,
        cycleStart: DateTime(2026, 7, 27),
        cycleEnd: DateTime(2026, 8, 26),
        totalIncomeCents: 420000,
        totalFixedExpensesCents: 7000,
        totalVariableExpensesCents: 1500,
        totalSavingsCents: 2000,
        realRemainingCents: 122300,
        remainingRatio: 0.24,
        unconfirmedChargesCount: 0,
        unconfirmedChargesTotalCents: 0,
        incomesCount: 1,
        fixedExpensesCount: 3,
        variableExpensesCount: 2,
        savingsCount: 1,
      );
      await _pumpDashboard(tester, data);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      expect(find.text('1 revenu'), findsOneWidget);
      expect(find.text('3 prélèvements'), findsOneWidget);
      expect(find.text('2 dépenses'), findsOneWidget);
      expect(find.text('1 épargne'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });
  });

  group('Cette semaine', () {
    testWidgets("affiche une version compacte quand rien n'est prévu", (tester) async {
      await _pumpDashboard(tester, _sampleData());
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      expect(find.text('Aucune opération prévue cette semaine'), findsOneWidget);
      // Pas la grande carte avec en-tête : version compacte, une seule ligne.
      expect(find.byIcon(Icons.view_week_rounded), findsNothing);
    });

    testWidgets('affiche les opérations planifiées dans les 7 prochains jours', (tester) async {
      final data = DashboardViewData(
        cycleId: 1,
        cycleStart: DateTime(2026, 7, 27),
        cycleEnd: DateTime(2026, 8, 26),
        totalIncomeCents: 515000,
        totalFixedExpensesCents: 245000,
        totalVariableExpensesCents: 67700,
        totalSavingsCents: 80000,
        realRemainingCents: 122300,
        remainingRatio: 0.24,
        unconfirmedChargesCount: 0,
        unconfirmedChargesTotalCents: 0,
        thisWeekFixedExpenses: [
          FixedExpenseEntity(
            id: 5,
            cycleId: 1,
            name: 'Abonnement box',
            expectedAmountCents: 3990,
            expectedDate: DateTime(2026, 8, 2),
          ),
        ],
      );
      await _pumpDashboard(tester, data);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      expect(find.text('Cette semaine'), findsOneWidget);
      expect(find.byIcon(Icons.view_week_rounded), findsOneWidget);
      expect(find.text('Abonnement box'), findsOneWidget);
    });
  });

  group('Prochaines échéances', () {
    testWidgets('affiche les charges à venir avec nom, date et montant', (tester) async {
      final charges = [
        FixedExpenseEntity(
          id: 1,
          cycleId: 1,
          name: 'Crédit maison',
          expectedAmountCents: 85000,
          expectedDate: DateTime(2026, 8, 3),
          status: ChargeStatus.aVenir,
        ),
        FixedExpenseEntity(
          id: 2,
          cycleId: 1,
          name: 'Électricité',
          expectedAmountCents: 18000,
          expectedDate: DateTime(2026, 8, 10),
          status: ChargeStatus.aConfirmer,
        ),
      ];
      await _pumpDashboard(tester, _sampleData(upcomingCharges: charges));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      expect(find.text('Prochaines échéances'), findsOneWidget);
      expect(find.text('Voir toutes'), findsOneWidget);
      expect(find.text('Crédit maison'), findsOneWidget);
      expect(find.text(formatCentsAsEuro(85000)), findsOneWidget);
      expect(find.text('Électricité'), findsOneWidget);
      expect(find.text(formatCentsAsEuro(18000)), findsOneWidget);
    });

    testWidgets('affiche un état vide quand aucune échéance', (tester) async {
      await _pumpDashboard(tester, _sampleData(upcomingCharges: const []));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      expect(find.text('Prochaines échéances'), findsOneWidget);
      expect(find.text('Aucune échéance à venir'), findsOneWidget);
    });
  });

  group("Aujourd'hui", () {
    testWidgets("affiche l'état vide quand aucune opération n'a lieu aujourd'hui", (tester) async {
      await _pumpDashboard(tester, _sampleData());
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      expect(find.text("Aujourd'hui"), findsOneWidget);
      expect(find.text('Aucune opération aujourd\'hui'), findsOneWidget);
    });

    testWidgets('affiche les prélèvements, revenus et alertes du jour', (tester) async {
      final data = DashboardViewData(
        cycleId: 1,
        cycleStart: DateTime(2026, 7, 27),
        cycleEnd: DateTime(2026, 8, 26),
        totalIncomeCents: 515000,
        totalFixedExpensesCents: 245000,
        totalVariableExpensesCents: 67700,
        totalSavingsCents: 80000,
        realRemainingCents: 122300,
        remainingRatio: 0.24,
        unconfirmedChargesCount: 0,
        unconfirmedChargesTotalCents: 0,
        todayFixedExpenses: [
          FixedExpenseEntity(
            id: 1,
            cycleId: 1,
            name: 'Internet',
            expectedAmountCents: 12000,
            expectedDate: DateTime(2026, 8, 5),
          ),
        ],
        todayIncomes: [
          IncomeEntity(id: 1, cycleId: 1, name: 'Salaire', expectedAmountCents: 245000, expectedDate: DateTime(2026, 8, 5)),
        ],
        alerts: [
          FixedExpenseEntity(
            id: 2,
            cycleId: 1,
            name: 'Assurance',
            expectedAmountCents: 8000,
            expectedDate: DateTime(2026, 7, 20),
            status: ChargeStatus.aConfirmer,
          ),
        ],
      );
      await _pumpDashboard(tester, data);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      expect(find.text('Internet'), findsOneWidget);
      expect(find.text('Salaire'), findsOneWidget);
      expect(find.textContaining('Assurance'), findsOneWidget);
    });

    testWidgets('affiche un badge avec le nombre d\'opérations en attente de confirmation (V0.9)',
        (tester) async {
      final data = DashboardViewData(
        cycleId: 1,
        cycleStart: DateTime(2026, 7, 27),
        cycleEnd: DateTime(2026, 8, 26),
        totalIncomeCents: 515000,
        totalFixedExpensesCents: 245000,
        totalVariableExpensesCents: 67700,
        totalSavingsCents: 80000,
        realRemainingCents: 122300,
        remainingRatio: 0.24,
        unconfirmedChargesCount: 0,
        unconfirmedChargesTotalCents: 0,
        todayFixedExpenses: [
          FixedExpenseEntity(
            id: 1,
            cycleId: 1,
            name: 'Internet',
            expectedAmountCents: 12000,
            expectedDate: DateTime(2026, 8, 5),
          ),
        ],
        alerts: [
          FixedExpenseEntity(
            id: 2,
            cycleId: 1,
            name: 'Assurance',
            expectedAmountCents: 8000,
            expectedDate: DateTime(2026, 7, 20),
            status: ChargeStatus.aConfirmer,
          ),
        ],
      );
      await _pumpDashboard(tester, data);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('un tap sur la carte "Aujourd\'hui" ouvre le centre de confirmations (V0.9)',
        (tester) async {
      await _pumpDashboard(tester, _sampleData());
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.tap(find.text("Aujourd'hui"));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Confirmations'), findsOneWidget);
    });
  });

  group('Progression du cycle', () {
    testWidgets('affiche le nombre de jours restants et "Jour X / Y"', (tester) async {
      await _pumpDashboard(tester, _sampleData());
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      expect(find.textContaining('dans ce cycle'), findsOneWidget);
      expect(find.textContaining('Jour '), findsOneWidget);
    });
  });

  group('Carte Crédits', () {
    testWidgets("affiche 'Aucun crédit en cours' quand la base est vide", (tester) async {
      await _pumpDashboard(tester, _sampleData());
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      expect(find.text('Crédits'), findsOneWidget);
      expect(find.text('Aucun crédit en cours'), findsOneWidget);
    });
  });
}
