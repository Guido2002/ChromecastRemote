import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The large circular D-pad from the reference remote design: a dark outer
/// ring with four chevron regions and a lighter center OK circle.
///
/// Each region fires [onDirection] with one of 'up', 'down', 'left', 'right';
/// the center fires [onSelect]. Directions support long-press repetition via
/// [onDirectionLongPressStart] / [onDirectionLongPressEnd].
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
        final available = (constraints.maxWidth - 16).clamp(0.0, maxDiameter);
        final diameter = available < 240
            ? available
            : available.clamp(240.0, maxDiameter);
        return SizedBox.square(
          dimension: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring.
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surfaceContainerHigh,
                  border: Border.all(color: colors.outlineVariant),
                ),
              ),
              _PadRegion(
                alignment: Alignment.topCenter,
                padding: EdgeInsets.only(top: diameter * 0.06),
                icon: Icons.keyboard_arrow_up_rounded,
                semanticLabel: 'Up',
                enabled: enabled,
                onTap: () => onDirection('up'),
                onLongPressStart: onDirectionLongPressStart == null
                    ? null
                    : () => onDirectionLongPressStart!('up'),
                onLongPressEnd: onDirectionLongPressEnd == null
                    ? null
                    : () => onDirectionLongPressEnd!('up'),
              ),
              _PadRegion(
                alignment: Alignment.bottomCenter,
                padding: EdgeInsets.only(bottom: diameter * 0.06),
                icon: Icons.keyboard_arrow_down_rounded,
                semanticLabel: 'Down',
                enabled: enabled,
                onTap: () => onDirection('down'),
                onLongPressStart: onDirectionLongPressStart == null
                    ? null
                    : () => onDirectionLongPressStart!('down'),
                onLongPressEnd: onDirectionLongPressEnd == null
                    ? null
                    : () => onDirectionLongPressEnd!('down'),
              ),
              _PadRegion(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(left: diameter * 0.06),
                icon: Icons.keyboard_arrow_left_rounded,
                semanticLabel: 'Left',
                enabled: enabled,
                onTap: () => onDirection('left'),
                onLongPressStart: onDirectionLongPressStart == null
                    ? null
                    : () => onDirectionLongPressStart!('left'),
                onLongPressEnd: onDirectionLongPressEnd == null
                    ? null
                    : () => onDirectionLongPressEnd!('left'),
              ),
              _PadRegion(
                alignment: Alignment.centerRight,
                padding: EdgeInsets.only(right: diameter * 0.06),
                icon: Icons.keyboard_arrow_right_rounded,
                semanticLabel: 'Right',
                enabled: enabled,
                onTap: () => onDirection('right'),
                onLongPressStart: onDirectionLongPressStart == null
                    ? null
                    : () => onDirectionLongPressStart!('right'),
                onLongPressEnd: onDirectionLongPressEnd == null
                    ? null
                    : () => onDirectionLongPressEnd!('right'),
              ),
              // Center OK circle.
              SizedBox.square(
                dimension: diameter * 0.42,
                child: Material(
                  color: enabled
                      ? colors.surfaceContainerLow
                      : colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: CircleBorder(
                    side: BorderSide(
                      color: enabled
                          ? colors.outline
                          : colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    overlayColor: WidgetStatePropertyAll(
                      colors.primary.withValues(alpha: 0.12),
                    ),
                    onTap: enabled
                        ? () {
                            HapticFeedback.lightImpact();
                            onSelect();
                          }
                        : null,
                    child: Center(
                      child: Text(
                        'OK',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: enabled
                                  ? colors.onSurface
                                  : colors.onSurface.withValues(alpha: 0.35),
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

class _PadRegion extends StatelessWidget {
  const _PadRegion({
    required this.alignment,
    required this.padding,
    required this.icon,
    required this.semanticLabel,
    required this.enabled,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  final Alignment alignment;
  final EdgeInsets padding;
  final IconData icon;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding,
        child: GestureDetector(
          onLongPressStart: enabled && onLongPressStart != null
              ? (_) => onLongPressStart!()
              : null,
          onLongPressEnd: enabled && onLongPressEnd != null
              ? (_) => onLongPressEnd!()
              : null,
          onLongPressCancel: enabled && onLongPressEnd != null
              ? onLongPressEnd
              : null,
          child: IconButton(
            tooltip: semanticLabel,
            onPressed: enabled
                ? () {
                    HapticFeedback.lightImpact();
                    onTap();
                  }
                : null,
            icon: Icon(icon),
            iconSize: 44,
            color: colors.onSurfaceVariant,
            disabledColor: colors.onSurfaceVariant.withValues(alpha: 0.35),
            style: IconButton.styleFrom(
              fixedSize: const Size(72, 72),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              overlayColor: colors.primary.withValues(alpha: 0.12),
            ),
          ),
        ),
      ),
    );
  }
}
