import 'package:flutter/material.dart';
import '../theme/neumorphic_theme.dart';

/// Ported from a Uiverse.io circular neumorphic checkbox — raised when
/// unchecked, sinks to a pressed/inset look when checked, with a
/// checkmark that switches from a dim grey to the given [color] once
/// checked. Used for the Report/Feedback category picker, one circle
/// per category, coloured the same as that category's description
/// glow (glow_blob_field.dart) so the colour means the same thing in
/// both places.
class CategoryCheckOption extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const CategoryCheckOption({super.key, required this.label, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NeumorphicPalette.background,
              border: Border.all(color: const Color(0xFFECECEC), width: 6),
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [NeumorphicPalette.shadowDark.withOpacity(0.4), NeumorphicPalette.background, NeumorphicPalette.background],
                      stops: const [0, 0.3, 1],
                    )
                  : null,
              boxShadow: selected
                  ? null
                  : [
                      BoxShadow(color: NeumorphicPalette.shadowDark.withOpacity(0.7), offset: const Offset(4, 4), blurRadius: 8),
                      const BoxShadow(color: Colors.white, offset: Offset(-4, -4), blurRadius: 8),
                    ],
            ),
            alignment: Alignment.center,
            child: selected
                ? Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.55), blurRadius: 12)]),
                    child: Icon(Icons.check, size: 24, color: color, shadows: [Shadow(color: color.withOpacity(0.8), blurRadius: 8)]),
                  )
                : Icon(Icons.check, size: 22, color: NeumorphicPalette.textSecondary.withOpacity(0.45)),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 72,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: selected ? color : NeumorphicPalette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
