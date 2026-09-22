import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../theme/neumorphic_theme.dart';

/// A slider styled like a floating music-player scrubber: a thin
/// track line and a large circular thumb with a soft translucent
/// halo, instead of Flutter's default thick Material track. Optional
/// [snapPoints] pull the value to an exact stop (with a light haptic
/// tick) whenever the drag comes within [snapThreshold] of one, while
/// staying freely draggable everywhere else.
class NeumorphicSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final VoidCallback? onChangeStart;
  final List<double>? snapPoints;
  final double snapThreshold;

  const NeumorphicSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onChangeStart,
    this.snapPoints,
    this.snapThreshold = 0,
  });

  @override
  Widget build(BuildContext context) {
    final t = ((value - min) / (max - min)).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        void handle(double dx) {
          final newT = (dx / w).clamp(0.0, 1.0);
          var newValue = min + newT * (max - min);
          if (snapPoints != null) {
            for (final sp in snapPoints!) {
              if ((newValue - sp).abs() < snapThreshold) {
                if ((value - sp).abs() >= snapThreshold) HapticFeedback.selectionClick();
                newValue = sp;
                break;
              }
            }
          }
          onChanged(newValue);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            onChangeStart?.call();
            handle(d.localPosition.dx);
          },
          onHorizontalDragStart: (_) => onChangeStart?.call(),
          onHorizontalDragUpdate: (d) => handle(d.localPosition.dx),
          child: SizedBox(
            height: 36,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(color: NeumorphicPalette.shadowDark.withOpacity(0.6), borderRadius: BorderRadius.circular(2)),
                ),
                Container(
                  height: 3,
                  width: t * w,
                  decoration: BoxDecoration(color: NeumorphicPalette.accent, borderRadius: BorderRadius.circular(2)),
                ),
                if (snapPoints != null)
                  for (final sp in snapPoints!)
                    Positioned(
                      left: ((sp - min) / (max - min)).clamp(0.0, 1.0) * w - 1.5,
                      child: Container(width: 3, height: 3, decoration: BoxDecoration(color: NeumorphicPalette.shadowDark, borderRadius: BorderRadius.circular(2))),
                    ),
                Positioned(
                  left: (t * w - 18).clamp(-18.0, w - 18.0),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: NeumorphicPalette.accent.withOpacity(0.16)),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: NeumorphicPalette.background,
                        border: Border.all(color: NeumorphicPalette.accent, width: 2.5),
                        boxShadow: [BoxShadow(color: NeumorphicPalette.shadowDark, blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                    ),
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
