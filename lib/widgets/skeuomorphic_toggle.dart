import 'package:flutter/material.dart';

/// A chunky, skeuomorphic ON/OFF toggle — red track labeled "OFF" with
/// the knob on the right when off, green track labeled "ON" with the
/// knob on the left when on. Deliberately its own look (dark bezel,
/// glossy circular knob) rather than the app's usual neumorphic style,
/// per a reference image the user provided.
class SkeuomorphicToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final double width;
  final double height;

  const SkeuomorphicToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 132,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    final knobDiameter = height - 8;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: width,
        height: height,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: value ? const [Color(0xFF3FCB5C), Color(0xFF1E9E3B)] : const [Color(0xFFE24C4C), Color(0xFFB01E1E)],
                ),
              ),
              child: Align(
                alignment: value ? Alignment.centerLeft : Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(left: value ? 14 : 0, right: value ? 0 : 14),
                  child: Text(
                    value ? 'ON' : 'OFF',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5),
                  ),
                ),
              ),
            ),
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: value ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                width: knobDiameter,
                height: knobDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4A4A4C), Color(0xFF141416)],
                  ),
                  boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      4,
                      (i) => Container(
                        width: 1.4,
                        height: knobDiameter * 0.4,
                        margin: const EdgeInsets.symmetric(horizontal: 1.6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
