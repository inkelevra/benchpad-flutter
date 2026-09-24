import 'package:flutter/material.dart';

/// Same shape/size/track-colors as SunMoonToggle (for visual
/// consistency within the Appearance card), but for the Auto
/// on/off setting: knob shows "A", and the track shows ON/OFF text
/// on the side opposite the knob so the state reads at a glance,
/// not just during the brief animation when tapped.
class AutoToggle extends StatelessWidget {
  final bool isOn;
  final ValueChanged<bool> onChanged;
  final double width;
  final double height;

  const AutoToggle({
    super.key,
    required this.isOn,
    required this.onChanged,
    this.width = 108,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final knobDiameter = height - 10;

    return GestureDetector(
      onTap: () => onChanged(!isOn),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: width,
        height: height,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          color: isOn ? const Color(0xFF0F1642) : const Color(0xFFEDEFF4),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(isOn ? 0.4 : 0.12), blurRadius: 6, offset: const Offset(0, 3)),
          ],
        ),
        child: Stack(
          children: [
            Align(
              alignment: isOn ? Alignment.centerLeft : Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(left: isOn ? 12 : 0, right: isOn ? 0 : 12),
                child: Text(
                  isOn ? 'ON' : 'OFF',
                  style: TextStyle(color: isOn ? Colors.white : const Color(0xFF7A7E8C), fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
                ),
              ),
            ),
            AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: knobDiameter,
                height: knobDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOn ? const Color(0xFF1B2358) : Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 3, offset: const Offset(0, 1))],
                ),
                child: Center(
                  child: Text(
                    'A',
                    style: TextStyle(color: isOn ? const Color(0xFFF5F0DC) : const Color(0xFFFFC94A), fontWeight: FontWeight.w800, fontSize: knobDiameter * 0.5),
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
