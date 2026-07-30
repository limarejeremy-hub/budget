import 'package:flutter/material.dart';

import '../../features/charges/charges_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/expenses/variable_expenses_page.dart';
import '../../features/history/history_page.dart';
import '../../features/settings/settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [
      DashboardPage(),
      ChargesPage(),
      VariableExpensesPage(),
      HistoryPage(),
      SettingsPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Charges'),
          NavigationDestination(
              icon: Icon(Icons.shopping_bag_outlined),
              selectedIcon: Icon(Icons.shopping_bag),
              label: 'Dépenses'),
          NavigationDestination(
              icon: Icon(Icons.history), selectedIcon: Icon(Icons.history), label: 'Historique'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Paramètres'),
        ],
      ),
    );
  }
}
