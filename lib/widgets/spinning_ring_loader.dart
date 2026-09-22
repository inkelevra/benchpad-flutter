import 'package:flutter/material.dart';
import '../theme/neumorphic_theme.dart';

/// Ported from a Uiverse.io "donut spinner" reference — a neumorphic
/// ring frame with a rotating violet-to-pink gradient disc behind a
/// punched neumorphic center hole. Used on BenchPad AI Studio's
/// "generating" step in place of the pulsing orb.
///
/// [centerImageAsset] is meant for the Kinesus logo GIF (Flutter plays
/// animated GIFs automatically via Image.asset — no extra work needed
/// once the asset is added) — falls back to gradient "AI" lettering
/// until that asset exists. Either way the center content spins
/// slowly, clockwise, independently of the outer ring.
class SpinningRingLoader extends StatefulWidget {
  final double size;
  final String? centerImageAsset;

  const SpinningRingLoader({super.key, this.size = 140, this.centerImageAsset});

  @override
  State<SpinningRingLoader> createState() => _SpinningRingLoaderState();
}

class _SpinningRingLoaderState extends State<SpinningRingLoader> with TickerProviderStateMixin {
  late final AnimationController _ringController;
  late final AnimationController _centerController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    _centerController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _ringController.dispose();
    _centerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final holeSize = widget.size * 0.4;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer neumorphic frame.
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NeumorphicPalette.background,
              boxShadow: [
                BoxShadow(color: NeumorphicPalette.shadowDark.withOpacity(0.5), offset: const Offset(4, 4), blurRadius: 9),
                BoxShadow(color: Colors.white.withOpacity(0.7), offset: const Offset(-4, -4), blurRadius: 9),
              ],
            ),
          ),
          // Rotating gradient disc.
          RotationTransition(
            turns: _ringController,
            child: Container(
              width: widget.size * 0.8,
              height: widget.size * 0.8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF595CFC), Color(0xFFE239F1)]),
              ),
            ),
          ),
          // Punched neumorphic center hole.
          Container(
            width: holeSize,
            height: holeSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NeumorphicPalette.background,
              border: Border.all(color: NeumorphicPalette.shadowDark.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(color: NeumorphicPalette.shadowDark.withOpacity(0.4), offset: const Offset(2, 2), blurRadius: 5),
                BoxShadow(color: Colors.white.withOpacity(0.6), offset: const Offset(-2, -2), blurRadius: 5),
              ],
            ),
            child: ClipOval(
              child: RotationTransition(
                turns: _centerController, // clockwise, per request
                child: widget.centerImageAsset != null
                    ? Image.asset(widget.centerImageAsset!, fit: BoxFit.cover)
                    : Center(
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(colors: [Color(0xFF595CFC), Color(0xFFE239F1)]).createShader(bounds),
                          child: Text('AI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: widget.size * 0.16, color: Colors.white)),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
