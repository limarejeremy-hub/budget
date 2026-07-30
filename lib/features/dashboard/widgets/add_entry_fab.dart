import 'package:flutter/material.dart';

import '../../entries/fixed_expense_form_page.dart';
import '../../entries/income_form_page.dart';
import '../../entries/saving_form_page.dart';
import '../../entries/variable_expense_form_page.dart';

/// Bouton flottant "+" du tableau de bord : ouvre le choix du type de
/// saisie, puis le vrai formulaire correspondant pour le cycle [cycleId].
class AddEntryFab extends StatelessWidget {
  final int cycleId;
  const AddEntryFab({super.key, required this.cycleId});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      onPressed: () => _showAddMenu(context),
      tooltip: 'Ajouter',
      child: const Icon(Icons.add),
    );
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AddOptionTile(
                icon: Icons.shopping_bag_outlined,
                label: 'Dépense',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => VariableExpenseFormPage(cycleId: cycleId),
                )),
              ),
              _AddOptionTile(
                icon: Icons.receipt_long_outlined,
                label: 'Charge fixe',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => FixedExpenseFormPage(cycleId: cycleId),
                )),
              ),
              _AddOptionTile(
                icon: Icons.payments_outlined,
                label: 'Revenu',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => IncomeFormPage(cycleId: cycleId),
                )),
              ),
              _AddOptionTile(
                icon: Icons.savings_outlined,
                label: 'Épargne',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SavingFormPage(cycleId: cycleId),
                )),
              ),
              const SizedBox(height: 8),
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
  final VoidCallback onTap;
  const _AddOptionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }
}
