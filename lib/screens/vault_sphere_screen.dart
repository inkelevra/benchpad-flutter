import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/benchpad_api.dart';
import '../services/geosphere.dart';
import '../theme/neumorphic_theme.dart';
import '../widgets/home_back_leading.dart';
import 'capsule_creator_screen.dart';
import 'capsule_certificate_screen.dart';
import 'broadcast_calendar_screen.dart';

/// Vault Sphere — personal time capsules as an interactive 3D
/// point-cloud, ported from benchpad-time-capsule.html. Same rendering
/// approach as Memory Sphere (Fibonacci sphere distribution, drag to
/// rotate, pinch to zoom, tap to select) — 162 points instead of 500 (12
/// "core" cells rendered larger/square, 150 "standard" cells the rest).
class VaultSphereScreen extends StatefulWidget {
  const VaultSphereScreen({super.key});

  @override
  State<VaultSphereScreen> createState() => _VaultSphereScreenState();
}

class _VaultSphereScreenState extends State<VaultSphereScreen> with SingleTickerProviderStateMixin {
  final _api = BenchpadApi();
  List<VaultCell> _cells = [];
  bool _loading = true;
  String? _error;

  double _rotationY = 0;
  double _rotationX = -0.15;
  double _scale = 1.0;
  double _baseScale = 1.0;
  Offset? _lastPanPos;
  bool _spinning = true;

  int? _selectedIndex;
  String _statusFilter = 'all';

  late final AnimationController _spinController;

