import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/neumorphic_theme.dart';

/// Ported from a Uiverse.io "orbit" loader — a neumorphic inset ring
/// track with a small glossy orb spinning around it with a bouncy
/// ease, instead of the flat Material CircularProgressIndicator arc.
/// The reference's own inset-shadow tones already match this app's
/// palette closely, so almost no recolouring was needed.
class OrbitLoader extends StatefulWidget {
  final double size;
  final Widget? centerChild;

  const OrbitLoader({super.key, this.size = 140, this.centerChild});

  @override
  State<OrbitLoader> createState() => _OrbitLoaderState();
}

class _OrbitLoaderState extends State<OrbitLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringThickness = widget.size * 0.16;
    final orbSize = widget.size * 0.15;
    final orbitRadius = widget.size * 0.3;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer track — subtle inset bevel via a diagonal gradient
          // ring, matching the same trick the rest of the app's
          // "pressed" neumorphic elements use.
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [NeumorphicPalette.shadowDark.withOpacity(0.55), NeumorphicPalette.background, NeumorphicPalette.shadowLight],
              ),
            ),
          ),
          Container(
            width: widget.size - ringThickness * 2,
            height: widget.size - ringThickness * 2,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: NeumorphicPalette.background),
          ),
          // Orbiting glossy orb.
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final angle = Curves.easeInOutBack.transform(_controller.value) * 2 * math.pi;
              final dx = math.cos(angle) * orbitRadius;
              final dy = math.sin(angle) * orbitRadius;
              return Transform.translate(
                offset: Offset(dx, dy),
                child: child,
              );
            },
            child: Container(
              width: orbSize,
              height: orbSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(center: Alignment(-0.3, -0.3), colors: [Colors.white, Color(0xFFCCCCCC)]),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 8, offset: const Offset(0, 4)),
                  BoxShadow(color: NeumorphicPalette.accent.withOpacity(0.35), blurRadius: 6),
                ],
              ),
            ),
          ),
          if (widget.centerChild != null) widget.centerChild!,
        ],
      ),
    );
  }
}
