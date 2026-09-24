import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../widgets/home_back_leading.dart';
import 'vault_sphere_screen.dart';
import 'memory_sphere_screen.dart';
import 'hex_grid_screen.dart';
import 'profile_screen.dart';
import 'community_screen.dart';

/// BenchPad World — navigation hub.
///
/// Black-and-yellow redesign (first screen of this pass; the rest of
/// the app follows the same language once this one is confirmed).
/// Black background with a faint grayscale world-map watermark; My
/// Profile / Community as two slim buttons up top; the three Time
/// Capsules as glowing circular buttons arranged in a ring below —
/// each capsule now shows only its plain "Time Capsule N" name (no
/// second technical name like "Time Capsule 1" underneath) since having
/// the same underlying capsule mechanic called three different single
/// words (Vault / Memory / a bare "Hex Grid") read as inconsistent.
/// Secret Room removed entirely — unused, no concept for it yet.
class BenchPadWorldScreen extends StatelessWidget {
  const BenchPadWorldScreen({super.key});

  static const _bg = Color(0xFF0A0A0F);
  static const _card = Color(0xFF16161F);
  static const _yellow = Color(0xFFFFC94D);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: _bg,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: Builder(builder: homeBackLeading),
          leadingWidth: 72,
          centerTitle: true,
          title: const Text('Time Capsules', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: Stack(
          children: [
            // Faint world-map watermark — same premium-dark texture idea
            // the user referenced (dark grey continents, barely visible).
            Positioned.fill(
              child: Opacity(
                opacity: 0.07,
                child: Image.asset('assets/images/world-map-silhouette.png', fit: BoxFit.cover, alignment: Alignment.center),
              ),
            ),
            SafeArea(
              child: NotificationListener<OverscrollIndicatorNotification>(
                onNotification: (n) {
                  n.disallowIndicator();
                  return true;
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    const _FoundingKeyVideo(),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _slimButton(
                            icon: Icons.person_outline,
                            label: 'My Profile',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _slimButton(
                            icon: Icons.groups_outlined,
                            label: 'Community',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunityScreen())),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    _CapsuleWheel(
                      items: [
                        _WheelItem(
                          icon: Icons.workspace_premium_outlined,
                          label: 'Time Capsule 1',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultSphereScreen())),
                        ),
                        _WheelItem(
                          icon: Icons.hub_outlined,
                          label: 'Time Capsule 2',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MemorySphereScreen())),
                        ),
                        _WheelItem(
                          icon: Icons.grid_view_rounded,
                          label: 'Time Capsule 3',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HexGridScreen())),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              child: SafeArea(
                child: GestureDetector(
                  onTap: () => _showInfoSheet(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _card,
                      border: Border.all(color: _yellow.withOpacity(0.6), width: 1.2),
                      boxShadow: [
                        BoxShadow(color: _yellow.withOpacity(0.16), blurRadius: 12, spreadRadius: -2),
                        const BoxShadow(color: Colors.black, offset: Offset(1, 2), blurRadius: 5),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text('i', style: TextStyle(color: _yellow, fontSize: 18, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _card, border: Border.all(color: _yellow.withOpacity(0.6))),
                  alignment: Alignment.center,
                  child: const Text('i', style: TextStyle(color: _yellow, fontSize: 16, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic)),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('How the spheres work', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white))),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Each sphere is a reservation for one spot. Reserve a spot, fill it with a photo or message, then seal it — it will publish on the physical BenchPad display, on the date and time you choose.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 24),
            _infoStep('1', 'Tap a capsule', 'Time Capsule 1, 2 or 3 — each is its own set of reservable spots, shown as a 3D sphere or a hex grid.'),
            _infoStep('2', 'Pick an empty spot', 'Empty spots are open to anyone. Tap one to start filling it in — or, if it was reserved specifically for you, use the access code you were given under "My Capsule" in Profile.'),
            _infoStep('3', 'Fill in your identity', 'A name or pseudonym, and your country — this is what appears alongside your publication.'),
            _infoStep('4', 'Add your message and photo', 'Whatever you want shown on the display — a short message, a photograph, or both.'),
            _infoStep('5', 'Choose when it publishes', 'Pick the date and time your capsule shows on the physical BenchPad display, and whether it stays private until then or is visible right away.'),
            _infoStep('6', 'Seal it', '"Save as locked" keeps it editable — nothing publishes yet. "Seal" locks it permanently and schedules the publish. You can\'t edit a sealed capsule afterward.'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _infoStep(String number, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _yellow.withOpacity(0.7))),
            alignment: Alignment.center,
            child: Text(number, style: const TextStyle(color: _yellow, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(body, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _slimButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _yellow.withOpacity(0.55), width: 1.2),
          boxShadow: [
            BoxShadow(color: _yellow.withOpacity(0.16), blurRadius: 16, spreadRadius: -2),
            const BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 6),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _yellow, size: 18),
            const SizedBox(width: 8),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }
}

class _WheelItem {
  final IconData icon;
  final Widget? customIcon; // when set, shown instead of `icon`
  final String label;
  final VoidCallback onTap;
  const _WheelItem({required this.icon, this.customIcon, required this.label, required this.onTap});
}

/// A self-contained "idle breathing" icon: its own AnimationController
/// (not shared with any parent State — this widget is built directly
/// inside BenchPadWorldScreen.build(), which has no ticker/animation
/// state of its own), so it works wherever it's placed. [phase] (0..1)
/// offsets where in the shared-length cycle this particular instance
/// starts, so multiple of these don't all pulse in lockstep.
class _PulsingIcon extends StatefulWidget {
  final CustomPainter Function(double t) makePainter;
  final double phase;
  final double size;
  const _PulsingIcon({required this.makePainter, this.phase = 0, this.size = 44});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = (_controller.value + widget.phase) % 1.0;
        return SizedBox(width: widget.size, height: widget.size, child: CustomPaint(painter: widget.makePainter(t)));
      },
    );
  }
}

/// Time Capsule 1 (Time Capsule 1) — a sealed capsule: a rounded pill
/// outline with a horizontal seam and a small seal dot.
class _CapsuleIconPainter extends CustomPainter {
  final Color color;
  final double t; // 0..1, one idle "breathing" cycle
  const _CapsuleIconPainter(this.color, {this.t = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final rect = Rect.fromLTWH(w * 0.27, h * 0.08, w * 0.46, h * 0.84);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.23));
    canvas.drawRRect(rrect, stroke);
    canvas.drawLine(Offset(w * 0.27, h * 0.5), Offset(w * 0.73, h * 0.5), stroke);

    // The seal dot pulses like a slow heartbeat — this capsule is
    // sealed and "alive", waiting for its moment.
    final pulse = 0.5 + 0.5 * math.sin(2 * math.pi * t);
    canvas.drawCircle(Offset(w * 0.5, h * 0.68), w * (0.045 + 0.02 * pulse), Paint()..color = color.withOpacity(0.55 + 0.45 * pulse));
  }

  @override
  bool shouldRepaint(covariant _CapsuleIconPainter oldDelegate) => oldDelegate.color != color || oldDelegate.t != t;
}

/// Time Capsule 2 (Time Capsule 2) — a globe of connected people: a
/// circle outline with nodes linked back to a shared center.
class _GlobeNetworkIconPainter extends CustomPainter {
  final Color color;
  final double t; // 0..1, one idle "pulse traveling outward" cycle
  const _GlobeNetworkIconPainter(this.color, {this.t = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final center = Offset(w / 2, h / 2);
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.065;
    canvas.drawCircle(center, w * 0.42, outline);

    final nodes = [
      Offset(w * 0.5, h * 0.16),
      Offset(w * 0.20, h * 0.40),
      Offset(w * 0.80, h * 0.40),
      Offset(w * 0.30, h * 0.78),
      Offset(w * 0.70, h * 0.78),
    ];
    final linkPaint = Paint()
      ..color = color.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035;
    for (final n in nodes) {
      canvas.drawLine(center, n, linkPaint);
    }
    final dotPaint = Paint()..color = color;
    canvas.drawCircle(center, w * 0.06, dotPaint);
    for (final n in nodes) {
      canvas.drawCircle(n, w * 0.05, dotPaint);
    }

    // A small bright pulse travels from the center out to each node in
    // turn, like a signal reaching people around the world.
    final travelPaint = Paint()..color = Colors.white.withOpacity(0.85);
    for (int i = 0; i < nodes.length; i++) {
      final localT = (t + i / nodes.length) % 1.0;
      final pos = Offset.lerp(center, nodes[i], localT)!;
      final fade = (1 - (localT - 0.5).abs() * 2).clamp(0.0, 1.0); // fades in/out along the trip
      canvas.drawCircle(pos, w * 0.028, Paint()..color = travelPaint.color.withOpacity(0.85 * fade));
    }
  }

  @override
  bool shouldRepaint(covariant _GlobeNetworkIconPainter oldDelegate) => oldDelegate.color != color || oldDelegate.t != t;
}

/// Time Capsule 3 (Hex Grid) — a small honeycomb cluster of 3 hexagons.
class _HexClusterIconPainter extends CustomPainter {
  final Color color;
  final double t; // 0..1, one idle "cells lighting up in sequence" cycle
  const _HexClusterIconPainter(this.color, {this.t = 0});

