import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Transition de navigation standard de l'app : fondu + léger glissement
/// vers le haut, cohérente sur tous les écrans (remplace
/// [MaterialPageRoute] partout dans BudgetPilot).
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({required WidgetBuilder builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionDuration: AppDurations.pageTransition,
          reverseTransitionDuration: AppDurations.pageTransition,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(parent: animation, curve: AppCurves.standard);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
                child: child,
              ),
            );
          },
        );
}
