import 'package:flutter/material.dart';
import '../theme/neumorphic_theme.dart';

/// Ported from a Uiverse.io "glass radio" reference — a floating ball
/// that slides to dock into whichever circle is currently selected,
/// one row per option, with a label next to each circle. The
/// reference's decorative frosted-glass panel was dropped — it read
/// as an unexplained empty box rather than adding anything.
class GlassRadioSelector extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const GlassRadioSelector({super.key, required this.labels, required this.selectedIndex, required this.onChanged});

  static const _circleSize = 40.0;
  static const _rowHeight = 50.0;

  @override
  Widget build(BuildContext context) {
    final totalHeight = labels.length * _rowHeight;

    return SizedBox(
      width: double.infinity,
      height: totalHeight,
      child: Stack(
        children: [
          // Empty ring + label per row (tappable).
          for (var i = 0; i < labels.length; i++)
            Positioned(
              left: 0,
              top: i * _rowHeight + (_rowHeight - _circleSize) / 2,
              right: 0,
              height: _circleSize,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Row(
                  children: [
                    Container(
                      width: _circleSize,
                      height: _circleSize,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: NeumorphicPalette.shadowDark.withOpacity(0.35), width: 6)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: i == selectedIndex ? NeumorphicPalette.accent : NeumorphicPalette.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // The ball, sliding to dock in whichever circle is selected.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeOutBack,
            left: 0,
            top: selectedIndex * _rowHeight + (_rowHeight - _circleSize) / 2,
            width: _circleSize,
            height: _circleSize,
            child: IgnorePointer(
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE8E8E8),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 8, offset: const Offset(0, 4)),
                    BoxShadow(color: NeumorphicPalette.accent.withOpacity(0.55), blurRadius: 14),
                  ],
                ),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2ECC5F),
                    boxShadow: [BoxShadow(color: const Color(0xFF2ECC5F).withOpacity(0.85), blurRadius: 10)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
