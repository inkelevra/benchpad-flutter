import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/neumorphic_theme.dart';

/// Empty-state placeholder for the Advertise preview stage — ported
/// from a Uiverse.io "premium card" reference (moving glow dot along
/// the border, diagonal light sweep, inset border lines), recoloured
/// from the reference's dark palette into the app's own light
/// neumorphic tones so it doesn't clash with the rest of the screen.
class AdvertisePreviewPlaceholder extends StatefulWidget {
  const AdvertisePreviewPlaceholder({super.key});

  @override
  State<AdvertisePreviewPlaceholder> createState() => _AdvertisePreviewPlaceholderState();
}

class _AdvertisePreviewPlaceholderState extends State<AdvertisePreviewPlaceholder> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _corners = [
    Alignment(0.85, -0.85), // top-right
    Alignment(-0.85, -0.85), // top-left
    Alignment(-0.85, 0.85), // bottom-left
    Alignment(0.85, 0.85), // bottom-right
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Alignment _dotAlignment(double t) {
    final scaled = t * _corners.length;
    final i = scaled.floor() % _corners.length;
    final frac = scaled - scaled.floor();
    return Alignment.lerp(_corners[i], _corners[(i + 1) % _corners.length], frac)!;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Soft radial glow from one corner, standing in for the
        // reference's dark radial gradient.
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topLeft,
              radius: 1.4,
              colors: [Colors.white, NeumorphicPalette.shadowDark.withOpacity(0.35)],
            ),
          ),
        ),
        // Diagonal light sweep.
        Positioned(
          top: -20,
          left: -50,
          child: Transform.rotate(
            angle: 40 * math.pi / 180,
            child: Container(
              width: 220,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.65),
                borderRadius: BorderRadius.circular(100),
                boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.7), blurRadius: 28)],
              ),
            ),
          ),
        ),
        // Inset border rectangle (~10% margin, matching the reference).
        Positioned.fill(
          child: FractionallySizedBox(
            widthFactor: 0.8,
            heightFactor: 0.8,
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: NeumorphicPalette.shadowDark.withOpacity(0.5), width: 1)),
            ),
          ),
        ),
        // Moving glow dot orbiting the border.
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Align(
              alignment: _dotAlignment(_controller.value),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: NeumorphicPalette.accent,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: NeumorphicPalette.accent.withOpacity(0.7), blurRadius: 8)],
                ),
              ),
            );
          },
        ),
        // Caption.
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              'Your BenchPad preview will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
