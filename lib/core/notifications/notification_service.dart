import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/local/cycle_repository.dart';
import '../../data/local/database.dart';
import '../../domain/entities/credit_entity.dart';
import '../../domain/entities/fixed_expense_entity.dart';
import '../constants/app_constants.dart';
import 'notification_content.dart';

/// Identifiants des actions disponibles directement depuis une notification
/// (sans ouvrir l'application) — V0.9, point 5.
class NotificationActionIds {
  NotificationActionIds._();
  static const confirm = 'confirm';
  static const remindLater = 'remind_later';
  static const ignoreToday = 'ignore_today';
}

/// Seuil (en centimes) au-delà duquel un prélèvement est considéré comme
/// "important" et déclenche un rappel une heure avant son échéance.
const int kImportantChargeThresholdCents = 5000;

const String _channelId = 'budgetpilot_default';
const String _channelName = 'BudgetPilot';
const String _channelDescription = 'Rappels de prélèvements et mises à jour de crédits';

/// Notifications locales de BudgetPilot — 100 % hors-ligne : aucun serveur,
/// aucun cloud. Chaque notification affichée est aussi journalisée dans
/// `NotificationLogs` (via [CycleRepository]), qui reste la source de
/// vérité du centre de notifications même si la permission système est
/// refusée ou si le bandeau Android a déjà disparu — l'application reste
/// pleinement utilisable sans cette permission.
class NotificationService {
  final CycleRepository repository;
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  NotificationService(this.repository, {FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName));
    } catch (_) {
      // Fuseau non résolu (ex : environnement de test) — reste sur UTC,
      // sans jamais faire planter l'initialisation.
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    try {
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) => handleNotificationAction(repository, response),
        onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
      );
    } catch (_) {
      // Plugin indisponible (web, tests) — l'app reste utilisable, le
      // centre de notifications continue de fonctionner via l'historique.
    }
    _initialized = true;
  }

  /// Demande la permission système (Android 13+, `POST_NOTIFICATIONS`) —
  /// jamais bloquant si elle est refusée.
  Future<bool> requestPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      final granted = await androidPlugin?.requestNotificationsPermission();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  NotificationDetails get _defaultDetails => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
        ),
      );

  NotificationDetails get _actionableDetails => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction(NotificationActionIds.confirm, 'Confirmer'),
            AndroidNotificationAction(NotificationActionIds.remindLater, 'Me rappeler dans 2h'),
            AndroidNotificationAction(NotificationActionIds.ignoreToday, 'Ignorer aujourd\'hui'),
          ],
        ),
      );

  Future<void> showMorningSummary(int count) async {
    final (title, body) = NotificationContent.morningSummary(count);
    await _showAndLog(id: 1, type: 'morning_summary', title: title, body: body);
  }

  Future<void> showBigChargeReminder(FixedExpenseEntity charge) async {
    final (title, body) = NotificationContent.bigChargeReminder(charge);
    await _showAndLog(
      id: 2000 + charge.id,
      type: 'big_charge_reminder',
      title: title,
      body: body,
      actionable: true,
      payload: 'charge:${charge.id}',
      relatedFixedExpenseId: charge.id,
    );
  }

  Future<void> showEveningReminder(int remainingCount) async {
    if (remainingCount <= 0) return;
    final (title, body) = NotificationContent.eveningReminder(remainingCount);
    await _showAndLog(id: 3, type: 'evening_reminder', title: title, body: body);
  }

  Future<void> showCreditFinished(CreditEntity credit) async {
    final (title, body) = NotificationContent.creditFinished(credit);
    await _showAndLog(
      id: 4000 + credit.id,
      type: 'credit_finished',
      title: title,
      body: body,
      relatedCreditId: credit.id,
    );
  }

  Future<void> showCreditAutoUpdated(CreditEntity credit) async {
    final (title, body) = NotificationContent.creditAutoUpdated(credit);
    await _showAndLog(
      id: 5000 + credit.id,
      type: 'credit_auto_updated',
      title: title,
      body: body,
      relatedCreditId: credit.id,
    );
  }

  /// Planifie les rappels quotidiens (résumé du matin 8h, bilan du soir
  /// 20h) et, pour chaque prélèvement important prévu aujourd'hui, un
  /// rappel une heure avant son échéance. Idempotent — ids stables par
  /// créneau/charge, peut être rappelé à chaque ouverture sans dupliquer.
  Future<void> scheduleDailyReminders({
    required List<FixedExpenseEntity> todayCharges,
    required int pendingCountToday,
  }) async {
    final morning = NotificationContent.morningSummary(pendingCountToday);
    await _scheduleDaily(id: 101, hour: 8, minute: 0, title: morning.$1, body: morning.$2);

    final evening = NotificationContent.eveningReminder(pendingCountToday);
    await _scheduleDaily(id: 102, hour: 20, minute: 0, title: evening.$1, body: evening.$2);

    for (final charge in todayCharges) {
      if (charge.effectiveAmountCents < kImportantChargeThresholdCents) continue;
      final reminderTime = charge.expectedDate.subtract(const Duration(hours: 1));
      if (reminderTime.isBefore(DateTime.now())) continue;
      final (title, body) = NotificationContent.bigChargeReminder(charge);
      await _scheduleOneOff(id: 2000 + charge.id, dateTime: reminderTime, title: title, body: body);
    }
  }

  Future<void> _showAndLog({
    required int id,
    required String type,
    required String title,
    required String body,
    bool actionable = false,
    String? payload,
    int? relatedFixedExpenseId,
    int? relatedCreditId,
  }) async {
    try {
      await _plugin.show(id, title, body, actionable ? _actionableDetails : _defaultDetails, payload: payload);
    } catch (_) {
      // Permission refusée ou plugin indisponible (tests, web) — l'entrée
      // est tout de même journalisée : l'historique reste la source de
      // vérité du centre de notifications.
    }
    await repository.logNotification(
      type: type,
      title: title,
      body: body,
      relatedFixedExpenseId: relatedFixedExpenseId,
      relatedCreditId: relatedCreditId,
    );
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        _defaultDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Environnement sans plugin natif (tests) ou permission refusée —
      // jamais bloquant.
    }
  }

  /// Annule les rappels programmés pour des charges qui n'appartiennent
  /// plus au cycle courant (finalisation du moteur de cycle, §15) : ces
  /// rappels deviennent obsolètes dès qu'un cycle est clôturé — y compris
  /// avant sa date de fin prévue (clôture manuelle anticipée), où certains
  /// pourraient encore être programmés dans le système. Les rappels
  /// quotidiens (résumé du matin, bilan du soir) ne sont jamais concernés :
  /// leurs ids stables (101/102) sont automatiquement remplacés dès le
  /// prochain [scheduleDailyReminders], sans action explicite ici.
  Future<void> cancelChargeReminders(Iterable<int> chargeIds) async {
    for (final id in chargeIds) {
      try {
        await _plugin.cancel(2000 + id);
      } catch (_) {
        // Environnement sans plugin natif (tests) — jamais bloquant.
      }
    }
  }

  Future<void> _scheduleOneOff({
    required int id,
    required DateTime dateTime,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(dateTime, tz.local),
        _actionableDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Idem : jamais bloquant.
    }
  }
}

