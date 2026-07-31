import 'package:flutter/material.dart';

import '../branding/brand_resolver.dart';

/// Badge circulaire "logo" d'une entrée (charge, dépense, revenu) : si le
/// nom saisi correspond à une marque connue, affiche son monogramme dans sa
/// couleur caractéristique ; sinon, retombe sur l'icône générique de
/// catégorie fournie par l'appelant.
class BrandBadge extends StatelessWidget {
  final String? name;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final double size;

  const BrandBadge({
    super.key,
    required this.name,
    required this.fallbackIcon,
    required this.fallbackColor,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    final brand = resolveBrand(name);

    if (brand == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: fallbackColor.withValues(alpha: 0.16), shape: BoxShape.circle),
        child: Icon(fallbackIcon, size: size * 0.5, color: fallbackColor),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: brand.color, shape: BoxShape.circle),
      child: Center(
        child: brand.icon != null
            ? Icon(brand.icon, size: size * 0.5, color: Colors.white)
            : Text(
                brand.monogram,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.42,
                ),
              ),
      ),
    );
  }
}
