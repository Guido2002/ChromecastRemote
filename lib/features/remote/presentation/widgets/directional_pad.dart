import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Every visible quadrant is interactive; OK owns the center circle.
class DirectionalPad extends StatelessWidget {
  const DirectionalPad({
    required this.enabled,
    required this.onDirection,
    required this.onSelect,
    this.onDirectionLongPressStart,
    this.onDirectionLongPressEnd,
    this.maxDiameter = 340,
    super.key,
  });

  final bool enabled;
  final ValueChanged<String> onDirection;
  final VoidCallback onSelect;
  final ValueChanged<String>? onDirectionLongPressStart;
  final ValueChanged<String>? onDirectionLongPressEnd;
  final double maxDiameter;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = (constraints.maxWidth - 16).clamp(0.0, maxDiameter);
        return SizedBox.square(
          dimension: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final (direction, icon, angle, alignment) in [
                (
                  'up',
                  Icons.keyboard_arrow_up_rounded,
                  -math.pi / 2,
                  const Alignment(0, -0.72),
                ),
                (
                  'right',
                  Icons.keyboard_arrow_right_rounded,
                  0.0,
                  const Alignment(0.72, 0),
                ),
                (
                  'down',
                  Icons.keyboard_arrow_down_rounded,
                  math.pi / 2,
                  const Alignment(0, 0.72),
                ),
                (
                  'left',
                  Icons.keyboard_arrow_left_rounded,
                  math.pi,
                  const Alignment(-0.72, 0),
                ),
              ])
                Positioned.fill(
                  child: ClipPath(
                    clipper: _QuadrantClipper(angle),
                    child: Semantics(
                      button: true,
                      enabled: enabled,
                      label:
                          '${direction[0].toUpperCase()}${direction.substring(1)}',
                      child: GestureDetector(
                        onLongPressStart:
                            enabled && onDirectionLongPressStart != null
                            ? (_) => onDirectionLongPressStart!(direction)
                            : null,
                        onLongPressEnd:
                            enabled && onDirectionLongPressEnd != null
                            ? (_) => onDirectionLongPressEnd!(direction)
                            : null,
                        onLongPressCancel:
                            enabled && onDirectionLongPressEnd != null
                            ? () => onDirectionLongPressEnd!(direction)
                            : null,
                        child: Material(
                          color: colors.surfaceContainerHigh,
                          child: InkWell(
                            onTap: enabled
                                ? () {
                                    HapticFeedback.lightImpact();
                                    onDirection(direction);
                                  }
                                : null,
                            child: Align(
                              alignment: alignment,
                              child: ExcludeSemantics(
                                child: Icon(
                                  icon,
                                  size: 36,
                                  color: enabled
                                      ? colors.onSurface
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              SizedBox.square(
                dimension: diameter * 0.42,
                child: Semantics(
                  button: true,
                  enabled: enabled,
                  label: 'OK, select',
                  child: Material(
                    color: colors.surfaceContainerLow,
                    shape: CircleBorder(
                      side: BorderSide(color: colors.outline),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: enabled
                          ? () {
                              HapticFeedback.lightImpact();
                              onSelect();
                            }
                          : null,
                      child: Center(
                        child: ExcludeSemantics(
                          child: Text(
                            'OK',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuadrantClipper extends CustomClipper<Path> {
  const _QuadrantClipper(this.angle);
  final double angle;

  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width / 2, size.height / 2)
    ..arcTo(
      Offset.zero & size,
      angle - math.pi / 4 - 0.001,
      math.pi / 2 + 0.002,
      false,
    )
    ..close();

  @override
  bool shouldReclip(_QuadrantClipper oldClipper) => oldClipper.angle != angle;
}
