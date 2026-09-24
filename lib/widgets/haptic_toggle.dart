import 'package:flutter/material.dart';

/// A Haptic Feedback on/off toggle in the same visual family as
/// SunMoonToggle — a rounded pill with a sliding circular knob holding
/// an icon, rather than the app's old chunky red/green skeuomorphic
/// ON/OFF switch.
class HapticToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final double width;
  final double height;

  const HapticToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 108,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final knobDiameter = height - 10;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: width,
        height: height,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          color: value ? const Color(0xFF3A2F0F) : const Color(0xFFEDEFF4),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(value ? 0.4 : 0.12), blurRadius: 6, offset: const Offset(0, 3)),
          ],
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: knobDiameter,
                height: knobDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? const Color(0xFFFFC94D) : Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 3, offset: const Offset(0, 1))],
                ),
                child: Center(
                  child: Icon(
                    value ? Icons.vibration : Icons.mobile_off,
                    color: value ? const Color(0xFF3A2F0F) : const Color(0xFFFFC94A),
                    size: knobDiameter * 0.52,
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
