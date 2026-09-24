import 'package:flutter/material.dart';

/// A Light/Dark toggle styled after a sun (light, knob on the left,
/// pale gray track) / moon-and-stars (dark, knob on the right, navy
/// track) reference image the user provided — its own distinct look,
/// not the app's usual neumorphic or the red/green ON-OFF toggle.
class SunMoonToggle extends StatelessWidget {
  final bool isDark;
  final ValueChanged<bool> onChanged;
  final double width;
  final double height;

  const SunMoonToggle({
    super.key,
    required this.isDark,
    required this.onChanged,
    this.width = 108,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final knobDiameter = height - 10;

    return GestureDetector(
      onTap: () => onChanged(!isDark),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: width,
        height: height,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          color: isDark ? const Color(0xFF0F1642) : const Color(0xFFEDEFF4),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.4 : 0.12), blurRadius: 6, offset: const Offset(0, 3)),
          ],
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: knobDiameter,
                height: knobDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1B2358) : Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 3, offset: const Offset(0, 1))],
                ),
                child: Center(
                  child: isDark
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(Icons.nightlight_round, color: const Color(0xFFF5F0DC), size: knobDiameter * 0.5),
                            Positioned(top: knobDiameter * 0.14, right: knobDiameter * 0.14, child: Icon(Icons.star, color: Colors.white.withOpacity(0.85), size: knobDiameter * 0.16)),
                            Positioned(bottom: knobDiameter * 0.18, left: knobDiameter * 0.18, child: Icon(Icons.star, color: Colors.white.withOpacity(0.7), size: knobDiameter * 0.12)),
                          ],
                        )
                      : Icon(Icons.wb_sunny_rounded, color: const Color(0xFFFFC94A), size: knobDiameter * 0.55),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
