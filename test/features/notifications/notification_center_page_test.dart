import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:budgetpilot/core/providers/database_provider.dart';
import 'package:budgetpilot/data/local/cycle_repository.dart';
import 'package:budgetpilot/data/local/database.dart';
import 'package:budgetpilot/features/notifications/notification_center_page.dart';

// Le centre de notifications (V0.9) affiche l'historique persistant des
// notifications journalisées par NotificationService — indépendant de la
// permission système, donc testable via de simples entrées insérées par
// CycleRepository.logNotification.
late AppDatabase _db;
late CycleRepository _repository;

Widget _wrap() {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWith((ref) => _db)],
    child: const MaterialApp(home: NotificationCenterPage()),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  setUp(() {
    _db = AppDatabase.forTesting(NativeDatabase.memory());
    _repository = CycleRepository(_db);
  });

  tearDown(() => _db.close());

  testWidgets("affiche l'état vide quand aucune notification n'a été journalisée", (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Aucune notification'), findsOneWidget);
  });

  testWidgets('affiche les notifications journalisées, les plus récentes en premier', (tester) async {
    await _repository.logNotification(
      type: 'morning_summary',
      title: 'Bonjour',
      body: 'Tu as 3 opérations aujourd\'hui.',
    );
    await _repository.logNotification(
      type: 'credit_finished',
      title: 'Crédit Auto',
      body: '🎉 Bravo ! Tu viens de récupérer 275 €/mois.',
    );

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Bonjour'), findsOneWidget);
    expect(find.text('Crédit Auto'), findsOneWidget);
    expect(find.text('🎉 Bravo ! Tu viens de récupérer 275 €/mois.'), findsOneWidget);

    // La plus récente (insérée en second) apparaît en premier dans la liste.
    final creditFinishedPosition = tester.getTopLeft(find.text('Crédit Auto')).dy;
    final morningPosition = tester.getTopLeft(find.text('Bonjour')).dy;
    expect(creditFinishedPosition, lessThan(morningPosition));
  });

  testWidgets('associe une icône distincte à chaque type de notification', (tester) async {
    await _repository.logNotification(type: 'credit_finished', title: 'Crédit Auto', body: 'Terminé');
    await _repository.logNotification(
        type: 'credit_auto_updated', title: 'Crédit Maison', body: 'Mise à jour');
    await _repository.logNotification(type: 'big_charge_reminder', title: 'Orange', body: '70 €');
    await _repository.logNotification(type: 'evening_reminder', title: 'Ce soir', body: 'Il reste 2');

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.celebration_rounded), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_rounded), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
  });
}
