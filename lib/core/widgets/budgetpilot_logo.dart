import 'package:flutter/material.dart';

/// Marque BudgetPilot — un sillage ascendant stylisé (trajectoire + point),
/// entièrement dessiné en vectoriel (aucune image, aucun emoji). Remplace
/// l'icône générique utilisée précédemment comme ornement de la carte
/// Argent Libre, et sert de "logo" discret ailleurs dans l'app (en-tête,
/// écran Paramètres).
class BudgetPilotMark extends StatelessWidget {
  final double size;
  final Color color;

  const BudgetPilotMark({super.key, this.size = 22, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _BudgetPilotMarkPainter(color),
    );
  }
}

class _BudgetPilotMarkPainter extends CustomPainter {
  final Color color;
  const _BudgetPilotMarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Sillage ascendant : un ruban courbe qui monte de gauche à droite,
    // évoquant à la fois une trajectoire de vol et une courbe budgétaire
    // en progression.
    final path = Path()
      ..moveTo(w * 0.04, h * 0.80)
      ..quadraticBezierTo(w * 0.30, h * 0.88, w * 0.48, h * 0.52)
      ..quadraticBezierTo(w * 0.64, h * 0.20, w * 0.94, h * 0.04)
      ..quadraticBezierTo(w * 0.78, h * 0.30, w * 0.60, h * 0.44)
      ..quadraticBezierTo(w * 0.44, h * 0.62, w * 0.26, h * 0.94)
      ..close();
    canvas.drawPath(path, paint);

    // Point d'arrivée — insiste sur la trajectoire ascendante.
    canvas.drawCircle(Offset(w * 0.93, h * 0.09), w * 0.055, paint);
  }

  @override
  bool shouldRepaint(covariant _BudgetPilotMarkPainter oldDelegate) => oldDelegate.color != color;
}

/// Badge circulaire portant la marque — utilisé dans l'en-tête du tableau
/// de bord et l'écran Paramètres.
class BudgetPilotBadge extends StatelessWidget {
  final double diameter;
  const BudgetPilotBadge({super.key, this.diameter = 40});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.primaryContainer],
        ),
      ),
      child: Center(
        child: BudgetPilotMark(size: diameter * 0.5, color: colorScheme.onPrimary),
      ),
    );
  }
}
