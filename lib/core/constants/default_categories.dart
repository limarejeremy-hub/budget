/// Catégories par défaut utilisées pour peupler la base au premier lancement.
/// (name, type, icon)
const List<(String, String, String)> defaultIncomeCategories = [
  ('Salaire', 'income', 'work'),
  ('Prime', 'income', 'star'),
  ('Allocation', 'income', 'card_giftcard'),
  ('Remboursement', 'income', 'undo'),
  ('Vente', 'income', 'sell'),
  ('Autre', 'income', 'more_horiz'),
];

const List<(String, String, String)> defaultFixedCategories = [
  ('Logement', 'fixed_expense', 'home'),
  ('Crédit', 'fixed_expense', 'account_balance'),
  ('Véhicule', 'fixed_expense', 'directions_car'),
  ('Assurance', 'fixed_expense', 'shield'),
  ('Énergie', 'fixed_expense', 'bolt'),
  ('Télécommunications', 'fixed_expense', 'phone_iphone'),
  ('Abonnement', 'fixed_expense', 'subscriptions'),
  ('Enfants', 'fixed_expense', 'child_care'),
  ('Impôts', 'fixed_expense', 'gavel'),
  ('Santé', 'fixed_expense', 'medical_services'),
  ('Épargne', 'fixed_expense', 'savings'),
  ('Autre', 'fixed_expense', 'more_horiz'),
];

const List<(String, String, String)> defaultVariableCategories = [
  ('Courses', 'variable_expense', 'shopping_cart'),
  ('Carburant / Recharge', 'variable_expense', 'local_gas_station'),
  ('Restaurant', 'variable_expense', 'restaurant'),
  ('Loisirs', 'variable_expense', 'sports_esports'),
  ('Achats en ligne', 'variable_expense', 'shopping_bag'),
  ('Maison', 'variable_expense', 'chair'),
  ('Enfants', 'variable_expense', 'child_friendly'),
  ('Vêtements', 'variable_expense', 'checkroom'),
  ('Santé', 'variable_expense', 'medical_services'),
  ('Voiture', 'variable_expense', 'directions_car'),
  ('Cadeaux', 'variable_expense', 'card_giftcard'),
  ('Vacances', 'variable_expense', 'flight'),
  ('Animaux', 'variable_expense', 'pets'),
  ('Autre', 'variable_expense', 'more_horiz'),
];

const List<(String, String, String)> defaultSavingCategories = [
  ('Épargne', 'saving', 'savings'),
];
