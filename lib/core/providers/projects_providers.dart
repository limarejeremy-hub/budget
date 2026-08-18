import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/converters/entity_mappers.dart';
import '../../domain/entities/project_entity.dart';
import 'dashboard_providers.dart';

/// Tous les projets (actifs et archivés) — indépendants du cycle courant,
/// comme les crédits.
final projectsProvider = StreamProvider.autoDispose<List<ProjectEntity>>((ref) {
  final repository = ref.watch(cycleRepositoryProvider);
  return repository.watchProjects().map((rows) => rows.map(projectFromRow).toList());
});
