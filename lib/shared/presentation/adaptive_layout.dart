import 'package:flutter/material.dart';

/// Shared viewport rules for phone and tablet layouts.
abstract final class AdaptiveLayout {
  static const double tabletBreakpoint = 700;
  static const double maxContentWidth = 1180;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return EdgeInsets.symmetric(
      horizontal: width >= 900 ? 32 : 20,
      vertical: isTablet(context) ? 24 : 12,
    );
  }
}

/// Keeps tablet content comfortably reachable instead of stretching controls
/// to the full display width.
class AdaptiveContent extends StatelessWidget {
  const AdaptiveContent({
    required this.child,
    this.maxWidth = AdaptiveLayout.maxContentWidth,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

class TabletPanel extends StatelessWidget {
  const TabletPanel({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final compactTablet = MediaQuery.sizeOf(context).width < 900;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF282A2D),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF3C4043)),
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(compactTablet ? 16 : 24),
        child: child,
      ),
    );
  }
}
