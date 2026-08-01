import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import 'dashboard_providers.dart';

/// Historique persistant des notifications déclenchées (V0.9) — source de
/// vérité du centre de notifications, indépendante de la permission
/// système et du bandeau Android.
final notificationLogsProvider = StreamProvider.autoDispose<List<NotificationLog>>((ref) {
  final repository = ref.watch(cycleRepositoryProvider);
  return repository.watchNotificationLogs();
});
