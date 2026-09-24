import 'package:flutter/material.dart';
import '../theme/neumorphic_theme.dart';

/// Report/Feedback description field frame — a bright neon light
/// continuously tracing the rounded border. Started as a Uiverse.io
/// "glowing card" reference with a blurred bouncing colour blob behind
/// a frosted-glass panel, but the blob read as a distracting extra
/// blurred circle once the neon border trace was added, so it was
/// removed — the border trace alone reads much cleaner. Colour stays
/// keyed to the selected category, so it's meaningful (matches the
/// urgency/type of what's being reported) rather than purely
/// decorative.
class GlowBlobField extends StatefulWidget {
  final Color color;
  final Widget child;
  final double borderRadius;

  const GlowBlobField({super.key, required this.color, required this.child, this.borderRadius = 16});

  @override
  State<GlowBlobField> createState() => _GlowBlobFieldState();
}

class _GlowBlobFieldState extends State<GlowBlobField> with SingleTickerProviderStateMixin {
  late final AnimationController _borderController;

  @override
  void initState() {
    super.initState();
    _borderController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _borderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NeumorphicPalette.background,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: NeumorphicPalette.shadowDark.withOpacity(0.7), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Stack(
          children: [
            widget.child,
            // Neon light continuously tracing the border outline —
            // purely decorative, so it must not swallow taps meant for
            // the field underneath. Without IgnorePointer here, this
            // full-size CustomPaint absorbed every tap on the field
            // (it sits on top in the Stack), and typing never focused.
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _borderController,
                  builder: (context, child) => CustomPaint(
                    painter: _NeonBorderPainter(phase: _borderController.value, color: widget.color, borderRadius: widget.borderRadius),
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

/// Traces a bright glowing segment around a rounded-rect border,
/// looping continuously — drawn as a sub-path of the border's own
/// perimeter so it always sits exactly on the outline, at any size.
class _NeonBorderPainter extends CustomPainter {
  final double phase;
  final Color color;
  final double borderRadius;

  _NeonBorderPainter({required this.phase, required this.color, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(borderRadius));
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final total = metric.length;
    if (total <= 0) return;

    final segmentLength = total * 0.22;
    final start = phase * total;
    final end = start + segmentLength;

    Path segment;
    if (end <= total) {
      segment = metric.extractPath(start, end);
    } else {
      segment = metric.extractPath(start, total);
      segment.addPath(metric.extractPath(0, end - total), Offset.zero);
    }

    // Wide soft outer glow, tighter mid glow, bright sharp core — layered
    // for a stronger neon look than a single blurred stroke gives.
    canvas.drawPath(
      segment,
      Paint()
        ..color = color.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawPath(
      segment,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      segment,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _NeonBorderPainter oldDelegate) => oldDelegate.phase != phase || oldDelegate.color != color;
}
