import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../domain/models/dashboard_view_data.dart';

/// "Il reste X jours dans ce cycle" + barre de progression — donne
/// instantanément le repère temporel du cycle en cours.
class CycleProgressBar extends StatelessWidget {
  final DashboardViewData data;
  const CycleProgressBar({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final daysLeft = data.daysRemaining();
    final progress = data.cycleProgress();
    final label = daysLeft <= 0
        ? 'Dernier jour du cycle'
        : 'Il reste $daysLeft jour${daysLeft > 1 ? 's' : ''} dans ce cycle';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: AppDurations.slow,
                  curve: AppCurves.standard,
                  builder: (context, value, child) => LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
