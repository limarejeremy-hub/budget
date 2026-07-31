import 'package:flutter/material.dart';

import '../formatting/currency_formatter.dart';
import '../theme/design_tokens.dart';

/// Affiche un montant en centimes avec une transition douce (comptage)
/// lorsque la valeur change — utilisé pour "Argent Libre" et les totaux du
/// résumé du cycle, pour un rendu premium plutôt qu'un changement instantané.
class AnimatedAmount extends StatefulWidget {
  final int cents;
  final TextStyle? style;
  final Duration duration;

  const AnimatedAmount({
    super.key,
    required this.cents,
    this.style,
    this.duration = AppDurations.slow,
  });

  @override
  State<AnimatedAmount> createState() => _AnimatedAmountState();
}

class _AnimatedAmountState extends State<AnimatedAmount> {
  late int _previousCents = widget.cents;
  late int _targetCents = widget.cents;

  @override
  void didUpdateWidget(covariant AnimatedAmount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cents != _targetCents) {
      _previousCents = _targetCents;
      _targetCents = widget.cents;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(_targetCents),
      tween: Tween<double>(begin: _previousCents.toDouble(), end: _targetCents.toDouble()),
      duration: widget.duration,
      curve: AppCurves.standard,
      builder: (context, value, child) {
        return Text(formatCentsAsEuro(value.round()), style: widget.style);
      },
    );
  }
}
