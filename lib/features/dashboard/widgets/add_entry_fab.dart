import 'package:flutter/material.dart';

/// Bouton flottant unique "+". Les options sont temporaires pour la Phase 2 —
/// les formulaires réels arrivent en Phase 3/4.
class AddEntryFab extends StatelessWidget {
  const AddEntryFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showAddMenu(context),
      child: const Icon(Icons.add),
    );
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return const SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AddOptionTile(icon: Icons.shopping_bag_outlined, label: 'Dépense'),
              _AddOptionTile(icon: Icons.receipt_long_outlined, label: 'Charge fixe'),
              _AddOptionTile(icon: Icons.payments_outlined, label: 'Revenu'),
              _AddOptionTile(icon: Icons.savings_outlined, label: 'Épargne'),
              SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _AddOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _AddOptionTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label — disponible prochainement')),
        );
      },
    );
  }
}
