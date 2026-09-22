import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show rootBundle;
import '../theme/neumorphic_theme.dart';

/// Community Pulse — a rotating globe plotting real visitor
/// settlements (city/country, from /api/community-pulse), ported from
/// benchpad-community.html's pulse-globe (there built on the globe.gl
/// WebGL library).
///
/// Renders an actual textured Earth (continents + oceans, from
/// assets/globe/earth-blue-marble.jpg — an equirectangular world map
/// texture already in the project) via Canvas.drawVertices: the
/// sphere is a triangle mesh sampled on a lat/lon grid, each vertex
/// carries a UV texture coordinate into the map image, rotated and
/// projected every frame, with back-facing triangles culled (valid
/// for a convex sphere — no other 3D content to occlude against).
/// This is real per-frame 3D rendering, not a 3D library or a static
/// image — no package exists for "the exact right thing" here, so it
/// had to be built from Canvas primitives.
///
/// Auto-rotates continuously; drag to spin manually; tap a location in
/// the list below to animate the globe to face it, matching the PWA's
/// own "tap a location to rotate the globe" behaviour.
class CommunityPulseGlobe extends StatefulWidget {
  final List<Map<String, dynamic>> locations;
  final String? emptyNotice;
  /// Called when a drag/pinch starts or ends on the globe, so the
  /// parent scrollable can temporarily disable its own scrolling —
  /// without this, the ancestor ListView sometimes wins the gesture
  /// arena instead of the globe, causing the whole page to scroll (and
  /// even trigger pull-to-refresh) instead of rotating the globe.
  final ValueChanged<bool>? onInteracting;

  const CommunityPulseGlobe({super.key, required this.locations, this.emptyNotice, this.onInteracting});

  @override
  State<CommunityPulseGlobe> createState() => _CommunityPulseGlobeState();
}

class _CommunityPulseGlobeState extends State<CommunityPulseGlobe> with TickerProviderStateMixin {
  late final Ticker _ticker;
  late final AnimationController _focusController;
  Duration _lastElapsed = Duration.zero;
  double _rotY = 0;
  double _rotX = -0.28;
  double _scale = 1;
  double _dragBaseScale = 1;
  double _focusFromRotY = 0;
  double _focusToRotY = 0;
  bool _dragging = false;
  int? _selectedIndex;
  ui.Image? _earthImage;
  late final _SphereMesh _mesh;

  static const _minScale = 1.0;
  static const _maxScale = 4.0;
  static const _autoRotateSpeed = 2 * math.pi / 50; // one full turn per 50s

