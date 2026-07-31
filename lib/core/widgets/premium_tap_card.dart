import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Enveloppe standard pour tout élément cliquable "premium" de l'app : ondes
/// Material normales (InkWell) + très légère mise à l'échelle au toucher,
/// pilotée par le même InkWell (pas de second détecteur de geste, donc
/// aucun conflit d'arène de gestes).
///
/// - Si [decoration] est fourni (ex : dégradé), le fond est transparent et
///   c'est [decoration] qui dessine la carte (utilisé par la carte Argent
///   Libre).
/// - Sinon, [color] (ou `surfaceContainerHigh` par défaut) sert de fond uni.
class PremiumTapCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Color? color;
  final Decoration? decoration;
  final List<BoxShadow>? shadows;

  const PremiumTapCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadii.md)),
    this.color,
    this.decoration,
    this.shadows,
  });

  @override
  State<PremiumTapCard> createState() => _PremiumTapCardState();
}

class _PremiumTapCardState extends State<PremiumTapCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomDecoration = widget.decoration != null;
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: AppDurations.fast,
      curve: AppCurves.standard,
      child: Container(
        decoration: hasCustomDecoration
            ? widget.decoration
            : BoxDecoration(
                borderRadius: widget.borderRadius,
                boxShadow: widget.shadows,
              ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: hasCustomDecoration ? Colors.transparent : (widget.color ?? colorScheme.surfaceContainerHigh),
          borderRadius: hasCustomDecoration ? BorderRadius.zero : widget.borderRadius,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: _setPressed,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
