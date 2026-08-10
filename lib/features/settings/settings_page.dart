import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/providers/shell_providers.dart';
import '../../core/routing/app_page_route.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/budgetpilot_logo.dart';
import '../../data/local/cycle_repository.dart';
import '../../data/local/demo_data_seeder.dart';
import 'documentation_page.dart';

/// Onglet "Paramètres" : sauvegarde locale (export/import JSON), thème,
/// documentation, version, et un menu développeur caché (7 appuis sur le
/// numéro de version) donnant accès au jeu de données de démonstration,
/// uniquement utile pour les tests, jamais dans le parcours normal.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _versionTapCount = 0;
  bool _devMenuUnlocked = false;
  bool _backupBusy = false;
  bool _resetBusy = false;

  void _onVersionTap() {
    setState(() {
      _versionTapCount++;
      if (_versionTapCount >= 7) _devMenuUnlocked = true;
    });
  }

  Future<void> _exportBackup() async {
    setState(() => _backupBusy = true);
    try {
      final repository = ref.read(cycleRepositoryProvider);
      final data = await repository.exportBackup();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Exporter la sauvegarde BudgetPilot',
        fileName: 'budgetpilot-backup-$timestamp.json',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (!mounted) return;
      if (savedPath == null) {
        _showSnackBar('Export annulé');
      } else {
        _showSnackBar('Sauvegarde exportée');
      }
    } catch (e) {
      if (mounted) _showSnackBar("Échec de l'export : $e");
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Importer une sauvegarde BudgetPilot',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.single.bytes;
    if (bytes == null) {
      _showSnackBar('Impossible de lire le fichier sélectionné');
      return;
    }

    final repository = ref.read(cycleRepositoryProvider);
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
      repository.validateBackup(decoded);
    } on FormatException {
      if (mounted) _showValidationError("Ce fichier n'est pas un JSON valide.");
      return;
    } on BackupValidationException catch (e) {
      if (mounted) _showValidationError(e.message);
      return;
    }

    if (!mounted) return;
    final replace = await _askReplaceOrMerge();
    if (replace == null) return; // annulé

    setState(() => _backupBusy = true);
    try {
      final count = await repository.importBackup(decoded! as Map<String, dynamic>, replaceExisting: replace);
      if (mounted) {
        _showSnackBar(
            '$count cycle${count > 1 ? 's' : ''} importé${count > 1 ? 's' : ''} (${replace ? 'remplacement' : 'fusion'})');
      }
    } catch (e) {
      if (mounted) _showSnackBar("Échec de l'import : $e");
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  void _showValidationError(String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sauvegarde invalide'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fermer')),
        ],
      ),
    );
  }

  /// Renvoie `true` pour remplacer, `false` pour fusionner, `null` si annulé.
  Future<bool?> _askReplaceOrMerge() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importer la sauvegarde'),
        content: const Text(
          'Fusionner ajoute les cycles importés à vos données actuelles.\n\n'
          'Remplacer supprime définitivement toutes vos données actuelles avant '
          "d'importer la sauvegarde.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Fusionner'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Remplacer'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// "Repartir de zéro" : supprime toutes les données financières et revient
  /// à l'état du premier lancement. Double confirmation très claire avant
  /// toute suppression — action irréversible.
  Future<void> _startOver() async {
    final wantsToContinue = await _confirmStartOverIntent();
    if (wantsToContinue != true || !mounted) return;

    final finalConfirmation = await _confirmStartOverFinal();
    if (finalConfirmation != true || !mounted) return;

    setState(() => _resetBusy = true);
    try {
      final repository = ref.read(cycleRepositoryProvider);
      await repository.resetAllUserData();
      if (!mounted) return;
      // Ramène automatiquement sur l'onglet Accueil, qui affiche déjà
      // l'écran de création du premier cycle dès que le dernier cycle a
      // disparu (`dashboardProvider` est réactif).
      ref.read(shellTabIndexProvider.notifier).state = 0;
      _showSnackBar('Toutes les données ont été supprimées');
    } finally {
      if (mounted) setState(() => _resetBusy = false);
    }
  }

  Future<bool?> _confirmStartOverIntent() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Repartir de zéro ?'),
        content: const Text(
          'Toutes les données financières seront supprimées : cycles, revenus, '
          'charges, dépenses, épargnes, crédits, projets et historique de '
          'confirmations associé.\n\n'
          "Les préférences d'apparence, la langue et la configuration de "
          "l'application sont conservées.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Continuer')),
        ],
      ),
    );
  }

  Future<bool?> _confirmStartOverFinal() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dernière confirmation'),
        content: const Text(
          'Cette action supprimera toutes vos données financières et ne pourra pas être annulée.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Repartir de zéro'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: AppSpacing.md),
            const Center(child: BudgetPilotBadge(diameter: 56)),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Text(AppConstants.appName, style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const _SectionHeader('Général'),
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
            const _SectionHeader('Thème'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('Système')),
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Clair')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Sombre')),
                ],
                selected: {themeMode},
                onSelectionChanged: (selection) =>
                    ref.read(cycleRepositoryProvider).setThemeMode(themeModeToString(selection.first)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _SectionHeader('Sauvegarde'),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: const Text('Exporter une sauvegarde'),
              subtitle: const Text('Fichier JSON local — cycles, revenus, charges, dépenses, épargnes, crédits'),
              enabled: !_backupBusy,
              onTap: _exportBackup,
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Importer une sauvegarde'),
              subtitle: const Text('Fusion ou remplacement, avec confirmation'),
              enabled: !_backupBusy,
              onTap: _importBackup,
            ),
            const _SectionHeader('Données'),
            ListTile(
              leading: Icon(Icons.restart_alt_outlined, color: Theme.of(context).colorScheme.error),
              title: Text('Repartir de zéro', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              subtitle: const Text("Supprime toutes les données financières et revient à l'état du premier lancement"),
              enabled: !_resetBusy,
              onTap: _startOver,
            ),
            const _SectionHeader('À propos'),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Documentation'),
              subtitle: const Text("Utilisation de l'app et conservation des données"),
              onTap: () => Navigator.of(context).push(AppPageRoute(
                builder: (_) => const DocumentationPage(),
              )),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text(AppConstants.appName),
              subtitle: const Text('Version 1.1.0'),
              onTap: _onVersionTap,
            ),
            if (_devMenuUnlocked) ...[
              const _SectionHeader('Mode développeur'),
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
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.sm),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
      ),
    );
  }
}
