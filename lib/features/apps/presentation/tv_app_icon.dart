import 'package:flutter/material.dart';

import '../tv_app.dart';

class TvAppIcon extends StatelessWidget {
  const TvAppIcon({
    required this.app,
    required this.size,
    this.borderRadius = 12,
    super.key,
  });

  final TvApp app;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Text(
        app.name.characters.first.toUpperCase(),
        style: TextStyle(
          color: colors.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final assetPath = app.iconAssetPath;
    if (assetPath == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
