import 'package:flutter/material.dart';

/// Léger reflet lumineux qui balaie la carte une seule fois à son
/// apparition — discret (un seul passage, pas de boucle continue, pour
/// rester "discret et non gadget"), isolé dans son propre
/// [RepaintBoundary] pour ne jamais forcer de rebuild du contenu de la
/// carte pendant l'animation. Ticker pur (pas de `Timer`/`Future.delayed`),
/// donc se termine proprement (compatible `pumpAndSettle` dans les tests).
class ShimmerSheen extends StatefulWidget {
  final double borderRadius;

  const ShimmerSheen({super.key, this.borderRadius = 0});

  @override
  State<ShimmerSheen> createState() => _ShimmerSheenState();
}

class _ShimmerSheenState extends State<ShimmerSheen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Le reflet ne traverse que pendant le premier tiers du
              // cycle, puis reste hors champ — effet "passage" discret
              // plutôt qu'un balayage continu.
              final t = _controller.value;
              final sweep = (t * 2.4) - 0.7;
              return FractionalTranslation(
                translation: Offset(sweep, 0),
                child: Transform.rotate(
                  angle: -0.35,
                  child: Container(
                    width: 60,
                    height: 400,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
