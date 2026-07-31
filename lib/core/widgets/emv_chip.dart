import 'package:flutter/material.dart';

/// Puce de carte bancaire (EMV) stylisée — dessinée en vectoriel pur
/// (aucune image), grille de contacts discrète. Purement décoratif, posé
/// sur la carte Argent Libre pour renforcer l'identité "carte bancaire
/// premium".
class EmvChip extends StatelessWidget {
  final double width;
  final Color color;

  const EmvChip({super.key, this.width = 34, required this.color});

  @override
  Widget build(BuildContext context) {
    final height = width * 0.76;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.55)],
        ),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      padding: EdgeInsets.symmetric(horizontal: width * 0.1, vertical: height * 0.14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (row) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(2, (col) {
              return Container(
                width: width * 0.32,
                height: height * 0.16,
                decoration: BoxDecoration(
                  border: Border.all(color: color.withValues(alpha: 0.5), width: 0.6),
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}