  static const _statusColors = {
    'empty': Color(0xFF75E7FF),
    'locked': Color(0xFFFFD84D),
    'sealed': Color(0xFFFF4D68),
    'open': Color(0xFF68F56A),
  };

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(vsync: this, duration: const Duration(seconds: 60))
      ..addListener(() {
        if (_spinning) setState(() => _rotationY += 0.0006);
      })
      ..repeat();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final cells = await _api.getVaultCells();
      final byKey = {for (final c in cells) '${c.type}:${c.number}': c};
      final core = List.generate(12, (i) => byKey['core:${i + 1}'] ?? VaultCell(type: 'core', number: i + 1, status: 'empty'));
      final standard = List.generate(150, (i) => byKey['standard:${i + 1}'] ?? VaultCell(type: 'standard', number: i + 1, status: 'empty'));
      if (mounted) {
        final combined = [...core, ...standard];
        setState(() {
          _cells = combined;
          _loading = false;
          _selectedIndex ??= _defaultSelection(combined);
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Picks a sensible cell to show by default so the info card isn't
  /// blank on first open — prefers 'open', falls back to any
  /// non-empty cell, null only if the sphere is entirely empty.
  int? _defaultSelection(List<VaultCell> cells) {
    for (int i = 0; i < cells.length; i++) {
      if (cells[i].status == 'open') return i;
    }
    for (int i = 0; i < cells.length; i++) {
      if (cells[i].status != 'empty') return i;
    }
    return null;
  }

  List<VaultCell> get _visibleCells {
    if (_statusFilter == 'all') return _cells;
    return _cells.where((c) => c.status == _statusFilter).toList();
  }

  Map<String, int> get _statusCounts {
    final counts = {'empty': 0, 'locked': 0, 'sealed': 0, 'open': 0};
    for (final c in _cells) {
      counts[c.status] = (counts[c.status] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _openCell(VaultCell cell) async {
    if (cell.status == 'empty' || cell.status == 'locked') {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CapsuleCreatorScreen(type: cell.type, number: cell.number)),
      );
      if (result == true) _load();
    } else {
      _showCellDetail(cell);
    }
  }

  void _showCellDetail(VaultCell cell) {
    final color = _statusColors[cell.status] ?? NeumorphicPalette.accent;
    showModalBottomSheet(
      context: context,
      backgroundColor: NeumorphicPalette.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cell.displayId, style: const TextStyle(color: NeumorphicPalette.accent, fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(cell.ownerName ?? 'Sealed capsule', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(999)),
              child: Text(cell.status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
            if (cell.status == 'open' && cell.message != null) ...[
              const SizedBox(height: 16),
              Text('"${cell.message}"', style: const TextStyle(fontSize: 14, height: 1.4, fontStyle: FontStyle.italic, color: NeumorphicPalette.textPrimary)),
            ] else if (cell.status == 'sealed') ...[
              const SizedBox(height: 12),
              Text(
                'This capsule is sealed. Its message will be revealed on ${cell.openingDate ?? "its opening date"}.',
                style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12),
              ),
            ],
            if (cell.ownerCountry != null) ...[
              const SizedBox(height: 12),
              Text('From ${cell.ownerCountry}', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: NeumorphicPalette.textPrimary, side: const BorderSide(color: NeumorphicPalette.accent)),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => CapsuleCertificateScreen(type: cell.type, number: cell.number)));
              },
              child: const Text('VIEW CERTIFICATE'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: NeumorphicPalette.textPrimary, side: const BorderSide(color: NeumorphicPalette.accent)),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => BroadcastCalendarScreen(
                  sphere: 'vault',
                  capsuleType: cell.type,
                  capsuleNumber: cell.number,
                  ownerName: cell.ownerName ?? '',
                  ownerCountry: cell.ownerCountry ?? '',
                  contentReady: cell.message != null && cell.message!.isNotEmpty,
                )));
              },
              child: const Text('SCHEDULE BROADCAST'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: NeumorphicPalette.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: NeumorphicPalette.background,
          foregroundColor: NeumorphicPalette.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(foregroundColor: NeumorphicPalette.textPrimary, disabledForegroundColor: NeumorphicPalette.textSecondary, side: const BorderSide(color: NeumorphicPalette.accent)),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: NeumorphicPalette.accent),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: Builder(builder: backLeading),
          leadingWidth: 64,
          centerTitle: true,
          title: const Text('Vault Sphere'),
          actions: [
            IconButton(
              tooltip: _spinning ? 'Pause rotation' : 'Resume rotation',
              icon: Icon(_spinning ? Icons.pause : Icons.play_arrow),
              onPressed: () => setState(() => _spinning = !_spinning),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: NeumorphicPalette.accent))
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: NeumorphicPalette.danger)))
                : Column(
                    children: [
                      _buildStatsBar(),
                      Expanded(child: _buildSphereStage()),
                      _buildSelectedCard(),
                      _buildLegend(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: NeumorphicPalette.background,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: NeumorphicPalette.shadowDark.withOpacity(0.6), offset: const Offset(3, 3), blurRadius: 6),
          const BoxShadow(color: Colors.white, offset: Offset(-3, -3), blurRadius: 6),
        ],
      ),
      child: Row(
        children: [
          _statItem('12', 'CORE'),
          _statItem('150', 'STANDARD'),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
        ],
      ),
    );
  }

  Widget _buildSphereStage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: const RadialGradient(center: Alignment(-0.3, -0.3), radius: 1.3, colors: [Color(0xFF1A1F3A), Color(0xFF05060F)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF70DF78).withOpacity(0.25)),
        boxShadow: [
          BoxShadow(color: NeumorphicPalette.shadowDark.withOpacity(0.6), offset: const Offset(4, 4), blurRadius: 10),
          const BoxShadow(color: Colors.white, offset: Offset(-4, -4), blurRadius: 10),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
        onTapDown: (_) => _spinning = false,
        onScaleStart: (details) {
          _lastPanPos = details.focalPoint;
          _baseScale = _scale;
          _spinning = false;
        },
        onScaleUpdate: (details) {
          setState(() {
            if (details.pointerCount == 1 && _lastPanPos != null) {
              final delta = details.focalPoint - _lastPanPos!;
              _rotationY += delta.dx * 0.01;
              _rotationX = (_rotationX + delta.dy * 0.01).clamp(-1.4, 1.4);
              _lastPanPos = details.focalPoint;
            }
            _scale = (_baseScale * details.scale).clamp(0.6, 2.2);
          });
        },
        onTapUp: (details) => _handleTap(details.localPosition, constraints.biggest),
        child: CustomPaint(
          size: Size.infinite,
          painter: _VaultSpherePainter(
            cells: _visibleCells,
            totalCells: _cells.length,
            rotationX: _rotationX,
            rotationY: _rotationY,
            scale: _scale,
            selectedCell: _selectedIndex != null && _selectedIndex! < _cells.length ? _cells[_selectedIndex!] : null,
            statusColors: _statusColors,
          ),
        ),
        ),
      ),
    );
  }

  void _handleTap(Offset local, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.38 * _scale;
    VaultCell? closest;
    double closestDist = 30;

    final visible = _visibleCells;
    for (int i = 0; i < visible.length; i++) {
      final p = _cellPosition(visible[i]);
      final rotated = _rotate(p, _rotationX, _rotationY);
      if (rotated.z < -0.1) continue;
      final screen = Offset(center.dx + rotated.x * radius, center.dy + rotated.y * radius);
      final dist = (screen - local).distance;
      if (dist < closestDist) {
        closestDist = dist;
        closest = visible[i];
      }
    }

    if (closest != null) {
      setState(() => _selectedIndex = _cells.indexOf(closest!));
    }
  }

  Widget _buildSelectedCard() {
    if (_selectedIndex == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          'Tap a point on the sphere to open a capsule.',
          style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
    }
    final cell = _cells[_selectedIndex!];
    final color = _statusColors[cell.status] ?? NeumorphicPalette.accent;
    return GestureDetector(
      onTap: () => _openCell(cell),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: NeumorphicPalette.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(color: NeumorphicPalette.shadowDark.withOpacity(0.5), offset: const Offset(3, 3), blurRadius: 6),
            const BoxShadow(color: Colors.white, offset: Offset(-3, -3), blurRadius: 6),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: cell.type == 'core' ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: cell.type == 'core' ? BorderRadius.circular(12) : null,
                color: color.withOpacity(0.15),
                border: Border.all(color: color),
              ),
              child: Center(child: Text('${cell.number}', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cell.type == 'core' ? 'CORE CELL' : 'STANDARD CELL', style: const TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(cell.ownerName ?? cell.displayId, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(cell.status.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    final counts = _statusCounts;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          _legendButton('all', 'ALL', _cells.length, NeumorphicPalette.accent),
          const SizedBox(width: 6),
          _legendButton('empty', 'EMPTY', counts['empty']!, _statusColors['empty']!),
          const SizedBox(width: 6),
          _legendButton('locked', 'LOCKED', counts['locked']!, _statusColors['locked']!),
          const SizedBox(width: 6),
          _legendButton('sealed', 'SEALED', counts['sealed']!, _statusColors['sealed']!),
          const SizedBox(width: 6),
          _legendButton('open', 'OPEN', counts['open']!, _statusColors['open']!),
        ],
      ),
    );
  }

  Widget _legendButton(String key, String label, int count, Color color) {
    final active = _statusFilter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _statusFilter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.15) : NeumorphicPalette.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: active ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Text('$count', style: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
              Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 7, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Vec3 {
  final double x, y, z;
  const _Vec3(this.x, this.y, this.z);
}

const _vaultSubdivisions = 4; // -> exactly 162 tiles (12 pentagons + 150 hexagons), matching the 162 cells exactly

/// Maps a cell to its tile's center point — core cells (12 of them) to
/// the sphere's 12 natural pentagon tiles, standard cells (150) to its
/// 150 hexagon tiles. Shared by the painter and tap hit-testing so
/// both agree on where each cell actually sits.
_Vec3 _cellPosition(VaultCell cell) {
  final tiles = Geosphere.build(subdivisions: _vaultSubdivisions);
  if (cell.type == 'core') {
    final pentagons = tiles.where((t) => t.corners.length == 5).toList();
    final c = pentagons[(cell.number - 1) % pentagons.length].center;
    return _Vec3(c.x, c.y, c.z);
  } else {
    final hexagons = tiles.where((t) => t.corners.length == 6).toList();
    final c = hexagons[(cell.number - 1) % hexagons.length].center;
    return _Vec3(c.x, c.y, c.z);
  }
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

class _VaultSpherePainter extends CustomPainter {
  final List<VaultCell> cells;
  final int totalCells;
  final double rotationX, rotationY, scale;
  final VaultCell? selectedCell;
  final Map<String, Color> statusColors;

  _VaultSpherePainter({
    required this.cells,
    required this.totalCells,
    required this.rotationX,
    required this.rotationY,
    required this.scale,
    required this.selectedCell,
    required this.statusColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.38 * scale;

    final tiles = Geosphere.build(subdivisions: _vaultSubdivisions);
    final pentagons = tiles.where((t) => t.corners.length == 5).toList();
    final hexagons = tiles.where((t) => t.corners.length == 6).toList();

    final cellByCore = <int, VaultCell>{};
    final cellByStandard = <int, VaultCell>{};
    for (final cell in cells) {
      if (cell.type == 'core') {
        cellByCore[cell.number - 1] = cell;
      } else {
        cellByStandard[cell.number - 1] = cell;
      }
    }

    final entries = <MapEntry<GeoTile, VaultCell?>>[];
    for (int i = 0; i < pentagons.length; i++) {
      entries.add(MapEntry(pentagons[i], cellByCore[i]));
    }
    for (int i = 0; i < hexagons.length; i++) {
      entries.add(MapEntry(hexagons[i], cellByStandard[i]));
    }

    final rotated = entries.map((e) {
      final corners = e.key.corners.map((c) => _rotate(_Vec3(c.x, c.y, c.z), rotationX, rotationY)).toList();
      return MapEntry(e, corners);
    }).toList();

    rotated.sort((a, b) {
      final az = a.value.fold<double>(0, (s, v) => s + v.z) / a.value.length;
      final bz = b.value.fold<double>(0, (s, v) => s + v.z) / b.value.length;
      return az.compareTo(bz);
    });

    for (final entry in rotated) {
      final corners = entry.value;
      final cell = entry.key.value;
      final avgZ = corners.fold<double>(0, (s, v) => s + v.z) / corners.length;
      if (avgZ < -0.15) continue;

      final depthFactor = ((avgZ + 1) / 2).clamp(0.0, 1.0);
      final color = cell != null ? (statusColors[cell.status] ?? Colors.grey) : const Color(0xFF2A3050);
      final isSelected = cell != null && selectedCell != null && selectedCell!.type == cell.type && selectedCell!.number == cell.number;

      final path = Path();
      for (int i = 0; i < corners.length; i++) {
        final v = corners[i];
        final screen = Offset(center.dx + v.x * radius, center.dy + v.y * radius);
        if (i == 0) {
          path.moveTo(screen.dx, screen.dy);
        } else {
          path.lineTo(screen.dx, screen.dy);
        }
      }
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(cell != null ? (0.35 + depthFactor * 0.55) : (0.12 + depthFactor * 0.18))
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withOpacity(0.25 * depthFactor)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );

      if (isSelected) {
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VaultSpherePainter oldDelegate) {
    return oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.scale != scale ||
        oldDelegate.selectedCell != selectedCell ||
        oldDelegate.cells.length != cells.length;
  }
}