  Path _hex(Offset c, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = math.pi / 180 * (60 * i - 30);
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = w * 0.24;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeJoin = StrokeJoin.round;
    final centers = [
      Offset(w * 0.5, h * 0.32),
      Offset(w * 0.27, h * 0.68),
      Offset(w * 0.73, h * 0.68),
    ];
    for (int i = 0; i < centers.length; i++) {
      // Each cell "lights up" in its own turn, one after another.
      final localT = (t + i / centers.length) % 1.0;
      final glow = 0.5 + 0.5 * math.sin(2 * math.pi * localT);
      final fill = Paint()
        ..color = color.withOpacity(0.12 + 0.22 * glow)
        ..style = PaintingStyle.fill;
      final path = _hex(centers[i], r);
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _HexClusterIconPainter oldDelegate) => oldDelegate.color != color || oldDelegate.t != t;
}

/// A donut/pie wheel — three yellow wedge segments forming a ring
/// around a center hub disc, matching the referenced infographic wheel
/// (3 wedges instead of 8): top, bottom-left, bottom-right, going
/// counter-clockwise. Stateful so a pressed wedge can light up its
/// own perimeter immediately (tactile press feedback), without
/// waiting on Material's ink machinery to work through a custom
/// annular-sector clip.
class _CapsuleWheel extends StatefulWidget {
  final List<_WheelItem> items;
  const _CapsuleWheel({required this.items});

