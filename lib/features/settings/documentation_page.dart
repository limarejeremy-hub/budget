import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

/// Documentation in-app : comment utiliser BudgetPilot et quelles garanties
/// de conservation des données s'appliquent (résumé de
/// docs/DATA_PERSISTENCE.md pour un accès sans quitter l'app).
class DocumentationPage extends StatelessWidget {
  const DocumentationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documentation')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: const [
            _Section(
              title: 'Utiliser BudgetPilot au quotidien',
              items: [
                "L'Argent Libre, en haut de l'accueil, est ce qu'il vous reste réellement à "
                    "dépenser jusqu'à la fin du cycle, une fois les charges, dépenses et "
                    'épargnes prévues déduites de vos revenus.',
                'La section "Aujourd\'hui" résume les prélèvements et revenus attendus le '
                    'jour même, ainsi que les alertes à traiter en priorité.',
                'Chaque carte du tableau de bord (Revenus, Charges, Dépenses, Épargnes) '
                    "s'ouvre en un clic sur le détail correspondant.",
                'Le bouton "+" permet d\'ajouter un revenu, une charge fixe, une dépense '
                    'variable ou une épargne en quelques secondes.',
                'Sur une charge, ouvrez sa fiche pour la modifier, la marquer comme '
                    'prélevée, la dupliquer ou la supprimer.',
              ],
            ),
            SizedBox(height: AppSpacing.xxl),
            _Section(
              title: 'Conservation de vos données',
              items: [
                'Toutes vos données restent sur cet appareil, dans une base locale — '
                    'aucune synchronisation cloud.',
                'Une mise à jour de l\'application installée par-dessus la précédente '
                    'conserve toujours vos données.',
                'Une désinstallation, en revanche, supprime définitivement les données de '
                    "l'application : pensez à exporter une sauvegarde avant de désinstaller.",
                'Utilisez "Exporter une sauvegarde" régulièrement, et "Importer une '
                    'sauvegarde" pour restaurer vos données sur un nouvel appareil.',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<String> items;
  const _Section({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 6),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(item, style: Theme.of(context).textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}
