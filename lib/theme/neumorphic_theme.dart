import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:provider/provider.dart';
import '../services/haptic_settings.dart';

/// Light neumorphic ("soft UI") palette and shadow values, ported from
/// Themesberg's open-source neumorphism-ui-bootstrap kit
/// (github.com/themesberg/neumorphism-ui-bootstrap, src/scss/neumorphism/
/// _variables.scss). Scoped to the Home screen as a first UI-polish
/// experiment — the rest of the app still uses AppTheme's dark palette.
class NeumorphicPalette {
  NeumorphicPalette._();

  // $soft / $primary — the single base tone everything sits on; raised
  // and sunken elements use this SAME color, only the shadow pair
  // changes, which is the whole neumorphic trick.
  static const Color background = Color(0xFFE6E7EE);
  static const Color surface = Color(0xFFE6E7EE);

  // $gray-900 / $dark / $black — heading and icon ink.
  static const Color textPrimary = Color(0xFF31344B);
  // $gray-700 — one step darker than the kit's default $gray-600, for
  // better readability against the light background.
  static const Color textSecondary = Color(0xFF66799E);

  // $secondary — the kit's one accent color, used sparingly for
  // emphasis (active nav item, primary CTA).
  static const Color accent = Color(0xFF2D4CC8);

  static const Color danger = Color(0xFFA91E2C);
  // A readable, darker green for "Open now" status — Colors.green/
  // greenAccent were too pale to read on this light background.
  static const Color success = Color(0xFF1E8E3E);

  // Shadow pair colors from $box-shadow-soft / $shadow-inset.
  static const Color shadowDark = Color(0xFFB8B9BE);
  static const Color shadowLight = Color(0xFFFFFFFF);
}

/// A neumorphic surface: same background color as its parent, shaped
/// only by a dual drop-shadow (dark down-right, light up-left) so it
/// reads as gently raised — or, while pressed, a soft inward tint plus
/// a slight scale-down that approximates the kit's `inset` shadow
/// (Flutter's BoxShadow has no inset option, so this is a close visual
/// approximation rather than a literal port). [pressed] forces that
/// look permanently; interactive presses (when [onTap] is set) animate
/// into and out of it on their own, which is what gives the button its
/// "depresses" feel — no Material ripple is used, to keep the look
/// purely neumorphic.
class NeumorphicBox extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool pressed;
  final bool soft;
  final bool flat;
  final VoidCallback? onTap;

  const NeumorphicBox({
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
  State<NeumorphicBox> createState() => _NeumorphicBoxState();
}

class _NeumorphicBoxState extends State<NeumorphicBox> {
  bool _pressedDown = false;

  void _setPressed(bool value) {
    if (widget.onTap == null || !mounted) return;
    setState(() => _pressedDown = value);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    final isPressed = widget.pressed || _pressedDown;
    final distance = widget.soft ? 3.0 : 6.0;
    final blur = widget.soft ? 6.0 : 12.0;

    Widget box = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      padding: widget.padding,
      transformAlignment: Alignment.center,
      transform: isPressed && !widget.flat ? (Matrix4.identity()..scale(0.97)) : Matrix4.identity(),
      decoration: widget.flat
          ? BoxDecoration(
              color: NeumorphicPalette.surface,
              borderRadius: radius,
              border: Border.all(color: NeumorphicPalette.shadowDark.withOpacity(0.7), width: 1),
            )
          : BoxDecoration(
              color: NeumorphicPalette.surface,
              borderRadius: radius,
              gradient: isPressed
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        NeumorphicPalette.shadowDark.withOpacity(0.35),
                        NeumorphicPalette.surface,
                        NeumorphicPalette.surface,
                      ],
                      stops: const [0, 0.25, 1],
                    )
                  : null,
              boxShadow: isPressed
                  ? null
                  : [
                      BoxShadow(color: NeumorphicPalette.shadowDark, offset: Offset(distance, distance), blurRadius: blur),
                      BoxShadow(color: NeumorphicPalette.shadowLight, offset: Offset(-distance, -distance), blurRadius: blur),
                    ],
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