/// Callback d'action de notification en arrière-plan — Android l'exécute
/// dans un isolate séparé, sans accès à l'état de l'application. Rouvre
/// donc sa propre connexion à la base plutôt que de dépendre d'un
/// [CycleRepository] existant.
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {
  // ignore: discarded_futures
  _handleBackgroundAction(response);
}

Future<void> _handleBackgroundAction(NotificationResponse response) async {
  final db = AppDatabase();
  try {
    await handleNotificationAction(CycleRepository(db), response);
  } finally {
    await db.close();
  }
}

/// Logique de traitement d'une action de notification, partagée entre le
/// callback premier plan et le callback arrière-plan : Confirmer / Me
/// rappeler dans 2h / Ignorer aujourd'hui (V0.9, point 5) — modifie
/// directement les données réelles, sans jamais nécessiter d'ouvrir l'app.
Future<void> handleNotificationAction(CycleRepository repository, NotificationResponse response) async {
  final payload = response.payload;
  if (payload == null || !payload.startsWith('charge:')) return;
  final chargeId = int.tryParse(payload.substring('charge:'.length));
  if (chargeId == null) return;

  switch (response.actionId) {
    case NotificationActionIds.confirm:
      await repository.confirmFixedExpense(chargeId);
    case NotificationActionIds.remindLater:
      await repository.postponeFixedExpense(chargeId, by: const Duration(hours: 2));
    case NotificationActionIds.ignoreToday:
      await repository.updateFixedExpenseStatus(chargeId, ChargeStatus.suspendue);
  }
}
