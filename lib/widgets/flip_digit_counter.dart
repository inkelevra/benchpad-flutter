import 'dart:math' show pi;
import 'package:flutter/material.dart';
import '../theme/neumorphic_theme.dart';

/// A split-flap ("airport departure board") style counter: each digit
/// of [value] sits on its own small raised card with a seam line
/// across the middle, and only the digit(s) that actually changed
/// flip — matching the reference scoreboard/countdown-timer images
/// (each digit its own tile, not one shared window).
class FlipDigitCounter extends StatelessWidget {
  final int value;
  final double digitWidth;
  final double digitHeight;
  final double fontSize;

  const FlipDigitCounter({
    super.key,
    required this.value,
    this.digitWidth = 20,
    this.digitHeight = 26,
    this.fontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final digits = value.toString().split('');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < digits.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          _FlipDigit(digit: digits[i], width: digitWidth, height: digitHeight, fontSize: fontSize),
        ],
      ],
    );
  }
}

class _FlipDigit extends StatelessWidget {
  final String digit;
  final double width;
  final double height;
  final double fontSize;

  const _FlipDigit({required this.digit, required this.width, required this.height, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        transitionBuilder: (child, animation) {
          final rotation = Tween(begin: pi / 2, end: 0.0).animate(animation);
          return AnimatedBuilder(
            animation: rotation,
            child: child,
            builder: (context, child) => Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.003)
                ..rotateX(rotation.value),
              child: child,
            ),
          );
        },
        child: Container(
          key: ValueKey<String>(digit),
          decoration: BoxDecoration(
            color: NeumorphicPalette.background,
            borderRadius: BorderRadius.circular(5),
            boxShadow: [
              BoxShadow(color: NeumorphicPalette.shadowDark, offset: const Offset(2, 2), blurRadius: 4),
              BoxShadow(color: NeumorphicPalette.shadowLight, offset: const Offset(-2, -2), blurRadius: 4),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(digit, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: NeumorphicPalette.textPrimary)),
              // The split-flap seam line across the middle.
              Align(
                alignment: Alignment.center,
                child: Container(height: 1, color: NeumorphicPalette.shadowDark.withOpacity(0.8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
