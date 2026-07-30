import 'package:flutter_test/flutter_test.dart';

import 'package:budgetpilot/core/constants/app_constants.dart';
import 'package:budgetpilot/domain/calculations/charge_status_service.dart';

void main() {
  const service = ChargeStatusService();
  final now = DateTime(2026, 8, 15);

  test('date future => a_venir', () {
    final status = service.computeStatus(
      expectedDate: DateTime(2026, 8, 20),
      isConfirmed: false,
      now: now,
    );
    expect(status, ChargeStatus.aVenir);
  });

  test('date du jour => a_verifier_aujourdhui', () {
    final status = service.computeStatus(
      expectedDate: DateTime(2026, 8, 15),
      isConfirmed: false,
      now: now,
    );
    expect(status, ChargeStatus.aVerifierAujourdhui);
  });

  test('date dépassée sans confirmation => a_confirmer', () {
    final status = service.computeStatus(
      expectedDate: DateTime(2026, 8, 10),
      isConfirmed: false,
      now: now,
    );
    expect(status, ChargeStatus.aConfirmer);
  });

  test('confirmée manuellement => prelevee, quelle que soit la date', () {
    final status = service.computeStatus(
      expectedDate: DateTime(2026, 8, 10),
      isConfirmed: true,
      now: now,
    );
    expect(status, ChargeStatus.prelevee);
  });
}
