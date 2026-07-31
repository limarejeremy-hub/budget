import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Barre de recherche + bouton de tri, réutilisée par toutes les listes
/// premium (charges, dépenses, revenus, épargnes).
class PremiumSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final VoidCallback onToggleSort;
  final bool sortAscending;
  final String sortTooltip;

  const PremiumSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onToggleSort,
    required this.sortAscending,
    this.sortTooltip = 'Trier',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: colorScheme.surfaceContainerHigh,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filledTonal(
            tooltip: sortTooltip,
            onPressed: onToggleSort,
            icon: AnimatedRotation(
              turns: sortAscending ? 0 : 0.5,
              duration: AppDurations.medium,
              child: const Icon(Icons.sort_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