  @override
  void initState() {
    super.initState();
    _mesh = _SphereMesh.build(latSegments: 16, lonSegments: 28);
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
      _lastElapsed = elapsed;
      setState(() {
        if (!_dragging && !_focusController.isAnimating) _rotY += dt * _autoRotateSpeed;
      });
    })..start();
    _focusController = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))
      ..addListener(() {
        if (mounted) setState(() => _rotY = _focusFromRotY + (_focusToRotY - _focusFromRotY) * Curves.easeInOutCubic.transform(_focusController.value));
      });
    _loadEarthTexture();
  }

  Future<void> _loadEarthTexture() async {
    try {
      final data = await rootBundle.load('assets/globe/earth-blue-marble.jpg');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _earthImage = frame.image);
    } catch (_) {
      // Falls back to a plain gradient sphere (painted below) if the
      // texture can't load for any reason.
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusController.dispose();
    super.dispose();
  }

  double get _currentRotY => _rotY;

  void _focusOn(int index) {
    final loc = widget.locations[index];
    final lon = (loc['longitude'] as num?)?.toDouble() ?? 0;
    final target = -(lon * math.pi / 180);
    _focusFromRotY = _currentRotY;
    _focusToRotY = target;
    setState(() => _selectedIndex = index);
    _focusController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.15,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const RadialGradient(
                center: Alignment(-0.3, -0.3),
                radius: 1.3,
                colors: [Color(0xFF1A1F3A), Color(0xFF05060F)],
              ),
              boxShadow: [
                BoxShadow(color: NeumorphicPalette.shadowDark.withOpacity(0.7), offset: const Offset(6, 6), blurRadius: 14),
                const BoxShadow(color: Colors.white, offset: Offset(-6, -6), blurRadius: 14),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Listener(
                onPointerDown: (_) => widget.onInteracting?.call(true),
                onPointerUp: (_) => widget.onInteracting?.call(false),
                onPointerCancel: (_) => widget.onInteracting?.call(false),
                child: GestureDetector(
                  onScaleStart: (details) {
                    _dragBaseScale = _scale;
                    _dragging = true;
                  },
                  onScaleUpdate: (details) {
                    setState(() {
                      _rotY += details.focalPointDelta.dx * 0.008;
                      _rotX = (_rotX - details.focalPointDelta.dy * 0.008).clamp(-1.4, 1.4);
                      _scale = (_dragBaseScale * details.scale).clamp(_minScale, _maxScale);
                    });
                  },
                  onScaleEnd: (_) => setState(() => _dragging = false),
                  child: AnimatedBuilder(
                    animation: _focusController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _GlobePainter(
                          mesh: _mesh,
                          earthImage: _earthImage,
                        locations: widget.locations,
                        rotationX: _rotX,
                        rotationY: _currentRotY,
                        scale: _scale,
                        selectedIndex: _selectedIndex,
                        pulseMs: _lastElapsed.inMilliseconds,
                      ),
                      child: Container(),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
        if (widget.emptyNotice != null) ...[
          const SizedBox(height: 10),
          Text(widget.emptyNotice!, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 16),
        Row(
          children: const [
            Text('Visitor locations', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: NeumorphicPalette.textPrimary)),
            SizedBox(width: 8),
            Expanded(child: Text('Tap a location to rotate the globe', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10), textAlign: TextAlign.right)),
          ],
        ),
        const SizedBox(height: 10),
        if (widget.locations.isEmpty)
          NeumorphicBox(
            flat: true,
            borderRadius: 14,
            child: const Text('No public settlement data yet.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
          )
        else
          ...List.generate(widget.locations.length, (i) {
            final loc = widget.locations[i];
            final selected = _selectedIndex == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NeumorphicBox(
                soft: true,
                pressed: selected,
                borderRadius: 12,
                onTap: () => _focusOn(i),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${loc['city']}, ${loc['country']}',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? NeumorphicPalette.accent : NeumorphicPalette.textPrimary),
                      ),
                    ),
                    Text('${(loc['visitors'] as num?)?.toInt() ?? 0} visitors', style: const TextStyle(fontSize: 11, color: NeumorphicPalette.textSecondary)),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _Vec3 {
  final double x, y, z;
  const _Vec3(this.x, this.y, this.z);
}

_Vec3 _latLonToVec3(double lat, double lon) {
  final phi = (90 - lat) * math.pi / 180;
  final theta = (lon + 180) * math.pi / 180;
  return _Vec3(-(math.sin(phi) * math.cos(theta)), math.cos(phi), math.sin(phi) * math.sin(theta));
}

_Vec3 _rotate(_Vec3 p, double rotX, double rotY) {
  final cosY = math.cos(rotY), sinY = math.sin(rotY);
  final x1 = p.x * cosY - p.z * sinY;
  final z1 = p.x * sinY + p.z * cosY;
  final cosX = math.cos(rotX), sinX = math.sin(rotX);
  final y2 = p.y * cosX - z1 * sinX;
  final z2 = p.y * sinX + z1 * cosX;
  return _Vec3(x1, y2, z2);
}

/// A fixed lat/lon triangle mesh over a unit sphere, precomputed once
/// (topology + base positions + UV coords never change — only the
/// rotation applied per frame does).
class _SphereMesh {
  final List<_Vec3> basePositions;
  final List<Offset> uvUnit; // 0..1, scaled to image pixels at draw time
  final List<int> indices;

  _SphereMesh({required this.basePositions, required this.uvUnit, required this.indices});

  factory _SphereMesh.build({required int latSegments, required int lonSegments}) {
    final positions = <_Vec3>[];
    final uvs = <Offset>[];
    for (int la = 0; la <= latSegments; la++) {
      final lat = 90 - (la / latSegments) * 180;
      for (int lo = 0; lo <= lonSegments; lo++) {
        final lon = -180 + (lo / lonSegments) * 360;
        positions.add(_latLonToVec3(lat, lon));
        uvs.add(Offset(lo / lonSegments, la / latSegments));
      }
    }
    final indices = <int>[];
    final rowStride = lonSegments + 1;
    for (int la = 0; la < latSegments; la++) {
      for (int lo = 0; lo < lonSegments; lo++) {
        final i0 = la * rowStride + lo;
        final i1 = i0 + 1;
        final i2 = i0 + rowStride;
        final i3 = i2 + 1;
        indices.addAll([i0, i2, i1, i1, i2, i3]);
      }
    }
    return _SphereMesh(basePositions: positions, uvUnit: uvs, indices: indices);
  }
}

class _GlobePainter extends CustomPainter {
  final _SphereMesh mesh;
  final ui.Image? earthImage;
  final List<Map<String, dynamic>> locations;
  final double rotationX, rotationY;
  final double scale;
  final int? selectedIndex;
  final int pulseMs;

  _GlobePainter({required this.mesh, required this.earthImage, required this.locations, required this.rotationX, required this.rotationY, required this.scale, required this.selectedIndex, required this.pulseMs});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.42 * scale;

    // Starfield — fixed pseudo-random positions (same seed every
    // frame, so stars don't jitter).
    final starRandom = math.Random(7);
    final starPaint = Paint()..color = Colors.white;
    for (int i = 0; i < 70; i++) {
      final dx = starRandom.nextDouble() * size.width;
      final dy = starRandom.nextDouble() * size.height;
      final r = starRandom.nextDouble() * 1.2 + 0.3;
      starPaint.color = Colors.white.withOpacity(0.2 + starRandom.nextDouble() * 0.5);
      canvas.drawCircle(Offset(dx, dy), r, starPaint);
    }

    final image = earthImage;
    if (image == null) {
      // Texture still loading — plain gradient sphere placeholder.
      final basePaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 1.1,
          colors: [const Color(0xFF7FD4C6), const Color(0xFF2E7A9E), const Color(0xFF1B4E6E)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, basePaint);
    } else {
      final rotated = List<_Vec3>.generate(mesh.basePositions.length, (i) => _rotate(mesh.basePositions[i], rotationX, rotationY));
      final positions = List<Offset>.generate(rotated.length, (i) => Offset(center.dx + rotated[i].x * radius, center.dy - rotated[i].y * radius));
      final texCoords = List<Offset>.generate(mesh.uvUnit.length, (i) => Offset(mesh.uvUnit[i].dx * image.width, mesh.uvUnit[i].dy * image.height));

      final visibleIndices = <int>[];
      for (int t = 0; t < mesh.indices.length; t += 3) {
        final i0 = mesh.indices[t], i1 = mesh.indices[t + 1], i2 = mesh.indices[t + 2];
        final avgZ = (rotated[i0].z + rotated[i1].z + rotated[i2].z) / 3;
        if (avgZ > -0.06) visibleIndices.addAll([i0, i1, i2]);
      }

      final vertices = ui.Vertices(ui.VertexMode.triangles, positions, textureCoordinates: texCoords, indices: Uint16List.fromList(visibleIndices));
      final paint = Paint()..shader = ImageShader(image, TileMode.clamp, TileMode.clamp, Matrix4.identity().storage);
      canvas.drawVertices(vertices, BlendMode.srcOver, paint);

      // Subtle rim shading so the sphere reads as lit, not flat.
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.transparent, Colors.black.withOpacity(0.28)],
            stops: const [0.75, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // Location dots, painter's-algorithm sorted by depth.
    final withDepth = <MapEntry<Map<String, dynamic>, _Vec3>>[];
    for (int i = 0; i < locations.length; i++) {
      final loc = locations[i];
      final lat = (loc['latitude'] as num?)?.toDouble() ?? 0;
      final lon = (loc['longitude'] as num?)?.toDouble() ?? 0;
      withDepth.add(MapEntry(loc, _rotate(_latLonToVec3(lat, lon), rotationX, rotationY)));
    }
    withDepth.sort((a, b) => a.value.z.compareTo(b.value.z));

    for (int i = 0; i < withDepth.length; i++) {
      final v = withDepth[i].value;
      if (v.z < -0.1) continue;
      final depthFactor = (v.z + 1) / 2;
      final screen = Offset(center.dx + v.x * radius, center.dy - v.y * radius);
      final loc = withDepth[i].key;
      final origIndex = locations.indexOf(loc);
      final isSelected = origIndex == selectedIndex;
      final dotRadius = 3.0 + depthFactor * 3.0;
      const gold = Color(0xFFFFC24B);

      // Two staggered pulses per point — as one fades out mid-cycle,
      // the other is roughly mid-expansion, so it reads as a
      // continuous outward pulse rather than a single blinking ring.
      // Offsetting the start by the point's own index keeps every
      // location from pulsing in exact unison (a bit more organic).
      const cycleMs = 2200;
      final staggerMs = (origIndex * 137) % cycleMs;
      const maxExpansion = 15.0;
      for (final ringOffset in [0, cycleMs ~/ 2]) {
        final phase = ((pulseMs + staggerMs + ringOffset) % cycleMs) / cycleMs;
        final ringRadius = dotRadius + phase * maxExpansion;
        final ringOpacity = (1 - phase) * (0.5 + depthFactor * 0.3);
        canvas.drawCircle(
          screen,
          ringRadius,
          Paint()
            ..color = gold.withOpacity(ringOpacity.clamp(0.0, 1.0))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }

      canvas.drawCircle(screen, dotRadius, Paint()..color = gold.withOpacity(0.35 + depthFactor * 0.5));
      canvas.drawCircle(screen, dotRadius * 0.55, Paint()..color = gold);
      if (isSelected) {
        canvas.drawCircle(
          screen,
          dotRadius + 6,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePainter oldDelegate) {
    return oldDelegate.rotationY != rotationY ||
        oldDelegate.rotationX != rotationX ||
        oldDelegate.scale != scale ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.locations.length != locations.length ||
        oldDelegate.pulseMs != pulseMs ||
        oldDelegate.earthImage != earthImage;
  }
}
