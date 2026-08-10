import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/widgets/euro_amount_field.dart';

void main() {
  group('EuroAmountField.parseCents', () {
    test('solde positif', () {
      expect(EuroAmountField.parseCents('250'), 25000);
    });

    test('zéro', () {
      expect(EuroAmountField.parseCents('0'), 0);
    });

    test('solde négatif entier', () {
      expect(EuroAmountField.parseCents('-180'), -18000);
    });

    test('solde négatif avec décimales', () {
      expect(EuroAmountField.parseCents('-1250.50'), -125050);
      expect(EuroAmountField.parseCents('-1250.5'), -125050);
    });

    test('virgule française (positive et négative)', () {
      expect(EuroAmountField.parseCents('250,75'), 25075);
      expect(EuroAmountField.parseCents('-1250,50'), -125050);
    });

    test('valeur invalide', () {
      expect(EuroAmountField.parseCents('abc'), isNull);
      expect(EuroAmountField.parseCents(''), isNull);
      expect(EuroAmountField.parseCents('12-34'), isNull);
    });
  });

  group('EuroAmountField widget — allowNegative (solde bancaire)', () {
    late TextEditingController controller;
    late GlobalKey<FormState> formKey;

    setUp(() {
      controller = TextEditingController();
      formKey = GlobalKey<FormState>();
    });

    Widget wrap() {
      return MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: EuroAmountField(
              controller: controller,
              label: 'Solde bancaire déclaré',
              required: false,
              allowNegative: true,
            ),
          ),
        ),
      );
    }

    testWidgets('solde positif : aucune erreur de validation', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.enterText(find.byType(TextFormField), '250');
      await tester.pump();

      expect(formKey.currentState!.validate(), isTrue);
      await tester.pump();
      expect(find.text('Le montant doit être supérieur à 0'), findsNothing);
      expect(find.text('Montant invalide'), findsNothing);
    });

    testWidgets('zéro : accepté, jamais rejeté comme "doit être supérieur à 0"', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.enterText(find.byType(TextFormField), '0');
      await tester.pump();

      expect(formKey.currentState!.validate(), isTrue);
      await tester.pump();
      expect(find.text('Le montant doit être supérieur à 0'), findsNothing);
    });

    testWidgets('solde négatif entier : accepté, le "-" reste tapable', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.enterText(find.byType(TextFormField), '-180');
      await tester.pump();

      expect(controller.text, '-180');
      expect(formKey.currentState!.validate(), isTrue);
      await tester.pump();
      expect(find.text('Le montant doit être supérieur à 0'), findsNothing);
      expect(EuroAmountField.parseCents(controller.text), -18000);
    });

    testWidgets('solde négatif avec décimales : accepté', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.enterText(find.byType(TextFormField), '-1250.50');
      await tester.pump();

      expect(formKey.currentState!.validate(), isTrue);
      expect(EuroAmountField.parseCents(controller.text), -125050);
    });

    testWidgets('virgule française sur un solde négatif : accepté', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.enterText(find.byType(TextFormField), '-1250,50');
      await tester.pump();

      expect(formKey.currentState!.validate(), isTrue);
      expect(EuroAmountField.parseCents(controller.text), -125050);
    });

    testWidgets(
        'valeur invalide : la création n\'est jamais bloquée silencieusement, une erreur claire '
        's\'affiche', (tester) async {
      await tester.pumpWidget(wrap());
      // Des lettres seraient filtrées par le clavier avant même d'atteindre
      // le contrôleur — un format numérique mal formé (deux points) est le
      // cas réaliste de "valeur invalide" pour ce champ.
      await tester.enterText(find.byType(TextFormField), '1.2.3');
      await tester.pump();

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Montant invalide'), findsOneWidget);
      expect(EuroAmountField.parseCents('1.2.3'), isNull);
    });
  });

  group('EuroAmountField widget — sans allowNegative (comportement inchangé)', () {
    testWidgets('un montant à 0 reste rejeté pour les autres champs (ex : apport, revenu)', (tester) async {
      final controller = TextEditingController();
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: EuroAmountField(controller: controller, label: 'Montant', required: false),
          ),
        ),
      ));

      await tester.enterText(find.byType(TextFormField), '0');
      await tester.pump();

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Le montant doit être supérieur à 0'), findsOneWidget);
    });
  });
}
