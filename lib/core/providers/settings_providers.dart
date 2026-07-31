import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_providers.dart';

ThemeMode _themeModeFromString(String value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

String themeModeToString(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

/// Thème choisi par l'utilisateur (persisté en base) — 'system' par défaut.
final themeModeProvider = StreamProvider.autoDispose<ThemeMode>((ref) {
  final repository = ref.watch(cycleRepositoryProvider);
  return repository.watchThemeMode().map(_themeModeFromString);
});
