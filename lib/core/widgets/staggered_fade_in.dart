import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Apparition douce d'un élément de liste — fondu + léger glissement vers
/// le haut, décalé selon [index] pour un effet "cascade" discret à
/// l'ouverture d'une liste. Le décalage est purement piloté par la
/// [Ticker] du contrôleur (aucun `Timer`/`Future.delayed`), pour se
/// terminer proprement même sous test (`pumpAndSettle` compatible, aucun
/// minuteur qui traîne).
class StaggeredFadeIn extends StatefulWidget {
  final int index;
  final Widget child;

  const StaggeredFadeIn({super.key, required this.index, required this.child});

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    final startFraction = (0.05 * widget.index.clamp(0, 10)).clamp(0.0, 0.6);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(startFraction, 1.0, curve: AppCurves.standard),
    );
    _fade = curved;
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
