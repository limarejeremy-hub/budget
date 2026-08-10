import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/calculations/pending_confirmations.dart';
import '../../domain/models/dashboard_view_data.dart';
import '../../features/charges/charges_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/expenses/variable_expenses_page.dart';
import '../../features/history/history_page.dart';
import '../../features/settings/settings_page.dart';
import '../providers/dashboard_providers.dart';
import '../providers/shell_providers.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    // Notifications locales (V0.9) : initialisation + permission + rappels
    // du jour. Ne bloque jamais l'affichage de l'app (voir NotificationService
    // — chaque étape échoue silencieusement si le plugin ou la permission
    // n'est pas disponible, ex. web ou tests).
    Future.microtask(_initNotifications);
  }

  Future<void> _initNotifications() async {
    final service = ref.read(notificationServiceProvider);
    await service.initialize();
    await service.requestPermission();

    ref.listenManual<AsyncValue<DashboardViewData?>>(dashboardProvider, (previous, next) {
      final data = next.valueOrNull;
      if (data == null) return;
      final pendingCount = pendingConfirmations(data).length;
      // ignore: discarded_futures
      service.scheduleDailyReminders(todayCharges: data.todayFixedExpenses, pendingCountToday: pendingCount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(shellTabIndexProvider);
    const pages = [
      DashboardPage(),
      ChargesPage(),
      VariableExpensesPage(),
      HistoryPage(),
      SettingsPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => ref.read(shellTabIndexProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Charges'),
          NavigationDestination(
              icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: 'Dépenses'),
          NavigationDestination(icon: Icon(Icons.history), selectedIcon: Icon(Icons.history), label: 'Historique'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Paramètres'),
        ],
      ),
    );
  }
}
