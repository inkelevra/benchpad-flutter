import 'package:flutter/material.dart';
import '../theme/neumorphic_theme.dart';

/// Circular, raised neumorphic social platform badge — filled with the
/// platform's own real brand colour (Simple Icons' official hex per
/// platform), a white brand glyph on top (Simple Icons, CC0), and the
/// platform name labelled below.
class SocialPlatformButton extends StatelessWidget {
  final String iconAsset;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  const SocialPlatformButton({
    super.key,
    required this.iconAsset,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: selected ? Border.all(color: NeumorphicPalette.accent, width: 3) : null,
              boxShadow: [
                BoxShadow(color: NeumorphicPalette.shadowDark, offset: const Offset(3, 3), blurRadius: 7),
                BoxShadow(color: NeumorphicPalette.shadowLight, offset: const Offset(-3, -3), blurRadius: 7),
              ],
            ),
            child: Image.asset(iconAsset, width: size * 0.42, height: size * 0.42, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: selected ? NeumorphicPalette.accent : NeumorphicPalette.textPrimary),
          ),
        ],
      ),
    );
  }
}
