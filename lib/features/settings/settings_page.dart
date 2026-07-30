import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/database_provider.dart';
import '../../data/local/demo_data_seeder.dart';

/// Onglet "Paramètres" — minimal pour cette version. Un menu développeur
/// caché (7 appuis sur le numéro de version) donne accès au jeu de données
/// de démonstration, uniquement utile pour les tests, jamais dans le
/// parcours normal.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _versionTapCount = 0;
  bool _devMenuUnlocked = false;

  void _onVersionTap() {
    setState(() {
      _versionTapCount++;
      if (_versionTapCount >= 7) _devMenuUnlocked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: SafeArea(
        child: ListView(
          children: [
            const ListTile(
              leading: Icon(Icons.euro_outlined),
              title: Text('Devise'),
              subtitle: Text(AppConstants.defaultCurrency),
            ),
            const ListTile(
              leading: Icon(Icons.language_outlined),
              title: Text('Langue'),
              subtitle: Text('Français (France)'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text(AppConstants.appName),
              subtitle: const Text('Version 0.1.0'),
              onTap: _onVersionTap,
            ),
            if (_devMenuUnlocked) ...[
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text('Menu développeur', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.science_outlined),
                title: const Text('Charger les données de démonstration'),
                subtitle: const Text('Réservé aux tests — jamais de vraies données'),
                onTap: () async {
                  final db = ref.read(appDatabaseProvider);
                  await DemoDataSeeder(db).seedIfEmpty();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Données de démonstration chargées')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined),
                title: const Text('Réinitialiser toutes les données'),
                onTap: () async {
                  final db = ref.read(appDatabaseProvider);
                  await DemoDataSeeder(db).clearDemoData();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Données réinitialisées')),
                    );
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