  @override
  State<_CapsuleWheel> createState() => _CapsuleWheelState();
}

class _CapsuleWheelState extends State<_CapsuleWheel> {
  static const _yellow = BenchPadWorldScreen._yellow;
  // A richer, more saturated amber specifically for the wedge fill —
  // the brand `_yellow` is fairly pale/pastel, which read as washed
  // out compared to the referenced infographic wheel's deeper gold.
  // Ring/hub/border stay on the brand `_yellow` for consistency with
  // the rest of the app; only this fill changes.
  static const _wedgeYellow = Color(0xFFFFC107);
  static const _card = BenchPadWorldScreen._card;
  static const _bg = BenchPadWorldScreen._bg;
  static const _separatorWidth = 4.0; // constant-width straight gap, not an angular wedge
  static const _frameGap = 7.0; // breathing room between the wedges and the outer frame ring

  int? _pressedIndex;

  /// Which wedge (if any) contains [localPos], given the wheel's
  /// [center] and the [angles] each wedge is centered on (each
  /// spanning ±60° around its center — full 120°, no gap). Returns
  /// null for the hub hole, outside the ring, or between rings.
  int? _wedgeIndexAt(Offset localPos, Offset center, List<double> angles, double innerR, double outerR) {
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    final r = math.sqrt(dx * dx + dy * dy);
    if (r < innerR || r > outerR) return null;
    final angleDeg = math.atan2(dy, dx) * 180 / math.pi;
    for (int i = 0; i < angles.length; i++) {
      var diff = (angleDeg - angles[i]) % 360;
      if (diff > 180) diff -= 360;
      if (diff.abs() <= 60) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = math.min(constraints.maxWidth, 320.0);
        final outerRadius = diameter * 0.48;
        final innerRadius = outerRadius * 0.40;
        final center = Offset(diameter / 2, diameter / 2);

        // -90° = straight up (Time Capsule 1). Going counter-clockwise
        // from there — the user's explicit order — the next stop is
        // bottom-left (Time Capsule 2, "left side") at 150°, then
        // bottom-right (Time Capsule 3, "right side") at 30°.
        // Clockwise from the top (TC1 at 12 o'clock, TC2 lower-right,
        // TC3 lower-left) — the conventional direction for a numbered
        // dial, matching how most circular UIs (gauges, clock faces)
        // read. Was counter-clockwise (TC2/TC3 swapped) before.
        final angles = [-90.0, 30.0, 150.0];

        return Center(
          child: SizedBox(
            width: diameter,
            height: diameter,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => setState(() => _pressedIndex = _wedgeIndexAt(details.localPosition, center, angles, innerRadius, outerRadius)),
              onTapUp: (_) {
                final index = _pressedIndex;
                setState(() => _pressedIndex = null);
                if (index != null) widget.items[index].onTap();
              },
              onTapCancel: () => setState(() => _pressedIndex = null),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _WheelRingPainter(
                        center: center,
                        innerRadius: innerRadius,
                        outerRadius: outerRadius,
                        wedgeOuterRadius: outerRadius - _frameGap,
                        centerAnglesDeg: angles,
                        separatorWidth: _separatorWidth,
                        yellow: _wedgeYellow,
                        separatorColor: _bg,
                        ringColor: Color.lerp(_yellow, Colors.black, 0.25)!,
                        pressedIndex: _pressedIndex,
                      ),
                    ),
                  ),
                  for (int i = 0; i < widget.items.length; i++)
                    _wedgeContent(widget.items[i], center, angles[i], innerRadius, outerRadius - _frameGap),
                  Positioned(
                    left: center.dx - innerRadius,
                    top: center.dy - innerRadius,
                    width: innerRadius * 2,
                    height: innerRadius * 2,
                    child: _hubDisc(innerRadius * 2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Icon + short label, centered at the wedge's middle angle/radius —
  /// purely visual now; the actual tap target is the whole wedge,
  /// handled by the GestureDetector wrapping the entire wheel above.
  Widget _wedgeContent(_WheelItem item, Offset center, double angleDeg, double innerR, double outerR) {
    final midR = (innerR + outerR) / 2;
    final rad = angleDeg * math.pi / 180;
    final pos = Offset(center.dx + midR * math.cos(rad), center.dy + midR * math.sin(rad));
    final contentSize = math.min((outerR - innerR) * 1.5, 104.0);

    final match = RegExp(r'\d+').firstMatch(item.label);
    final number = match?.group(0);

    return Positioned(
      left: pos.dx - contentSize / 2,
      top: pos.dy - contentSize / 2,
      width: contentSize,
      height: contentSize,
      child: IgnorePointer(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset('assets/images/hub-mark.png', width: 62),
              if (number != null) ...[
                const SizedBox(height: 2),
                Text(
                  number,
                  style: const TextStyle(color: _bg, fontSize: 22, fontWeight: FontWeight.w900, height: 1.0),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The center disc — same convex/glossy treatment as before, sized
  /// to exactly fill the ring's hole, carrying the BenchPad mark, not
  /// tappable (it's the hub, not a destination).
  Widget _hubDisc(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: _yellow.withOpacity(0.35), blurRadius: 26, spreadRadius: -2),
          const BoxShadow(color: Colors.black, offset: Offset(2, 4), blurRadius: 12),
        ],
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.35, -0.5),
                  radius: 1.15,
                  colors: [
                    Color.lerp(_card, Colors.white, 0.20)!,
                    _card,
                    Color.lerp(_card, Colors.black, 0.35)!,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
            Positioned(
              top: size * 0.08,
              left: size * 0.18,
              width: size * 0.5,
              height: size * 0.28,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.white.withOpacity(0.22), Colors.white.withOpacity(0.0)],
                  ),
                ),
              ),
            ),
            Center(
              child: Image.asset(
                'assets/images/benchpad-logo-mark.png',
                width: size * 0.44,
                height: size * 0.44,
                color: _yellow,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _yellow.withOpacity(0.8), width: 1.8)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Builds one annular-sector (donut wedge) path: from [startAngle],
/// sweeping [sweepAngle] radians, between [innerR] and [outerR] —
/// with all 4 corners rounded off by [cornerRadius] (matches the
/// referenced infographic wheel's rounded-corner segments instead of
/// sharp points). Each rounded corner is a quadratic Bézier using the
/// original sharp-corner point as its control point — a standard,
/// cheap fillet approximation that's visually indistinguishable from
/// a true arc at radii this small.
Path _wedgePath(Offset center, double innerR, double outerR, double startAngle, double sweepAngle, {double cornerRadius = 10}) {
  final endAngle = startAngle + sweepAngle;
  // Angular size, in radians, that cornerRadius subtends at each of the
  // two radii — used to pull the arc's start/end back to make room for
  // the fillets.
  final dThetaOuter = (cornerRadius / outerR).clamp(0.0, sweepAngle / 2 - 0.001);
  final dThetaInner = (cornerRadius / innerR).clamp(0.0, sweepAngle / 2 - 0.001);

  Offset pt(double r, double a) => Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));

  final outerRect = Rect.fromCircle(center: center, radius: outerR);
  final innerRect = Rect.fromCircle(center: center, radius: innerR);

  final startOuterCorner = pt(outerR, startAngle); // the sharp corner this fillet replaces
  final endOuterCorner = pt(outerR, endAngle);
  final endInnerCorner = pt(innerR, endAngle);
  final startInnerCorner = pt(innerR, startAngle);

  final p1 = pt(outerR - cornerRadius, startAngle); // on the start radial edge, short of the outer corner
  final p2 = pt(outerR, startAngle + dThetaOuter); // on the outer arc, just past the start corner
  final p3 = pt(outerR, endAngle - dThetaOuter); // on the outer arc, just before the end corner
  final p4 = pt(outerR - cornerRadius, endAngle); // on the end radial edge, short of the outer corner
  final p5 = pt(innerR + cornerRadius, endAngle); // on the end radial edge, short of the inner corner
  final p6 = pt(innerR, endAngle - dThetaInner); // on the inner arc, just before the end corner
  final p7 = pt(innerR, startAngle + dThetaInner); // on the inner arc, just past the start corner
  final p8 = pt(innerR + cornerRadius, startAngle); // on the start radial edge, short of the inner corner

  return Path()
    ..moveTo(p1.dx, p1.dy)
    ..quadraticBezierTo(startOuterCorner.dx, startOuterCorner.dy, p2.dx, p2.dy)
    ..arcTo(outerRect, startAngle + dThetaOuter, sweepAngle - 2 * dThetaOuter, false)
    ..quadraticBezierTo(endOuterCorner.dx, endOuterCorner.dy, p4.dx, p4.dy)
    ..lineTo(p5.dx, p5.dy)
    ..quadraticBezierTo(endInnerCorner.dx, endInnerCorner.dy, p6.dx, p6.dy)
    ..arcTo(innerRect, endAngle - dThetaInner, -(sweepAngle - 2 * dThetaInner), false)
    ..quadraticBezierTo(startInnerCorner.dx, startInnerCorner.dy, p8.dx, p8.dy)
    ..lineTo(p1.dx, p1.dy)
    ..close();
}

/// Paints the 3 (or N) donut wedges forming the ring:
/// - One shared radial-gradient shader (anchored to the whole ring's
///   bounds, not each wedge's own bounds) so the sheen reads as one
///   coherent light source across the wheel instead of three
///   separately-lit, mismatched patches — that mismatch was what read
///   as "wrong/muddy color" rather than the flat accent yellow used
///   elsewhere in the app.
/// - Full 120° wedges with NO angular gap between them — the seam is
///   cut afterward as a straight constant-width line (see
///   [separatorWidth]), not by shrinking the sweep angle, which would
///   make the gap widen toward the rim like a ray.
/// - A crisp outer ring stroke framing the whole wheel, matching the
///   referenced infographic's outer circle.
/// - The currently pressed wedge (if any) gets an extra bright
///   perimeter glow — immediate tactile press feedback.
class _WheelRingPainter extends CustomPainter {
  final Offset center;
  final double innerRadius, outerRadius;
  final double wedgeOuterRadius;
  final List<double> centerAnglesDeg;
  final double separatorWidth;
  final Color yellow;
  final Color separatorColor;
  final Color ringColor;
  final int? pressedIndex;

  const _WheelRingPainter({
    required this.center,
    required this.innerRadius,
    required this.outerRadius,
    required this.wedgeOuterRadius,
    required this.centerAnglesDeg,
    required this.separatorWidth,
    required this.yellow,
    required this.separatorColor,
    required this.ringColor,
    this.pressedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ringBounds = Rect.fromCircle(center: center, radius: wedgeOuterRadius);
    // The reference (the glossy black squares, not the flat wheel image)
    // is NOT a smooth wash across the whole shape — pixel-sampling it
    // confirms a mostly-flat/dark base with a *concentrated* bright
    // streak only in the upper ~35%, dropping to the base color well
    // before the midpoint. A broad corner-to-corner gradient (what was
    // here before) reads as a flat wash, not a shine — this instead
    // paints a flat base, then a separate soft glare clipped to each
    // wedge, from one shared light position (screen upper-left) so all
    // three wedges read as lit by the same source rather than each
    // having its own independent gradient.
    final fillPaint = Paint()..color = yellow;
    final glareCenter = Offset(center.dx - wedgeOuterRadius * 0.35, center.dy - wedgeOuterRadius * 0.55);
    final glareRadius = wedgeOuterRadius * 0.85;
    final glareRect = Rect.fromCircle(center: glareCenter, radius: glareRadius);
    final glarePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.55),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(glareRect);
    final shadePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.4, 0.6),
        radius: 1.1,
        colors: [
          Colors.transparent,
          Color.lerp(yellow, Colors.black, 0.35)!.withOpacity(0.55),
        ],
        stops: const [0.55, 1.0],
      ).createShader(ringBounds);

    // Full-sweep wedges, no angular gap — they visually touch each
    // other, but stop short of outerRadius (see wedgeOuterRadius) to
    // leave breathing room before the frame ring, matching the
    // reference.
    for (final centerAngleDeg in centerAnglesDeg) {
      final startRad = (centerAngleDeg - 60) * math.pi / 180;
      final sweepRad = 120 * math.pi / 180;
      final path = _wedgePath(center, innerRadius, wedgeOuterRadius, startRad, sweepRad);
      canvas.drawPath(path, fillPaint);
      canvas.save();
      canvas.clipPath(path);
      canvas.drawPath(path, glarePaint);
      canvas.drawPath(path, shadePaint);
      canvas.restore();
    }

    // Straight, constant-width seams — cut on top of the fill, at the
    // 3 boundary angles between adjacent wedges (each wedge center
    // minus 60°).
    final separatorPaint = Paint()
      ..color = separatorColor
      ..strokeWidth = separatorWidth
      ..strokeCap = StrokeCap.butt;
    for (final centerAngleDeg in centerAnglesDeg) {
      final boundaryRad = (centerAngleDeg - 60) * math.pi / 180;
      final innerPoint = Offset(center.dx + innerRadius * math.cos(boundaryRad), center.dy + innerRadius * math.sin(boundaryRad));
      final outerPoint = Offset(center.dx + wedgeOuterRadius * math.cos(boundaryRad), center.dy + wedgeOuterRadius * math.sin(boundaryRad));
      canvas.drawLine(innerPoint, outerPoint, separatorPaint);
    }

    // Outer ring framing the whole wheel, matching the reference — a
    // dedicated color, distinct from the background, since the
    // separator color IS the background and was invisible against
    // itself here.
    canvas.drawCircle(center, outerRadius, Paint()..style = PaintingStyle.stroke..strokeWidth = 5.5..color = ringColor);
    // Inner ring, so the hub's edge reads crisply too.
    canvas.drawCircle(center, innerRadius, Paint()..style = PaintingStyle.stroke..strokeWidth = 4.0..color = ringColor);

    // Pressed-wedge perimeter glow — same cheap wide-then-crisp-stroke
    // trick used elsewhere in this app (no MaskFilter.blur).
    if (pressedIndex != null && pressedIndex! < centerAnglesDeg.length) {
      final startRad = (centerAnglesDeg[pressedIndex!] - 60) * math.pi / 180;
      final sweepRad = 120 * math.pi / 180;
      final glowPath = _wedgePath(center, innerRadius, wedgeOuterRadius, startRad, sweepRad);
      canvas.drawPath(glowPath, Paint()..style = PaintingStyle.stroke..strokeWidth = 10..color = Colors.white.withOpacity(0.35));
      canvas.drawPath(glowPath, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = Colors.white.withOpacity(0.9));
    }
  }

  @override
  bool shouldRepaint(covariant _WheelRingPainter oldDelegate) =>
      oldDelegate.center != center ||
      oldDelegate.innerRadius != innerRadius ||
      oldDelegate.outerRadius != outerRadius ||
      oldDelegate.pressedIndex != pressedIndex;
}

/// Founding Key intro video — same asset/behaviour as before, restyled
/// for the dark background.
class _FoundingKeyVideo extends StatefulWidget {
  const _FoundingKeyVideo();

  @override
  State<_FoundingKeyVideo> createState() => _FoundingKeyVideoState();
}

class _FoundingKeyVideoState extends State<_FoundingKeyVideo> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
      'assets/video/benchpad-founding-key-world.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.play();
      }).catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: BenchPadWorldScreen._yellow.withOpacity(0.35)),
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_ready) VideoPlayer(_controller) else Container(color: Colors.white.withOpacity(0.05)),
              Positioned(
                right: 10,
                bottom: 10,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _muted = !_muted;
                    _controller.setVolume(_muted ? 0 : 1);
                  }),
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle),
                    child: Icon(_muted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 17),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
