import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:provider/provider.dart';
import '../services/haptic_settings.dart';

/// Black + yellow dark theme — the palette established on the
/// BenchPad World hub screen (benchpad_world_screen.dart), shared here
/// so every other screen uses the exact same colors instead of each
/// re-declaring its own private constants.
class BPColors {
  BPColors._();

  static const Color bg = Color(0xFF0A0A0F);
  static const Color card = Color(0xFF16161F);
  static const Color yellow = Color(0xFFFFC94D);

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white60;
  static const Color danger = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF4ADE80);

  // A visible-on-black divider/border tone — NOT the same as bg, since
  // a divider drawn in the background's own near-black color is
  // invisible against it (this app already hit that exact bug once,
  // on the World hub wheel's outer ring).
  static const Color border = Color(0xFF2A2A35);
}

/// Dark equivalent of NeumorphicBox (same API: soft/flat/pressed/
/// borderRadius/onTap/padding) — but styled for this app's black+
/// yellow theme instead of the light neumorphic "soft UI" look. The
/// light theme's dual light/dark drop-shadow reads as embossed only on
/// a light, single-tone surface; on black that trick doesn't work, so
/// this uses a dark card with a thin border that brightens to yellow
/// on press, plus a faint yellow glow when raised — same idea
/// (surface responds to press) via a different mechanism.
class DarkCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool pressed;
  final bool soft;
  final bool flat;
  final VoidCallback? onTap;

  const DarkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.pressed = false,
    this.soft = false,
    this.flat = false,
    this.onTap,
  });

  @override
  State<DarkCard> createState() => _DarkCardState();
}

class _DarkCardState extends State<DarkCard> {
  bool _pressedDown = false;

  void _setPressed(bool value) {
    if (widget.onTap == null || !mounted) return;
    setState(() => _pressedDown = value);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    final isPressed = widget.pressed || _pressedDown;

    Widget box = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      padding: widget.padding,
      transformAlignment: Alignment.center,
      transform: isPressed && !widget.flat ? (Matrix4.identity()..scale(0.97)) : Matrix4.identity(),
      decoration: BoxDecoration(
        color: BPColors.card,
        borderRadius: radius,
        border: Border.all(color: isPressed ? BPColors.yellow.withOpacity(0.7) : BPColors.border, width: 1),
        boxShadow: widget.flat || isPressed
            ? null
            : [BoxShadow(color: BPColors.yellow.withOpacity(0.08), blurRadius: 14, spreadRadius: -4)],
      ),
      child: widget.child,
    );

    if (widget.onTap != null) {
      box = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          if (context.read<HapticSettings>().enabled) {
            HapticFeedback.vibrate();
          }
          _setPressed(true);
        },
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: box,
      );
    }
    return box;
  }
}
