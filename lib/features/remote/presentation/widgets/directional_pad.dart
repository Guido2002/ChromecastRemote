import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../shared/presentation/remote_haptics.dart';
import 'package:flutter/semantics.dart';

/// Full quadrants handle touch; separate nonoverlapping semantic bounds make
/// each direction discoverable through screen-reader touch exploration.
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
  final ValueChanged<String>? onDirectionLongPressStart,
      onDirectionLongPressEnd;
  final double maxDiameter;
  void _tap(String direction) {
    unawaited(RemoteHaptics.instance.press());
    onDirection(direction);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const regions = [
      (
        'up',
        Icons.keyboard_arrow_up_rounded,
        -math.pi / 2,
        Alignment(0, -0.72),
      ),
      ('right', Icons.keyboard_arrow_right_rounded, 0.0, Alignment(0.72, 0)),
      (
        'down',
        Icons.keyboard_arrow_down_rounded,
        math.pi / 2,
        Alignment(0, 0.72),
      ),
      ('left', Icons.keyboard_arrow_left_rounded, math.pi, Alignment(-0.72, 0)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = (constraints.maxWidth - 16).clamp(0.0, maxDiameter);
        return SizedBox.square(
          dimension: diameter,
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (final (direction, icon, angle, alignment) in regions)
                  Positioned.fill(
                    child: ClipPath(
                      clipper: _QuadrantClipper(angle),
                      child: ExcludeSemantics(
                        child: GestureDetector(
                          onLongPressStart:
                              enabled && onDirectionLongPressStart != null
                              ? (_) {
                                  unawaited(RemoteHaptics.instance.press());
                                  onDirectionLongPressStart!(direction);
                                }
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
                              enableFeedback: false,
                              onTap: enabled ? () => _tap(direction) : null,
                              child: Align(
                                alignment: alignment,
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
                SizedBox.square(
                  dimension: diameter * 0.4,
                  child: Semantics(
                    button: true,
                    enabled: enabled,
                    excludeSemantics: true,
                    label: 'OK, select',
                    sortKey: const OrdinalSortKey(2),
                    onTap: enabled
                        ? () {
                            unawaited(RemoteHaptics.instance.press());
                            onSelect();
                          }
                        : null,
                    child: Material(
                      color: colors.surfaceContainerLow,
                      shape: CircleBorder(
                        side: BorderSide(color: colors.outline),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        enableFeedback: false,
                        customBorder: const CircleBorder(),
                        onTap: enabled
                            ? () {
                                unawaited(RemoteHaptics.instance.press());
                                onSelect();
                              }
                            : null,
                        child: Center(
                          child: Text(
                            'OK',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                for (final (direction, x, y, order) in [
                  ('up', .35, 0.0, 0.0),
                  ('left', 0.0, .35, 1.0),
                  ('right', .7, .35, 3.0),
                  ('down', .35, .7, 4.0),
                ])
                  Positioned(
                    left: diameter * x,
                    top: diameter * y,
                    width: diameter * .3,
                    height: diameter * .3,
                    child: Semantics(
                      button: true,
                      enabled: enabled,
                      sortKey: OrdinalSortKey(order),
                      label:
                          '${direction[0].toUpperCase()}${direction.substring(1)}',
                      onTap: enabled ? () => _tap(direction) : null,
                      child: const IgnorePointer(child: SizedBox.expand()),
                    ),
                  ),
              ],
            ),
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
      angle - math.pi / 4 - .001,
      math.pi / 2 + .002,
      false,
    )
    ..close();
  @override
  bool shouldReclip(_QuadrantClipper oldClipper) => oldClipper.angle != angle;
}
